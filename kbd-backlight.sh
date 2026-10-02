#!/bin/bash
echo "$1" | tee /sys/class/leds/tpacpi::kbd_backlight/brightness > /dev/null
