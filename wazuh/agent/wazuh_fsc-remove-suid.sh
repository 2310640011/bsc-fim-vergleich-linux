#!/bin/bash
# Active-Response-Skript fuer den Werkzeugvergleich
# Entfernt das SUID-Bit von einer Datei im Testverzeichnis
# Wazuh uebergibt die Alert-Daten als JSON ueber stdin,
# der betroffene Pfad steht im syscheck-Abschnitt unter "path"

LOGFILE="/var/ossec/logs/fsc-active-response.log"

read INPUT

# Dateipfad aus dem syscheck-Abschnitt des JSON extrahieren
DATEI=$(echo "$INPUT" | grep -oP '"syscheck":\{"path":"\K[^"]+')

case "$DATEI" in
  /opt/fsc-test/*)
    MODUS_VORHER=$(stat -c '%a' "$DATEI" 2>/dev/null)
    chmod u-s "$DATEI" 2>/dev/null
    MODUS_NACHHER=$(stat -c '%a' "$DATEI" 2>/dev/null)
    echo "$(date -Iseconds) SUID entfernt: $DATEI $MODUS_VORHER -> $MODUS_NACHHER" >> "$LOGFILE"
    ;;
  *)
    echo "$(date -Iseconds) Ignoriert, ausserhalb Testverzeichnis: $DATEI" >> "$LOGFILE"
    ;;
esac
