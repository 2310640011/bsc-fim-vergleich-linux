# Werkzeugvergleich Dateisystemintegrität unter Linux

Begleitmaterial zur Bachelorarbeit „Vergleich von Werkzeugen zur Überwachung der
Dateisystemintegrität unter Linux“ (Lukas Kogler, FH Burgenland, 2026).

## Untersuchte Ansätze

| Ansatz | Version im Labor | Architekturprinzip |
|---|---|---|
| AIDE | 0.19.2 | periodischer Vergleich mit Referenzdatenbank |
| Open Source Tripwire | 2.4.3.7 | periodischer Vergleich mit Referenzdatenbank |
| Samhain | 4.1.4 | periodischer Vergleich, Scan-Modus |
| Wazuh FIM | siehe messprotokoll.txt | ereignisbasiert über inotify |
| osquery | 5.23.1 | abfragebasiert, Erfassung über inotify |
| Kontrollimplementierung | fsc-simple-check-v2.sh | periodischer Vergleich, eigenes Shell-Skript |

## Struktur

    aide/ Tripwire/ samhain/     Logs, Konfigurationen und Reaktionsskripte
    osquery/ wazuh/              je Werkzeug
    messung_20260922/            Hauptmessung, 30 Durchläufe
    vorversuch_10_durchlaeufe/   Vorversuche, 10 Durchläufe
    skalierung_20260926/         Skalierungsmessung, 2.000 und 20.000 Objekte
    ablage_20260927/             Dateisystem, Speicherort, Hashverfahren
    ereignisbasiert_20260927/    inotify-Reaktionszeit, zurueckgenommene Aenderung
    konfigurationen/             Konfigurationsdateien zum Stand der Messungen
    alt/                         Material der Vorversuche vom 19.09.2026
    messprotokoll.txt            Systemdaten, Dateisysteme, Werkzeugversionen
    auswertung.py                berechnet die Kennwerte aus Kapitel 4
    SHA256SUMS                   Prüfsummen aller Dateien

Die Unterordner alt/ innerhalb der Werkzeugordner enthalten Logs und
Konfigurationen der Vorversuche vom 19.09.2026. Maßgeblich für die in der Arbeit
genannten Werte sind messung_20260922, skalierung_20260926 , ablage_20260927 und ereignisbasiert_20260927.

## Aufbau

Alle Messungen liefen auf der virtuellen Maschine fsc-target (Ubuntu) mit dem
überwachten Verzeichnis /opt/fsc-test, 201 Objekte, etwa 12 MB. Die Inhaltsprüfung
war für alle scanbasierten Ansätze auf SHA-256 vereinheitlicht. Der Wazuh-Manager
lief auf einer separaten virtuellen Maschine. Systemdaten und Werkzeugversionen
stehen in messprotokoll.txt. Der erste Durchlauf jeder Messreihe wurde als
Warmlauf ausgeschlossen.

## Reproduktion

    python3 auswertung.py
    sha256sum -c SHA256SUMS

Die Messskripte in skalierung_20260926/ und ablage_20260927/ sind blockweise
kommentiert. Sie sind nicht in einem Zug lauffähig, weil Tripwire beim Aufbau der
Referenzdatenbank eine Passphrase benötigt.

## Hinweis

ablage_20260927/verworfen_202objekte.csv enthält eine verworfene Messreihe. Der
ext4-Datenträger hatte durch lost+found 202 statt 201 Objekte; die Messung wurde
nach Korrektur wiederholt und ist hier nur zur Vollständigkeit dokumentiert.
