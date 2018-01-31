To control power and OTG on/off/reboot, the known options are:

* mass-deployment:
  * [APC PDU](http://www.apc.com/shop/us/en/categories/power-distribution/rack-power-distribution/switched-rack-pdu/_/N-17k76am)
  * [cambrionix USB hub](https://cambrionix.com/products/)

* lightweight-deployment: use power relay module controlled by GPIO.

  The guide will set up a power/OTG controller with the following components:
  * [Raspberry Pi 3](https://www.raspberrypi.org/products/raspberry-pi-3-model-b/)
  * [RPi Relay Board](http://www.waveshare.net/shop/rpi-relay-board.htm)

## Homespun switch
1. Plug RPI Relay Board to Raspberry Pi 3.
2. Install and boot Raspbian.
3. Install Python Libraries and modules.
   ```
   sudo apt-get install python-pip python-dev python-smbus python-serial python-imaging
   pip install RPi.GPIO spidev
   ```
4. Between lava-slave T440 and Raspberry Pi3, setup passwordless SSH login using SSH keygen. And please notice lava-dispatcher uses 'root' user.
5. Copy `./tools/relay-module.py` to Raspbian's `/usr/local/bin`
6. On lava-slave, try out Power or OTG on/off/reboot control with command in the following format.
   ```
   ssh pi@hostname 'relay-module.py -c {CH1,CH2,CH3} -s {on,off,reboot}'   
   ```
7. On lava-master, update the following lines defined in device dictionary with the commands tested in the above step.
   ```
   {% set pre_power_command = 'ssh pi@192.168.100.10 relay-module.py -c CH2 -s on' %}
   {% set pre_os_command = 'ssh pi@192.168.100.10 relay-module.py -c CH2 -s off' %}
   {% set hard_reset_command = 'ssh pi@192.168.100.10 relay-module.py -c CH3 -s reboot' %}
   {% set power_on_command = 'ssh pi@192.168.100.10 relay-module.py -c CH3 -s on' %}
   {% set power_off_command = 'ssh pi@192.168.100.10 relay-module.py -c CH3 -s off' %}
   ```

## References:
[RPI Relay Board wiki](https://www.waveshare.com/wiki/RPi_Relay_Board)

[RPi.GPIO Python Module](https://sourceforge.net/p/raspberry-gpio-python/wiki/Home/)
