#!/bin/bash
# Haelt die Reihenfolge Tripwire vor Samhain bei 20.000 Objekten, wenn beide
# dasselbe Hashverfahren verwenden? Open Source Tripwire unterstuetzt laut
# twpolicy(4) nur CRC-32, Haval, MD5 und SHA, kein SHA-256; in der Hauptmessung
# lief Tripwire daher mit SHA-1, Samhain mit SHA-256.
# Diese Samhain-Version hat keinen Schalter fuer eine andere Konfigurationsdatei,
# deshalb wird /etc/samhain/samhainrc geaendert und am Ende zurueckgesetzt.
# Aufruf: /root/kontrolle_hash.sh 'TRIPWIRE-LOCAL-PASSPHRASE'
PASS="$1"; [ -z "$PASS" ] && { echo "FEHLER: Passphrase fehlt."; exit 1; }
RC=/etc/samhain/samhainrc
BAK=/root/samhainrc.backup.hash
CSV=/root/kontrolle_hash.csv
cp -a "$RC" "$BAK" || exit 1
echo "Sicherung: $BAK"
trap 'cp -a "$BAK" "$RC"; echo "Konfiguration zurueckgesetzt (Abbruch)"' EXIT
systemctl stop wazuh-agent osqueryd
rm -f "$CSV"

echo "Fuelle auf 20000 Objekte auf, das dauert einige Minuten ..."
cd /opt/fsc-test
i=$(ls scale_*.bin 2>/dev/null | wc -l)
while [ $(ls | wc -l) -lt 20000 ]; do
  i=$((i+1)); dd if=/dev/urandom of=scale_$i.bin bs=1K count=$((RANDOM % 100 + 1)) status=none
done
chmod 0644 scale_*.bin
ANZ=$(ls /opt/fsc-test | wc -l); echo "Bestand: $ANZ Objekte, $(du -sh /opt/fsc-test | cut -f1)"
[ "$ANZ" = "20000" ] || { echo "FEHLER: nicht 20000 Objekte."; exit 1; }

cd /root
rm -f /var/lib/tripwire/fsc-target.twd
echo "Tripwire-Datenbank wird aufgebaut ..."
tripwire --init -P "$PASS" > /dev/null 2>&1
[ -s /var/lib/tripwire/fsc-target.twd ] || { echo "FEHLER: Tripwire-Datenbank fehlt."; exit 1; }

messblock () {
  ALGO="$1"
  sed -i "s/^DigestAlgo=.*/DigestAlgo=$ALGO/" "$RC"
  echo "--- Block $ALGO: $(grep '^DigestAlgo=' $RC) ---"
  rm -f /var/lib/samhain/samhain-fsc.file
  samhain -t init --foreground -p none
  [ -s /var/lib/samhain/samhain-fsc.file ] || { echo "FEHLER: Samhain-Datenbank fehlt."; exit 1; }
  for runde in $(seq 1 10); do
    for arm in tripwire samhain; do
      START=$(date +%s%N)
      case "$arm" in
        tripwire) tripwire --check > /dev/null 2>&1 ;;
        samhain)  samhain -t check --foreground -p none > /dev/null 2>&1 ;;
      esac
      END=$(date +%s%N)
      echo "${ALGO};${arm};${runde};$(( (END - START) / 1000000 ))" >> "$CSV"
    done
    sleep 1
  done
}

messblock SHA256
messblock SHA1

echo "Raeume auf ..."
rm -f /opt/fsc-test/scale_*.bin
echo "Bestand: $(ls /opt/fsc-test | wc -l) Objekte"
cp -a "$BAK" "$RC"; trap - EXIT
echo "Konfiguration wiederhergestellt: $(grep '^DigestAlgo=' $RC)"
aide --config=/etc/aide/aide-fsc.conf --init > /dev/null 2>&1
mv -f /var/lib/aide/aide-fsc.db.new /var/lib/aide/aide-fsc.db
rm -f /var/lib/samhain/samhain-fsc.file
samhain -t init --foreground -p none > /dev/null 2>&1
/usr/local/sbin/fsc-simple-check-v2.sh init > /dev/null 2>&1
rm -f /var/lib/tripwire/fsc-target.twd
tripwire --init -P "$PASS" > /dev/null 2>&1
systemctl start wazuh-agent osqueryd
cp "$CSV" /home/lukas/ ; chown lukas /home/lukas/kontrolle_hash.csv

echo; echo "=== Ergebnis ==="
awk -F';' '$3>1 {k=$1"_"$2; v[k]=v[k]" "$4} END {for (a in v) print a, v[a]}' "$CSV"
