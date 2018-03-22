#!/bin/sh -ex
# Based on https://github.com/RobertCNelson/boot-scripts/blob/master/tools/eMMC/functions.sh#L695

BASE=/sys/class/leds/user_led
for i in $(seq 4); do
    echo none > "${BASE}$i/trigger"
done

TIMEOUT="$1"
end=$(( $(date +%s) + TIMEOUT ))
state=1
while [ "$(date +%s)" -lt "$end" ]; do
    case $state in
        1)
            echo 255 > ${BASE}1/brightness
            echo 0 > ${BASE}2/brightness
            state=2
            ;;
        2)
            echo 255 > ${BASE}2/brightness
            echo 0 > ${BASE}1/brightness
            state=3
            ;;
        3)
            echo 255 > ${BASE}3/brightness
            echo 0 > ${BASE}2/brightness
            state=4
            ;;
        4)
            echo 255 > ${BASE}4/brightness
            echo 0 > ${BASE}3/brightness
            state=5
            ;;
        5)
            echo 255 > ${BASE}3/brightness
            echo 0 > ${BASE}4/brightness
            state=6
            ;;
        6)
            echo 255 > ${BASE}2/brightness
            echo 0 > ${BASE}3/brightness
            state=1
            ;;
        *)
            echo 255 > ${BASE}1/brightness
            echo 0   > ${BASE}2/brightness
            state=2
            ;;
    esac
    sleep 0.1
done
