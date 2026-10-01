#!/bin/bash
# Gegenprobe im anderen Werkzeug: gleiches AIDE, gleicher Ablauf,
# einzige Variable = ctime (c) in der Attributmaske FSCRULE.
Z=/opt/fsc-test/testbinary
C0=/etc/aide/aide-fsc.conf                 # ohne c  (Originalmaske)
C1=/etc/aide/aide-fsc-ctime.conf           # mit  c
CSV=/root/aide_kontrolle.csv
LOG=/root/aide_kontrolle_detail.log

sed -e 's|^FSCRULE *=.*|FSCRULE = p+u+g+s+i+n+c+sha256|' \
    -e 's|aide-fsc\.db|aide-fsc-c.db|g' "$C0" > "$C1"
grep -E '^(FSCRULE|database)' "$C1"

ende(){ chmod 0755 $Z; systemctl start wazuh-agent; }
trap ende EXIT
systemctl stop wazuh-agent; sleep 2
chmod 0755 $Z
echo "block,arm,fall,lauf,erkannt" > $CSV
: > $LOG

init(){ aide --config="$1" --init >/dev/null 2>&1
        D=$(sed -n 's|^database_new *= *file:||p' "$1")
        mv -f "$D" "${D%.new}"; }

for B in 1 2 3 4; do
 for ARM in ohne mit; do
  [ $ARM = ohne ] && CF=$C0 || CF=$C1
  for L in 1 2 3 4 5 6 7; do
    [ $L -le 5 ] && FALL=rueckgenommen || FALL=persistent
    init "$CF"
    sleep 1.2
    chmod 4755 $Z
    sleep 0.2
    [ $FALL = rueckgenommen ] && chmod 0755 $Z
    OUT=$(aide --config="$CF" --check 2>&1 | grep -F "$Z")
    echo "$B $ARM $FALL $L :: $OUT" >> $LOG
    [ -n "$OUT" ] && E=1 || E=0
    echo "$B,$ARM,$FALL,$L,$E" | tee -a $CSV
    chmod 0755 $Z
  done
 done
done
ende
echo "FERTIG"
