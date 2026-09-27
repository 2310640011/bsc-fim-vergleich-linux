#!/bin/bash
# Trennschaerfe der automatischen Reaktion von Wazuh gegenueber legitimen Aenderungen.
# Arm 1: sechs legitime Aenderungstypen, je dreimal, die keine SUID-Aenderung sind.
# Arm 2: zehn gewollte SUID-Aenderungen, wie ein Administrator sie vornehmen wuerde.
# Gemessen wird, ob die Active Response ausgeloest hat (Eintrag in active-responses.log).
D=/opt/fsc-test
ARLOG=/var/ossec/logs/active-responses.log
TMP=/root/fehlalarm-sicherung
CSV=/root/test_fehlalarm.csv
[ -f "$ARLOG" ] || { echo "FEHLER: $ARLOG nicht gefunden."; exit 1; }
rm -rf "$TMP"; mkdir -p "$TMP"; rm -f "$CSV"
systemctl start wazuh-agent; sleep 5
chmod 755 "$D/testbinary"

# Zwei Dateien fuer die Tests sichern, damit der Zustand exakt wiederhergestellt wird
A=$(ls "$D" | grep -v testbinary | head -1)
B=$(ls "$D" | grep -v testbinary | sed -n 2p)
cp -a "$D/$A" "$TMP/"; cp -a "$D/$B" "$TMP/"
echo "Testdateien: $A und $B"

pruefe () {
  local NAME="$1" VOR="$2"
  sleep 3
  local NACH=$(wc -l < "$ARLOG")
  if [ "$NACH" -gt "$VOR" ]; then R=AUSGELOEST; else R="keine Reaktion"; fi
  echo "${NAME};${R}" >> "$CSV"
  printf '  %-28s %s\n' "$NAME" "$R"
}

echo; echo "=== Arm 1: legitime Aenderungen, je dreimal ==="
for i in 1 2 3; do
  V=$(wc -l < "$ARLOG"); echo "geaendert" >> "$D/$A"; pruefe "Inhaltsaenderung" "$V"
  cp -a "$TMP/$A" "$D/$A"

  V=$(wc -l < "$ARLOG"); chmod 640 "$D/$A"; pruefe "Rechte verschaerft (640)" "$V"
  chmod 644 "$D/$A"

  V=$(wc -l < "$ARLOG"); touch "$D/$A"; pruefe "Zeitstempel geaendert" "$V"

  V=$(wc -l < "$ARLOG"); chown nobody "$D/$A"; pruefe "Eigentuemer geaendert" "$V"
  chown root "$D/$A"

  V=$(wc -l < "$ARLOG"); echo neu > "$D/legitim_neu.tmp"; pruefe "Datei angelegt" "$V"
  rm -f "$D/legitim_neu.tmp"

  V=$(wc -l < "$ARLOG"); rm -f "$D/$B"; pruefe "Datei geloescht" "$V"
  cp -a "$TMP/$B" "$D/$B"
done

echo; echo "=== Arm 2: zehn gewollte SUID-Aenderungen ==="
Z=0
for i in $(seq 1 10); do
  chmod 4755 "$D/testbinary"
  G=$(( $(date +%s%N) + 5000000000 ))
  while [ "$(stat -c %a "$D/testbinary")" != "755" ]; do
    [ "$(date +%s%N)" -gt "$G" ] && break; sleep 0.005
  done
  if [ "$(stat -c %a "$D/testbinary")" = "755" ]; then
    Z=$((Z+1)); echo "gewollte SUID-Aenderung;ZURUECKGESETZT" >> "$CSV"
  else
    echo "gewollte SUID-Aenderung;bestehen geblieben" >> "$CSV"; chmod 755 "$D/testbinary"
  fi
  sleep 3
done
echo "  von 10 gewollten Aenderungen zurueckgesetzt: $Z"

echo; echo "=== Aufraeumen ==="
cp -a "$TMP/$A" "$D/$A"; cp -a "$TMP/$B" "$D/$B"; chmod 644 "$D/$A" "$D/$B"; chown root:root "$D/$A" "$D/$B"
rm -f "$D"/*.tmp
echo "Objekte: $(ls $D | wc -l), Modus testbinary: $(stat -c %a $D/testbinary)"
aide --config=/etc/aide/aide-fsc.conf --init > /dev/null 2>&1
mv -f /var/lib/aide/aide-fsc.db.new /var/lib/aide/aide-fsc.db
rm -f /var/lib/samhain/samhain-fsc.file
samhain -t init --foreground -p none > /dev/null 2>&1
/usr/local/sbin/fsc-simple-check-v2.sh init > /dev/null 2>&1
cp "$CSV" /home/lukas/ ; chown lukas /home/lukas/test_fehlalarm.csv

echo; echo "=== Zusammenfassung Arm 1 ==="
awk -F';' '$1!="gewollte SUID-Aenderung" {n[$1]++; if($2=="AUSGELOEST") a[$1]++} END {for (k in n) printf "%-28s %d von %d ausgeloest\n", k, a[k]+0, n[k]}' "$CSV"
