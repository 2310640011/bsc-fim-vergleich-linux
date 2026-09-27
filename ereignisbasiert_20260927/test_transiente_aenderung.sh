#!/bin/bash
# Erkennung einer zurueckgenommenen Aenderung.
# Frage: Welche Ansaetze sehen eine Aenderung, die vor dem naechsten Prueflauf
# rueckgaengig gemacht wurde? Erwartung: nur die ereignisbasierten.
F=/opt/fsc-test/testbinary
SLOG=/var/lib/samhain/samhain-fsc.log
OLOG=$(grep -m1 '^--logger_path' /etc/osquery/osquery.flags 2>/dev/null | cut -d= -f2)
OLOG="${OLOG:-/var/log/osquery}/osqueryd.results.log"
[ -f "$OLOG" ] || OLOG=$(find /var/log -name 'osqueryd.results.log' 2>/dev/null | head -1)
echo "osquery-Log: ${OLOG:-NICHT GEFUNDEN}"
[ -f "$OLOG" ] || { echo "FEHLER: Results-Log nicht gefunden."; exit 1; }

systemctl start wazuh-agent osqueryd 2>/dev/null; sleep 3
chmod 755 "$F"
echo "Modus vor dem Test: $(stat -c %a $F)"

# Referenzdatenbanken auf den aktuellen Zustand bringen
aide --config=/etc/aide/aide-fsc.conf --init > /dev/null 2>&1
mv -f /var/lib/aide/aide-fsc.db.new /var/lib/aide/aide-fsc.db
rm -f /var/lib/samhain/samhain-fsc.file
samhain -t init --foreground -p none > /dev/null 2>&1
/usr/local/sbin/fsc-simple-check-v2.sh init > /dev/null 2>&1
echo "Datenbanken neu aufgebaut. Tripwire-Datenbank bleibt bestehen."

pruefe_scanner () {
  local TAG="$1"
  local SL=$(wc -l < "$SLOG" 2>/dev/null || echo 0)
  local A T S K
  aide --config=/etc/aide/aide-fsc.conf --check 2>/dev/null | grep -qi 'testbinary' && A=MELDET || A="meldet nichts"
  tripwire --check 2>/dev/null | grep -qi 'testbinary' && T=MELDET || T="meldet nichts"
  samhain -t check --foreground -p none > /dev/null 2>&1
  [ "$(wc -l < "$SLOG" 2>/dev/null || echo 0)" -gt "$SL" ] && S=MELDET || S="meldet nichts"
  /usr/local/sbin/fsc-simple-check-v2.sh check 2>/dev/null | grep -qi 'testbinary' && K=MELDET || K="meldet nichts"
  echo "  AIDE: $A | Tripwire: $T | Samhain: $S | Kontrollimpl.: $K"
}

echo
echo "=== Durchgang 1: alle Dienste aktiv ==="
OC=$(grep -c 'testbinary' "$OLOG")
chmod 4755 "$F"
GRENZE=$(( $(date +%s%N) + 5000000000 ))
while [ "$(stat -c %a "$F")" != "755" ]; do
  [ "$(date +%s%N)" -gt "$GRENZE" ] && break
  sleep 0.005
done
if [ "$(stat -c %a "$F")" = "755" ]; then
  echo "  Wazuh: MELDET UND REAGIERT (SUID-Bit selbsttaetig zurueckgesetzt)"
else
  echo "  Wazuh: keine Reaktion innerhalb 5 s"; chmod 755 "$F"
fi
sleep 15
ON=$(grep -c 'testbinary' "$OLOG")
[ "$ON" -gt "$OC" ] && echo "  osquery: MELDET ($((ON-OC)) neue Eintraege)" || echo "  osquery: meldet nichts"
pruefe_scanner "mit Diensten"

echo
echo "=== Durchgang 2: Wazuh-Agent gestoppt, Aenderung besteht 2 s ==="
systemctl stop wazuh-agent; sleep 2
OC=$(grep -c 'testbinary' "$OLOG")
chmod 4755 "$F"; sleep 2; chmod 755 "$F"
echo "  Modus wieder: $(stat -c %a $F), Aenderung bestand 2 s"
sleep 15
ON=$(grep -c 'testbinary' "$OLOG")
[ "$ON" -gt "$OC" ] && echo "  osquery: MELDET ($((ON-OC)) neue Eintraege)" || echo "  osquery: meldet nichts"
pruefe_scanner "ohne Wazuh"

systemctl start wazuh-agent
echo
echo "Modus am Ende: $(stat -c %a $F)"
