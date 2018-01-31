#!/usr/bin/env python
#
# Copyright (C) 2018, Linaro Limited.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# Author: Chase Qi <chase.qi@linaro.org>
#

import argparse
import time
import RPi.GPIO as GPIO


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-c', '--channel', required=True, choices=['CH1', 'CH2', 'CH3'],
                        help='Specify channel.')
    parser.add_argument('-s', '--state', required=True, choices=['on', 'off', 'reboot'],
                        help='Specify power state')

    args = parser.parse_args()
    return args


if __name__ == '__main__':
    args = parse_args()

    channel_name = args.channel
    channel_map = {'CH1': 26, 'CH2': 20, 'CH3': 21}
    channel_number = channel_map[channel_name]
    state =args.state

    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    GPIO.setup(channel_number, GPIO.OUT)

    if state == 'reboot':
        # Power off.
        GPIO.output(channel_number, GPIO.HIGH)
        print('relay-module: sent GPIO.HIGH signal to {}'.format(channel_name))
        time.sleep(1)
        # Power on.
        GPIO.output(channel_number, GPIO.LOW)
        print('relay-module: sent GPIO.LOW signal to {}'.format(channel_name))
        time.sleep(1)
        print('relay-module: rebooted channel {}'.format(channel_name))

    if state == 'off':
        GPIO.output(channel_number, GPIO.HIGH)
        print('relay-module: sent GPIO.HIGH signal to {}'.format(channel_name))
        time.sleep(1)
        print('relay-module: powered off channel {}'.format(channel_name))

    if state == 'on':
        GPIO.output(channel_number, GPIO.LOW)
        print('relay-module: sent GPIO.LOW signal to {}'.format(channel_name))
        time.sleep(1)
        print('relay-module: powered on channel {}'.format(channel_name))
