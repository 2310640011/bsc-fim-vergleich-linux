#!/usr/bin/env python3
# ===========================================================================
# auswertung.py
#
# Was dieses Skript macht:
#   Es liest die Messdaten aus dem Ordner messung_20260922 und rechnet daraus
#   die Zahlen aus, die in Kapitel 4 der Arbeit stehen: fuer jede Messreihe
#   den Median (den mittleren Wert), den kleinsten und den groessten Wert.
#
# Wie man es startet:
#   python3 auswertung.py messung_20260922/
#
# Was man dafuer braucht:
#   Nur Python 3. Keine zusaetzlichen Pakete.
#
# Die Regeln, nach denen gerechnet wird, stehen in Kapitel 3.2.7 der Arbeit:
#   - Bei den Scan-, Ressourcen- und osquery-Messungen wird die erste Runde
#     weggelassen. Sie gilt als Warmlauf, weil das System beim ersten Mal
#     noch Daten in den Speicher laden muss.
#   - Bei der Wazuh-Messung werden alle 30 Runden verwendet. Dort gab es
#     keinen Warmlauf-Effekt.
#   - Der Median ist der Wert in der Mitte, wenn man alle Messwerte der
#     Groesse nach sortiert. Er wird statt des Durchschnitts verwendet,
#     weil ihn einzelne Ausreisser nicht verfaelschen.
# ===========================================================================

import csv          # zum Lesen der CSV-Dateien
import statistics   # fuer den Median
import sys          # fuer den Ordnernamen aus der Kommandozeile

# Der Ordner mit den Messdaten wird beim Aufruf mitgegeben.
if len(sys.argv) != 2:
    print("Aufruf: python3 auswertung.py messung_20260922/")
    sys.exit(1)
ordner = sys.argv[1].rstrip("/")


# ---------------------------------------------------------------------------
# Kleine Hilfe: eine CSV-Datei lesen.
# Alle Messdateien verwenden das Semikolon als Trennzeichen.
# Die Funktion gibt eine Liste von Zeilen zurueck, jede Zeile ist eine Liste
# der einzelnen Felder als Text.
# ---------------------------------------------------------------------------
def lese(dateiname):
    with open(ordner + "/" + dateiname, newline="") as f:
        return [zeile for zeile in csv.reader(f, delimiter=";") if zeile]


# ---------------------------------------------------------------------------
# Kleine Hilfe: Median, Minimum, Maximum und Anzahl einer Liste ausgeben.
# ---------------------------------------------------------------------------
def zeige(name, werte, einheit):
    print(f"  {name:26s} n={len(werte):2d}  Median={statistics.median(werte):7.1f} {einheit}  "
          f"Min={min(werte):7.1f} {einheit}  Max={max(werte):7.1f} {einheit}")


# ===========================================================================
# 1. SCAN-DAUER
#
# Datei: messung_scandauer_30.csv
# Jede Zeile:  werkzeug;runde;millisekunden
# Beispiel:    aide;5;52
#
# Gemessen wurde, wie lange ein Pruefdurchlauf dauert. 30 Runden, in jeder
# Runde alle vier Werkzeuge nacheinander. Runde 1 wird weggelassen.
# ===========================================================================
print("\n1. Scan-Dauer je Pruefdurchlauf (Runde 1 weggelassen)")

# Fuer jedes Werkzeug eine leere Liste, in die die Messwerte kommen
scan = {"aide": [], "samhain": [], "tripwire": [], "shellskript": []}

for werkzeug, runde, ms in lese("messung_scandauer_30.csv"):
    if runde == "1":
        continue                       # Warmlauf ueberspringen
    scan[werkzeug].append(int(ms))     # Millisekunden als Zahl merken

for werkzeug in scan:
    zeige(werkzeug, scan[werkzeug], "ms")


# ===========================================================================
# 2. MELDELATENZ OSQUERY
#
# Dateien: messung_osquery_int1_30.csv  und  messung_osquery_int10_30.csv
# Jede Zeile:  name;runde;millisekunden
# Beispiel:    osquery_int1;7;984
#
# Gemessen wurde, wie lange es dauert, bis eine Dateiaenderung im Log von
# osquery erscheint. Einmal mit Abfrageintervall 1 Sekunde, einmal mit
# 10 Sekunden. Runde 1 wird weggelassen.
# ===========================================================================
print("\n2. Meldelatenz osquery (Runde 1 weggelassen)")

for dateiname, name in [("messung_osquery_int1_30.csv",  "osquery, 1-s-Intervall"),
                        ("messung_osquery_int10_30.csv", "osquery, 10-s-Intervall")]:
    werte = []
    for _, runde, ms in lese(dateiname):
        if runde == "1":
            continue                   # Warmlauf ueberspringen
        werte.append(int(ms))
    zeige(name, werte, "ms")


# ===========================================================================
# 3. REAKTIONSZEIT WAZUH
#
# Datei: messung_wazuh_ar_30.csv
# Jede Zeile:  name;runde;millisekunden;status
# Beispiel:    wazuh_ar;3;46;ok
#
# Gemessen wurde, wie lange es von der Dateiaenderung bis zur automatischen
# Korrektur durch Wazuh dauert. Alle 30 Runden werden verwendet.
# "ok" am Ende heisst: die Korrektur hat stattgefunden.
# ===========================================================================
print("\n3. Reaktionszeit Wazuh (alle 30 Runden)")

werte = []
for _, _, ms, status in lese("messung_wazuh_ar_30.csv"):
    if status == "ok":
        werte.append(int(ms))
zeige("Wazuh, Reaktionskette", werte, "ms")


