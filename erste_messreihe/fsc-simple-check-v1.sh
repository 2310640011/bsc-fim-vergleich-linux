#!/bin/bash
# Einfache Integritaetspruefung als Vergleichsmassstab
# Bildet nach, was sich mit Bordmitteln und einem Cronjob umsetzen laesst:
# Referenzdatenbank anlegen, spaeter dagegen vergleichen

VERZEICHNIS="/opt/fsc-test"
DATENBANK="/var/lib/fsc-simple/referenz.txt"
MODUS="$1"

mkdir -p "$(dirname "$DATENBANK")"

# Erfasst je Datei: Rechte, Eigentuemer, Gruppe, Groesse, Inode und SHA-256
erfassen() {
  find "$VERZEICHNIS" -type f -printf '%p|%m|%U|%G|%s|%i|' -exec sha256sum {} \; \
    | awk '{print $1}' | sort
}

case "$MODUS" in
  init)
    erfassen > "$DATENBANK"
    echo "Referenzdatenbank angelegt: $(wc -l < "$DATENBANK") Eintraege"
    ;;
  check)
    AKTUELL=$(mktemp)
    erfassen > "$AKTUELL"
    diff "$DATENBANK" "$AKTUELL"
    ERGEBNIS=$?
    rm -f "$AKTUELL"
    exit $ERGEBNIS
    ;;
  *)
    echo "Aufruf: $0 {init|check}"
    exit 1
    ;;
esac
