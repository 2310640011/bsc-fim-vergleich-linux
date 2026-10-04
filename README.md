# Begleitdaten zur Bachelorarbeit

Vergleich von Werkzeugen zur Überwachung der Dateisystemintegrität unter Linux
Lukas Kogler, Matrikelnummer 2310640011, FH Burgenland

Alle Messdaten, Messskripte, Konfigurationen und Protokolle zur Arbeit.
`SHA256SUMS` im Hauptverzeichnis deckt sämtliche Dateien ab:

    sha256sum -c SHA256SUMS

## Messreihen

- `messung_20260922` – endgültige Messreihen mit 30 Durchläufen: Scan-Dauer,
  Ressourcen, Dauerbetrieb, Lasttest, osquery-Meldelatenz, Wazuh-Reaktionszeit
- `skalierung_20260926` – Skalierungsmessung mit 2.000 und 20.000 Objekten
- `ablage_20260927` – Kontrollmessungen zu Ablage und Dateisystem,
  zum Prüfsummenverfahren und zum Ressourcenverbrauch
- `ereignisbasiert_20260927` – Samhain im inotify-Modus, Test auf Fehlalarme,
  erster Einzelfall einer zurückgenommenen Änderung
- `transienz_20261001` – 120 Läufe zur zurückgenommenen Änderung über
  sechs Zeitfenster
- `attributkontrolle_20261001` – Kontrollmessung mit veränderter
  Attributmenge in AIDE und Samhain
- `vorversuch_10_durchlaeufe` – Vorversuche mit zehn Durchläufen,
  unverändert erhalten

## Werkzeugbezogene Belege

`aide`, `Tripwire`, `samhain`, `osquery`, `wazuh` – Protokolle zum
Erkennungsumfang, zur Reaktionsfähigkeit und die Reaktionsskripte.

## Weiteres

- `konfigurationen` – eingesetzte Konfigurationsdateien aller Werkzeuge
  sowie das Skript der Kontrollimplementierung
- `auswertung.py` – berechnet die in Kapitel 4 angegebenen Kennwerte
- `messprotokoll.txt` – Systemdaten und Werkzeugversionen
