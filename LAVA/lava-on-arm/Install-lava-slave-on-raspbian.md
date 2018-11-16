1. Add stretch-backports.
   ```
   apt-get install dirmngr
   apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 8B48AD6246925553
   apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7638D0442B90D010
   echo "deb http://ftp.debian.org/debian stretch-backports main" > /etc/apt/sources.list.d/stretch-backports.list
   apt update
   ```

2. Install lava-dispatcher

   Refer to [lava-slave](https://github.com/Linaro/lkft-remote-lab/blob/master/LAVA/deploy-distributed-lava-instance.md#lava-slave)

3. Install simg2img for LAVA woker.
   ```
   apt install android-tools-fsutils
   ```

4. When using [RPi Relay Board](http://www.waveshare.net/shop/rpi-relay-board.htm) for power and OTG ON/OFF control, copy `./tools/relay-module.py` to Raspbian's `/usr/local/bin` and update the device dictionary with the following lines:
    ```
   {% set pre_power_command = 'relay-module.py -c CH2 -s on' %}
   {% set pre_os_command = 'relay-module.py -c CH2 -s off' %}
   {% set hard_reset_command = 'relay-module.py -c CH3 -s reboot' %}
   {% set power_on_command = 'relay-module.py -c CH3 -s on' %}
   {% set power_off_command = 'relay-module.py -c CH3 -s off' %}
   ```

Known issue:

`applay-ovelay` doesn't work.

Workaround:

Use `transfer_overlay` instead. Job definition example:


```
- deploy:
    timeout:
      minutes: 45
    to: fastboot
    # OE deployment
    namespace: hikey
    connection: lxc
    images:
      ptable:
        url: http://images.validation.linaro.org/snapshots.linaro.org/96boards/reference-platform/components/uefi-staging/70/hikey/release/ptable-linux-8g.img
        reboot: hard-reset
      boot:
        url: $boot_url
        reboot: hard-reset
      system:
        url: $system_url
        # apply-overlay: true
    os: oe
    protocols:
      lava-lxc:
      - action: fastboot-deploy
        request: pre-power-command
        timeout:
          minutes: 2
- boot:
    namespace: hikey
    prompts:
      # login as root
      - 'root@hikey:'
    auto_login:
      login_prompt: 'hikey login:'
      username: root
    timeout:
      minutes: 5
    method: grub
    commands: installed
    transfer_overlay:
      download_command: cd /tmp ; wget
      unpack_command: tar -C / -xzf
    protocols:
      lava-lxc:
      - action: grub-sequence-action
        request: pre-os-command
        timeout:
          minutes: 2
```
