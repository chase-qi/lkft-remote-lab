#!/bin/sh

BASE=/sys/class/leds/user_led
echo none > ${BASE}1/trigger
echo none > ${BASE}2/trigger
echo none > ${BASE}3/trigger
echo none > ${BASE}4/trigger

STATE=1
while true; do
    case $STATE in
        1)
            echo 255 > ${BASE}1/brightness
            echo 0 > ${BASE}2/brightness
            STATE=2
            ;;
        2)
            echo 255 > ${BASE}2/brightness
            echo 0 > ${BASE}1/brightness
            STATE=3
            ;;
        3)
            echo 255 > ${BASE}3/brightness
            echo 0 > ${BASE}2/brightness
            STATE=4
            ;;
        4)
            echo 255 > ${BASE}4/brightness
            echo 0 > ${BASE}3/brightness
            STATE=5
            ;;
        5)
            echo 255 > ${BASE}3/brightness
            echo 0 > ${BASE}4/brightness
            STATE=6
            ;;
        6)
            echo 255 > ${BASE}2/brightness
            echo 0 > ${BASE}3/brightness
            STATE=1
            ;;
        *)
            echo 255 > ${BASE}1/brightness
            echo 0   > ${BASE}2/brightness
            STATE=2
            ;;
    esac
    sleep 0.1
done
