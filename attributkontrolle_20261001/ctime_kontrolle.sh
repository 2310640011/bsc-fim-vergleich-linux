#!/bin/bash
# Kontrollmessung innerhalb eines Werkzeugs.
# Konstant: Samhain, Datei, Ablauf, Maschine, Pruefintervall.
# Einzige Variable: ctime in der ueberwachten Attributmenge (ja/nein).
Z=/opt/fsc-test/testbinary
RC=/etc/samhain/samhainrc
DB=/var/lib/samhain/samhain-fsc.file
CSV=/root/ctime_kontrolle.csv
LOG=/root/ctime_kontrolle_detail.log
RUHE=1.2

[ -f $RC.bak ] || { echo "ABBRUCH: $RC.bak fehlt"; exit 1; }

ende(){ cp -f $RC.bak $RC; chmod 0755 $Z; systemctl start wazuh-agent; }
trap ende EXIT

arm_setzen(){                       # mit = Originalmaske, ohne = ctime entfernt
  cp -f $RC.bak $RC
  [ "$1" = ohne ] && sed -i '1i [Misc]\nRedefReadOnly=-CTM' $RC
}

systemctl stop wazuh-agent; sleep 2     # Active Response entfernt das SUID-Bit selbst
chmod 0755 $Z
echo "block,arm,fall,lauf,erkannt,maske" > $CSV
: > $LOG

for B in 1 2 3 4; do
 for ARM in mit ohne; do
  arm_setzen $ARM
  for L in 1 2 3 4 5 6 7; do
    [ $L -le 5 ] && FALL=rueckgenommen || FALL=persistent
    rm -f $DB
    samhain -t init --foreground -p none >/dev/null 2>&1
    sleep $RUHE
    chmod 4755 $Z
    sleep 0.2
    [ $FALL = rueckgenommen ] && chmod 0755 $Z
    OUT=$(samhain -t check --foreground -p err 2>&1 | grep -F "$Z")
    echo "$B $ARM $FALL $L :: $OUT" >> $LOG
    [ -n "$OUT" ] && E=1 || E=0
    M=$(sed -n 's/.*POLICY \[[^]]*\] \([-A-Z?]*\)>.*/\1/p' <<<"$OUT" | head -1)
    echo "$B,$ARM,$FALL,$L,$E,${M:--}" | tee -a $CSV
    chmod 0755 $Z
  done
 done
done
ende
echo "FERTIG"
