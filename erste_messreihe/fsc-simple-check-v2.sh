#!/bin/bash
# Einfache Integritaetspruefung als Vergleichsmassstab, korrigierte Fassung
#
# Diese Version behebt einen Fehler der ersten Fassung:
# Dort wurden die Dateirechte mit %m ausgegeben, was nur drei Oktalstellen
# liefert (z.B. 755). Das SUID-Bit steht aber in der vierten Stelle (4755)
# und ging dadurch verloren. Mit %04m werden alle vier Stellen erfasst.

VERZEICHNIS="/opt/fsc-test"
DATENBANK="/var/lib/fsc-simple/referenz-v2.txt"
MODUS="$1"

mkdir -p "$(dirname "$DATENBANK")"

# Erfasst je Datei folgende Attribute, getrennt durch senkrechte Striche:
#   %p    = vollstaendiger Pfad
#   %04m  = Rechte als vierstellige Oktalzahl, inklusive SUID/SGID/Sticky
#   %U    = numerische Benutzer-ID des Eigentuemers
#   %G    = numerische Gruppen-ID
#   %s    = Dateigroesse in Bytes
#   %i    = Inode-Nummer
# Anschliessend wird die SHA-256-Pruefsumme des Inhalts angehaengt.
erfassen() {
  find "$VERZEICHNIS" -type f -printf '%p|%04m|%U|%G|%s|%i|' -exec sha256sum {} \; \
    | awk '{print $1}' | sort
}

case "$MODUS" in
  init)
    # Referenzzustand erfassen und ablegen
    erfassen > "$DATENBANK"
    echo "Referenzdatenbank angelegt: $(wc -l < "$DATENBANK") Eintraege"
    ;;
  check)
    # Aktuellen Zustand erfassen und gegen die Referenz vergleichen
    # diff zeigt mit < die Referenz und mit > den aktuellen Stand
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