# ===========================================================================
# 4. RESSOURCENVERBRAUCH JE SCAN
#
# Datei: messung_ressourcen_30.csv
# Jede Zeile:  werkzeug;runde;benutzerzeit;systemzeit;speicher_kb
# Beispiel:    tripwire;12;0.39;0.00;7508
#
# Benutzerzeit = Sekunden, die das Programm selbst gerechnet hat
# Systemzeit   = Sekunden, die der Kernel fuer das Programm gearbeitet hat
#                (z. B. Dateien oeffnen, Prozesse starten)
# speicher_kb  = groesster Speicherbedarf waehrend des Laufs in Kilobyte
#
# CPU-Zeit gesamt = Median Benutzerzeit + Median Systemzeit
# Speicher wird von Kilobyte in Megabyte umgerechnet (geteilt durch 1024).
# Runde 1 wird weggelassen.
# ===========================================================================
print("\n4. Ressourcenverbrauch je Pruefdurchlauf (Runde 1 weggelassen)")

res = {"aide": {"user": [], "sys": [], "kb": []},
       "samhain": {"user": [], "sys": [], "kb": []},
       "tripwire": {"user": [], "sys": [], "kb": []},
       "shellskript": {"user": [], "sys": [], "kb": []}}

for werkzeug, runde, user, sysz, kb in lese("messung_ressourcen_30.csv"):
    if runde == "1":
        continue                       # Warmlauf ueberspringen
    res[werkzeug]["user"].append(float(user))
    res[werkzeug]["sys"].append(float(sysz))
    res[werkzeug]["kb"].append(int(kb))

for werkzeug in res:
    user_median = statistics.median(res[werkzeug]["user"])
    sys_median = statistics.median(res[werkzeug]["sys"])
    mb = statistics.median(res[werkzeug]["kb"]) / 1024
    print(f"  {werkzeug:14s} CPU user={user_median:.2f}s  sys={sys_median:.2f}s  "
          f"gesamt={user_median + sys_median:.2f}s   Speicher={mb:.1f} MB")


# ===========================================================================
# 5. LASTTEST
#
# Datei: messung_lasttest_fein.csv
# Jede Zeile:  phase;prozess;benutzer_ticks;system_ticks
# Beispiel:    vorher;wazuh-syscheckd;715;327
#              nachher;wazuh-syscheckd;724;328
#
# Vor und nach 200 schnellen Dateiaenderungen wurde abgelesen, wie viel
# CPU-Zeit die dauerhaft laufenden Prozesse bis dahin verbraucht hatten.
# Die Differenz "nachher minus vorher" ist die Zeit, die die 200 Aenderungen
# gekostet haben.
#
# Die Zahlen sind "Ticks". Das System zaehlt 100 Ticks pro Sekunde,
# ein Tick ist also 10 Millisekunden.
# ===========================================================================
print("\n5. Lasttest: CPU-Zeit fuer 200 Dateiaenderungen")

vorher = {}
nachher = {}
for phase, prozess, user, sysz in lese("messung_lasttest_fein.csv"):
    ticks = int(user) + int(sysz)      # beide Anteile zusammenzaehlen
    if phase == "vorher":
        vorher[prozess] = ticks
    else:
        nachher[prozess] = ticks

wazuh_gesamt = 0
osquery_gesamt = 0
for prozess in vorher:
    ms = (nachher[prozess] - vorher[prozess]) * 10     # Ticks -> Millisekunden
    print(f"  {prozess:22s} {ms:5d} ms")
    if prozess.startswith("wazuh"):
        wazuh_gesamt += ms
    else:
        osquery_gesamt += ms
print(f"  {'Wazuh gesamt':22s} {wazuh_gesamt:5d} ms")
print(f"  {'osquery gesamt':22s} {osquery_gesamt:5d} ms")


# ===========================================================================
# 6. DAUERBETRIEB
#
# Datei: messung_dauerbetrieb_30.csv
# Jede Zeile:  messpunkt;zeitstempel;werkzeug;prozess;speicher_kb;ticks
# Beispiel:    1;1790108554;wazuh;wazuh-agentd;9476;69
#
# Ueber zehn Minuten wurde jede Minute abgelesen, wie viel Speicher die
# Prozesse von Wazuh und osquery belegen und wie viel CPU-Zeit sie bisher
# verbraucht haben. Das System war dabei im Leerlauf.
#
# Speicher: die Werte aller Prozesse eines Werkzeugs beim ersten Messpunkt
#           werden zusammengezaehlt und in Megabyte umgerechnet.
# CPU:      Ticks beim letzten Messpunkt minus Ticks beim ersten Messpunkt,
#           mal 10 = Millisekunden, die in den neun Minuten verbraucht wurden.
# ===========================================================================
print("\n6. Dauerbetrieb im Leerlauf (Messpunkt 1 bis 10)")

speicher_kb = {"wazuh": 0, "osquery": 0}
ticks_erster = {"wazuh": 0, "osquery": 0}
ticks_letzter = {"wazuh": 0, "osquery": 0}

for messpunkt, _, werkzeug, _, kb, ticks in lese("messung_dauerbetrieb_30.csv"):
    if messpunkt == "1":
        speicher_kb[werkzeug] += int(kb)
        ticks_erster[werkzeug] += int(ticks)
    if messpunkt == "10":
        ticks_letzter[werkzeug] += int(ticks)

for werkzeug in speicher_kb:
    mb = speicher_kb[werkzeug] / 1024
    cpu_ms = (ticks_letzter[werkzeug] - ticks_erster[werkzeug]) * 10
    print(f"  {werkzeug:10s} Speicher={mb:5.1f} MB   CPU in 9 Minuten={cpu_ms:4d} ms")

print()
