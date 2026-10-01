#!/bin/bash
# Erkennbarkeit einer zurueckgenommenen SUID-Aenderung in Abhaengigkeit vom
# Zeitfenster.
#
# Das Bit wird gesetzt und nach W Millisekunden zurueckgenommen. Der
# AIDE-Pruefzeitpunkt wird mit einem Offset O im Pruefintervall I gezogen;
# Samhain prueft nach der Ruecknahme.
#
# Wichtig: Der Wazuh-Agent wird fuer die Messung gestoppt, weil seine Active
# Response das SUID-Bit nach etwa 28 ms selbst entfernt und damit das
# Zeitfenster zerstoert. Am Ende wird er wieder gestartet.
#
# Die Aufrufe von AIDE und Samhain entsprechen messung_dateisystem.sh.
set -u
Z=/opt/fsc-test/testbinary
ACONF=/etc/aide/aide-fsc.conf
I=500                                   # Pruefintervall in ms
RUHE=1.2                                # Pause nach der Initialisierung
CSV=/root/transienz.csv
LOG=/root/transienz_detail.log
ms() { awk "BEGIN{print $1/1000}"; }

init_aide() {
  aide --config=$ACONF --init >/dev/null 2>&1
  mv -f /var/lib/aide/aide-fsc.db.new /var/lib/aide/aide-fsc.db
}
init_samhain() {
  rm -f /var/lib/samhain/samhain-fsc.file
  samhain -t init --foreground -p none >/dev/null 2>&1
}

aufraeumen() {
  echo "Starte wazuh-agent wieder."
  systemctl start wazuh-agent
}
trap aufraeumen EXIT

echo "Stoppe wazuh-agent fuer die Messung."
systemctl stop wazuh-agent
for D in samhain samhaind; do
  systemctl is-active --quiet "$D" 2>/dev/null && systemctl stop "$D"
done
sleep 2

# Kontrolle: bleibt das Bit jetzt stehen?
chmod 4755 $Z; sleep 1
if [ "$(stat -c %a $Z)" != "4755" ]; then
  echo "ABBRUCH: Das SUID-Bit wird weiterhin von aussen entfernt."; exit 1
fi
chmod 0755 $Z
echo "Kontrolle bestanden, das Bit bleibt stehen."

: > "$LOG"
echo "fenster_ms,lauf,offset_ms,im_fenster,aide,samhain" > "$CSV"
init_aide; init_samhain; sleep "$RUHE"

for W in 10 50 100 250 500 1000; do
  for L in $(seq 1 20); do
    O=$(( RANDOM % I ))
    F=$([ $O -lt $W ] && echo 1 || echo 0)

    chmod 4755 $Z
    ( sleep "$(ms $O)"; aide --config=$ACONF --check 2>&1 ) > /tmp/a.out &
    P=$!
    sleep "$(ms $W)"
    chmod 0755 $Z
    wait $P
    grep -qF "$Z" /tmp/a.out && A=1 || A=0

    samhain -t check --foreground -p err > /tmp/s.out 2>&1
    grep -qF "$Z" /tmp/s.out && S=1 || S=0

    echo "$W,$L,$O,$F,$A,$S" | tee -a "$CSV"
    { echo "=== fenster=$W lauf=$L offset=$O im_fenster=$F aide=$A samhain=$S ==="
      echo "--- aide ---";    cat /tmp/a.out
      echo "--- samhain ---"; cat /tmp/s.out; } >> "$LOG"

    init_aide; init_samhain; sleep "$RUHE"
  done
done

echo
echo "Fertig. Rohdaten: $CSV   Volle Ausgaben: $LOG"
awk -F, 'NR>1{n[$1]++; f[$1]+=$4; a[$1]+=$5; s[$1]+=$6}
 END{printf "%8s %4s %11s %6s %8s\n","Fenster","n","im Fenster","AIDE","Samhain"
     for(k in n) printf "%6s ms %4d %11d %6d %8d\n",k,n[k],f[k],a[k],s[k]}' "$CSV" | sort -n
