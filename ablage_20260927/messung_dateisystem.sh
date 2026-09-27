#!/bin/bash
# Scan-Dauer auf zwei Dateisystemen, fsc-target, 27.09.2026.
# Aufruf: /root/messung_dateisystem.sh 'LOCAL-PASSPHRASE'
# Ergebnis: /root/messung_dateisystem.csv (dateisystem;werkzeug;runde;millisekunden)
# Beide Arme laufen auf frisch formatierten flachen Platten gleicher Groesse.
# Einziger Unterschied ist das Dateisystem; der Dateibestand ist byteidentisch.

PASS="$1"
[ -z "$PASS" ] && { echo "FEHLER: Passphrase fehlt."; exit 1; }
ARCHIV=/root/fsc-test-original.tar.gz
CSV=/root/messung_dateisystem.csv
[ -f "$ARCHIV" ] || { echo "FEHLER: $ARCHIV fehlt."; exit 1; }
[ "$(tar tzf $ARCHIV | grep -c '^opt/fsc-test/.')" = "201" ] || { echo "FEHLER: Archiv hat nicht 201 Objekte."; exit 1; }

systemctl stop wazuh-agent osqueryd
rm -f "$CSV"
[ -d /opt/fsc-test.orig ] || { mv /opt/fsc-test /opt/fsc-test.orig; mkdir /opt/fsc-test; }

datenbanken_neu () {
  aide --config=/etc/aide/aide-fsc.conf --init > /dev/null 2>&1
  mv -f /var/lib/aide/aide-fsc.db.new /var/lib/aide/aide-fsc.db
  rm -f /var/lib/samhain/samhain-fsc.file
  samhain -t init --foreground -p none > /dev/null 2>&1
  /usr/local/sbin/fsc-simple-check-v2.sh init > /dev/null 2>&1
  rm -f /var/lib/tripwire/fsc-target.twd
  tripwire --init -P "$PASS" > /dev/null 2>&1
}

messen () {
  FS="$1"
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
      echo "${FS};${werkzeug};${runde};$(( (END - START) / 1000000 ))" >> "$CSV"
    done
    sleep 1
  done
}

for ARM in "ext4 /dev/sdc" "xfs /dev/sdb"; do
  set -- $ARM; FS="$1"; DEV="$2"
  echo "=== Arm $FS auf $DEV ==="
  umount /opt/fsc-test 2>/dev/null
  if [ "$FS" = "ext4" ]; then mkfs.ext4 -F -q "$DEV"; else mkfs.xfs -f -q "$DEV"; fi
  mount "$DEV" /opt/fsc-test
  tar xzpf "$ARCHIV" -C /
  rmdir /opt/fsc-test/lost+found 2>/dev/null
  ANZ=$(ls /opt/fsc-test | wc -l); IST=$(findmnt -no FSTYPE /opt/fsc-test)
  echo "  Dateisystem: $IST, Objekte: $ANZ, Groesse: $(du -sh /opt/fsc-test | cut -f1)"
  if [ "$ANZ" != "201" ] || [ "$IST" != "$FS" ]; then
    echo "  FEHLER: Vorbedingung nicht erfuellt, Abbruch."; umount /opt/fsc-test; exit 1
  fi
  datenbanken_neu
  messen "$FS"
  umount /opt/fsc-test
done

rmdir /opt/fsc-test
mv /opt/fsc-test.orig /opt/fsc-test
datenbanken_neu
systemctl start wazuh-agent osqueryd

echo; echo "=== Fertig ==="
wc -l "$CSV"
cut -d';' -f1 "$CSV" | sort | uniq -c
