#!/bin/bash
# messung_skalierung.sh
#
# Skalierungsmessung der Scan-Dauer, durchgefuehrt am 26.09.2026 auf fsc-target.
# Die vier Bloecke wurden nacheinander als root eingegeben, einmal fuer
# 2.000 und einmal fuer 20.000 Objekte. Die Zusatzdateien liegen flach im
# Testverzeichnis, deshalb musste keine Werkzeugkonfiguration geaendert werden.
# Ergebnis: messung_skalierung.csv (bestand;werkzeug;runde;millisekunden)

# --- Block 1: Dienste anhalten, Zusatzdateien erzeugen -----------------------
# Wazuh-Agent und osquery ueberwachen /opt/fsc-test per inotify. Tausende neue
# Dateien wuerden entsprechend viele Ereignisse erzeugen und die Messung stoeren.
systemctl stop wazuh-agent osqueryd

# Zufallsdateien anlegen, bis der Bestand die Zielgroesse hat (2000 bzw. 20000).
# Groesse 1 bis 100 KB, Eigentuemer root, Modus 0644 - wie die urspruenglichen Dateien.
cd /opt/fsc-test
i=$(ls scale_*.bin 2>/dev/null | wc -l)
while [ $(ls | wc -l) -lt 2000 ]; do        # zweiter Durchgang: 20000
  i=$((i+1))
  dd if=/dev/urandom of=scale_$i.bin bs=1K count=$((RANDOM % 100 + 1)) status=none
done
chmod 0644 scale_*.bin
echo "Bestand: $(ls | wc -l) Objekte, $(du -sh . | cut -f1)"
# Ausgabe: "Bestand: 2000 Objekte, 103M"  bzw.  "Bestand: 20000 Objekte, 1018M"

# --- Block 2: Referenzdatenbanken neu aufbauen --------------------------------
# Dieselben Befehle wie vor der Hauptmessung. Tripwire fragt nach der Passphrase.
aide --config=/etc/aide/aide-fsc.conf --init > /dev/null 2>&1
mv /var/lib/aide/aide-fsc.db.new /var/lib/aide/aide-fsc.db
rm -f /var/lib/samhain/samhain-fsc.file
samhain -t init --foreground -p none > /dev/null 2>&1
/usr/local/sbin/fsc-simple-check-v2.sh init > /dev/null 2>&1
rm -f /var/lib/tripwire/fsc-target.twd
tripwire --init

# --- Block 3: Messung, 10 Runden ----------------------------------------------
# Gleiche Zeitmessung wie bei der Hauptmessung (date +%s%N, Ausgabe in ms),
# nur 10 statt 30 Runden. Vorne in jeder Zeile steht die Bestandsgroesse.
cd /root
BESTAND=$(ls /opt/fsc-test | wc -l)
for runde in $(seq 1 10); do
  for werkzeug in aide samhain tripwire shellskript; do
    START=$(date +%s%N)
    case "$werkzeug" in
      aide)        aide --config=/etc/aide/aide-fsc.conf --check > /dev/null 2>&1 ;;
      samhain)     samhain -t check --foreground -p none > /dev/null 2>&1 ;;
      tripwire)    tripwire --check > /dev/null 2>&1 ;;
      shellskript) /usr/local/sbin/fsc-simple-check-v2.sh check > /dev/null 2>&1 ;;
    esac
    END=$(date +%s%N)
    echo "${BESTAND};${werkzeug};${runde};$(( (END - START) / 1000000 ))" >> /root/messung_skalierung.csv
  done
  sleep 1
done

# --- Block 4: Aufraeumen (nach dem letzten Durchgang) -------------------------
# Zusatzdateien loeschen, Datenbanken fuer die 201 Objekte neu aufbauen (Block 2),
# Dienste wieder starten.
rm -f /opt/fsc-test/scale_*.bin
echo "Bestand: $(ls /opt/fsc-test | wc -l) Objekte"     # muss 201 sein
# ... Block 2 erneut ...
systemctl start wazuh-agent osqueryd
