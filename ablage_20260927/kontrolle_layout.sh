#!/bin/bash
# Frisch entpackter Bestand auf dem Systemvolume, ohne neues Blockgeraet.
# Aufruf: /root/kontrolle_layout.sh 'LOCAL-PASSPHRASE'
PASS="$1"; [ -z "$PASS" ] && { echo "FEHLER: Passphrase fehlt."; exit 1; }
ARCHIV=/root/fsc-test-original.tar.gz
CSV=/root/kontrolle_layout.csv
[ -f "$ARCHIV" ] || { echo "FEHLER: Archiv fehlt."; exit 1; }

datenbanken_neu () {
  aide --config=/etc/aide/aide-fsc.conf --init > /dev/null 2>&1
  mv -f /var/lib/aide/aide-fsc.db.new /var/lib/aide/aide-fsc.db
  rm -f /var/lib/samhain/samhain-fsc.file
  samhain -t init --foreground -p none > /dev/null 2>&1
  /usr/local/sbin/fsc-simple-check-v2.sh init > /dev/null 2>&1
  rm -f /var/lib/tripwire/fsc-target.twd
  tripwire --init -P "$PASS" > /dev/null 2>&1
}

systemctl stop wazuh-agent osqueryd
rm -f "$CSV"

# Originalbestand unberuehrt beiseitelegen, frisch entpacken
mv /opt/fsc-test /opt/fsc-test.unberuehrt
tar xzpf "$ARCHIV" -C /
ANZ=$(ls /opt/fsc-test | wc -l)
QUELLE=$(findmnt -no SOURCE /opt/fsc-test)
echo "Objekte: $ANZ, Traeger: $QUELLE"
case "$QUELLE" in *sdb*|*sdc*) echo "FEHLER: liegt auf Zusatzplatte, Abbruch."; exit 1 ;; esac
[ "$ANZ" = "201" ] || { echo "FEHLER: nicht 201 Objekte, Abbruch."; exit 1; }

datenbanken_neu
for runde in $(seq 1 30); do
  for werkzeug in aide samhain tripwire shellskript; do
    START=$(date +%s%N)
    case "$werkzeug" in
      aide)        aide --config=/etc/aide/aide-fsc.conf --check > /dev/null 2>&1 ;;
      samhain)     samhain -t check --foreground -p none > /dev/null 2>&1 ;;
      tripwire)    tripwire --check > /dev/null 2>&1 ;;
      shellskript) /usr/local/sbin/fsc-simple-check-v2.sh check > /dev/null 2>&1 ;;
    esac
    END=$(date +%s%N)
    echo "systemvolume_frisch;${werkzeug};${runde};$(( (END - START) / 1000000 ))" >> "$CSV"
  done
  sleep 1
done

# Ausgangszustand wiederherstellen
rm -rf /opt/fsc-test
mv /opt/fsc-test.unberuehrt /opt/fsc-test
datenbanken_neu
systemctl start wazuh-agent osqueryd

echo; echo "=== Fertig ==="
awk -F';' '$3>1 {v[$2]=v[$2]" "$4} END {for (w in v) print w, v[w]}' "$CSV"
