#!/bin/bash
# Reaktionskette von Samhain im inotify-Modus, gemessen wie bei Wazuh.
# Diese Samhain-Version kennt keinen Schalter fuer eine andere Konfigurationsdatei
# (-c bedeutet --copyright), daher wird /etc/samhain/samhainrc zeitweise ergaenzt
# und am Ende aus der Sicherung wiederhergestellt.
RC=/etc/samhain/samhainrc
BAK=/root/samhainrc.backup
CSV=/root/messung_samhain_inotify_v2.csv
F=/opt/fsc-test/testbinary

cp -a "$RC" "$BAK" || exit 1
echo "Sicherung liegt in $BAK"
systemctl stop wazuh-agent osqueryd
rm -f "$CSV"
chmod 755 "$F"

printf '\n[Inotify]\nInotifyActive=yes\n' >> "$RC"
echo "--- Ende der Konfiguration ---"; tail -4 "$RC"

rm -f /var/lib/samhain/samhain-fsc.file
samhain -t init --foreground -p none
if [ ! -s /var/lib/samhain/samhain-fsc.file ]; then
  echo "FEHLER: keine Datenbank, Konfiguration wird zurueckgesetzt."
  cp -a "$BAK" "$RC"; systemctl start wazuh-agent osqueryd; exit 1
fi
echo "Datenbank vorhanden: $(stat -c %s /var/lib/samhain/samhain-fsc.file) Byte"

samhain -t check --foreground --forever -p none &
SPID=$!
sleep 8
if kill -0 $SPID 2>/dev/null; then
  echo "Samhain laeuft im Dauerbetrieb, PID $SPID"
else
  echo "FEHLER: Dauerbetrieb nicht gestartet."
  cp -a "$BAK" "$RC"; systemctl start wazuh-agent osqueryd; exit 1
fi
echo "INOTIFY-Zeilen im Log: $(grep -c INOTIFY /var/lib/samhain/samhain-fsc.log)"

for runde in $(seq 1 30); do
  START=$(date +%s%N); GRENZE=$((START + 10000000000))
  chmod 4755 "$F"
  while [ "$(stat -c %a "$F")" != "755" ]; do
    [ "$(date +%s%N)" -gt "$GRENZE" ] && break
    sleep 0.005
  done
  END=$(date +%s%N)
  if [ "$(stat -c %a "$F")" = "755" ]; then
    MS=$(( (END - START) / 1000000 ))
  else
    MS=-1; chmod 755 "$F"
  fi
  echo "inotify;samhain;${runde};${MS}" >> "$CSV"
  sleep 6
done

kill $SPID 2>/dev/null; sleep 2; pkill -f 'samhain -t check' 2>/dev/null
cp -a "$BAK" "$RC"
echo "Konfiguration wiederhergestellt"
rm -f /var/lib/samhain/samhain-fsc.file
samhain -t init --foreground -p none
systemctl start wazuh-agent osqueryd
cp "$CSV" /home/lukas/ ; chown lukas /home/lukas/messung_samhain_inotify_v2.csv
echo; echo "Modus am Ende: $(stat -c %a $F)"
awk -F';' '$3>1 {v=v" "$4} END {print "samhain inotify:"v}' "$CSV"
echo "Abbrueche: $(grep -c ';-1$' "$CSV")"
