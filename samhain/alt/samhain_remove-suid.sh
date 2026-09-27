#!/bin/bash
# Externes Reaktionsskript fuer Samhain im Werkzeugvergleich
# Samhain ruft dieses Skript bei Alarm auf und uebergibt die Meldung
# ueber die Standardeingabe

LOGFILE="/var/log/samhain-reaktion.log"

while read ZEILE; do
  echo "$(date -Iseconds) EINGANG: $ZEILE" >> "$LOGFILE"

  # Dateipfad aus der Meldung extrahieren
  DATEI=$(echo "$ZEILE" | grep -oP 'path=<\K[^>]+')

  case "$DATEI" in
    /opt/fsc-test/*)
      MODUS_VORHER=$(stat -c '%a' "$DATEI" 2>/dev/null)
      chmod u-s "$DATEI" 2>/dev/null
      MODUS_NACHHER=$(stat -c '%a' "$DATEI" 2>/dev/null)
      echo "$(date -Iseconds) SUID entfernt: $DATEI $MODUS_VORHER -> $MODUS_NACHHER" >> "$LOGFILE"
      ;;
  esac
done
