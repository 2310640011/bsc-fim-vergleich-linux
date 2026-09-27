#!/bin/bash
# Kontrollmessung mit veränderter Ressourcenausstattung, unveränderter Bestand.
# Aufruf: /root/kontrolle_ressourcen.sh 'LOCAL-PASSPHRASE'
PASS="$1"; [ -z "$PASS" ] && { echo "FEHLER: Passphrase fehlt."; exit 1; }
CSV=/root/kontrolle_ressourcen.csv
CPU=$(nproc); RAM=$(free -m | awk '/^Mem:/{print $2}')
echo "Konfiguration: ${CPU} vCPU, ${RAM} MB"
systemctl stop wazuh-agent osqueryd
rm -f "$CSV"
aide --config=/etc/aide/aide-fsc.conf --init > /dev/null 2>&1
mv -f /var/lib/aide/aide-fsc.db.new /var/lib/aide/aide-fsc.db
rm -f /var/lib/samhain/samhain-fsc.file
samhain -t init --foreground -p none > /dev/null 2>&1
/usr/local/sbin/fsc-simple-check-v2.sh init > /dev/null 2>&1
rm -f /var/lib/tripwire/fsc-target.twd
tripwire --init -P "$PASS" > /dev/null 2>&1
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
    echo "${CPU}cpu_${RAM}mb;${werkzeug};${runde};$(( (END - START) / 1000000 ))" >> "$CSV"
  done
  sleep 1
done
systemctl start wazuh-agent osqueryd
cp "$CSV" /home/lukas/ ; chown lukas /home/lukas/kontrolle_ressourcen.csv
echo; awk -F';' '$3>1 {v[$2]=v[$2]" "$4} END {for (w in v) print w, v[w]}' "$CSV"
