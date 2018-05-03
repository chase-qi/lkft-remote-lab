A LAVA instance consists of two primary components - a master and a worker. A distributed LAVA instance installs these two components on separate machines. lava-master and lava-slave(worker) use ZMQ to pass control messages and log messages.

This document tries to give you a step by step guide to deploy a distributed LAVA instance.

## Common
1. Install Debian9 on LAVA master and slave.
2. If not enabled already, follow the instructions [here](https://backports.debian.org/Instructions/) to enable the Stretch backports repo.
3. Use Linaro [production-repo](https://images.validation.linaro.org/production-repo/) for latest production release.
   ```
   apt install -y apt-transport-https
   wget https://images.validation.linaro.org/staging-repo/staging-repo.key.asc
   apt-key add staging-repo.key.asc
   echo "deb https://images.validation.linaro.org/production-repo stretch-backports main" > /etc/apt/sources.list.d/lava-production-repo.list
   apt update
   ```

## LAVA Master
In this guide, the following key:values will be used for lava-master, you will need to adjust them to reflect your environment.
* hostname: lava-master
* External IP: 104.199.171.203
* Domain: chase.lkft.org

1. Install lava-server

   ```
   apt install -y postgresql
   apt install -y -t stretch-backports lava-server
   a2dissite 000-default
   a2enmod proxy
   a2enmod proxy_http
   a2ensite lava-server.conf
   systemctl reload apache2
   ```
2. Create a local superuser.
   ```
   lava-server manage createsuperuser
   ```
   Enter the following strings when prompted:
   * username: admin
   * email address: first.last@linaro.org
   * password: ********

3. Access frontend UI and admin interface.

   As django now enforces CSRF cookies, you need to do either of the following options to login through webUI.

    Note: As LAVA job submission API requires verified SSL certificate, self-singed SSL Cert wouldn't work, not in LKFT test framework.

   * Secure Apache with Let's Encrypt.

     Prerequisites
     * You must own or control the registered domain name.
     * Create an a record that points your domain to the public IP address of your server.

     Steps:
     * Set up lava-server site as default site
       ```
       a2dissite lava-server.conf
       mv 000-default.conf 000-default.conf.bak
       mv default-ssl.conf default-ssl.conf.bak
       cp lava-server.conf 000-default.conf
       a2ensite 000-default.conf
       systemctl reload apache2
       ```
     * Set up the Apache ServerName and ServerAlias
       ```
       vim /etc/apache2/sites-available/000-default.conf
       ```
       Add the following two lines:
       ```   
       <VirtualHost *:80>
           . . .
           ServerName chase.lkft.org
           ServerAlias chase.lkft.org
           . . .
       </VirtualHost>
       ```
       Restart Apache service to put the changes into effect:
       ```
       systemctl restart apache2
       ```
     * Set up the SSL Certificate
       ```
       certbot --apache
       ```
       Follow the instructions to active https for `chase.lkft.org` and redirect all requests to secure HTTPS access.

   * Use non HTTPS URL

     * Add the following two options to /etc/lava-server/settings.conf
       ```
       "CSRF_COOKIE_SECURE": false,
       "SESSION_COOKIE_SECURE": false
       ```
     * Reboot lava-master to put these changes into effect.

4. Configure event notifications
   When event notifications enabled in `lava-server`, `squad` will know when a test job finished, then it will start to fetch test results from that job.

   To enabled event notifications, open `/etc/lava-server/settings.conf` and add the following lines:
   ```
   "EVENT_TOPIC": "org.lkft.chase",
   "INTERNAL_EVENT_SOCKET": "ipc:///tmp/lava.events",
   "EVENT_SOCKET": "tcp://*:5500",
   "EVENT_NOTIFICATION": true,
   "EVENT_ADDITIONAL_SOCKETS": []
   ```
   Notes:
   * Ensure that the EVENT_TOPIC is changed to a string which the receivers of the events can use for filtering. Simply reversing the domain name for your LAVA instance should work.
   * Ensure that the EVENT_SOCKET is visible to the receivers. You may need to add a firewall rule to allow external access to the port.

   Restart the corresponding services:
   ```
   systemctl restart lava-publisher
   systemctl restart lava-master
   systemctl restart lava-logs
   systemctl restart lava-server-gunicorn
   ```

5. Connect to remote lava-slave
   * Enable ZMQ authentication and encryption
     ```
     cd /etc/lava-dispatcher/certificates.d
     /usr/share/lava-dispatcher/create_certificate.py master
     ```
     After the below lava-slave set, copy `slave-t440.key` from there to this directory.

   * Edit `/etc/lava-server/lava-master` to uncomment the following lines.
     ```
     MASTER_SOCKET="--master-socket tcp://*:5556"
     ENCRYPT="--encrypt"
     ```
   * Edit `/etc/lava-server/lava-logs` to uncomment the following lines
     ```
     SOCKET="--socket tcp://*:5555"
     MASTER_SOCKET="--master-socket tcp://localhost:5556"
     ENCRYPT="--encrypt"
     ```
   * Add the below remote lava-slave `T440`
     ```
     lava-server manage workers add T440
     ```
   * Restart lava-master and lava-logs
     ```
     systemctl restart lava-master
     systemctl restart lava-logs
     ```
6. Optionally, add local lava-slave
   * Generate certificates
     ```
     cd /etc/lava-dispatcher/certificates.d
     /usr/share/lava-dispatcher/create_certificate.py slave-localhost
     ```
   * Add the following lines to `/etc/lava-dispatcher/lava-slave`
     ```
     HOSTNAME="--hostname lava-frontend"
     ENCRYPT="--encrypt"
     MASTER_CERT="--master-cert /etc/lava-dispatcher/certificates.d/master.key"
     SLAVE_CERT="--slave-cert /etc/lava-dispatcher/certificates.d/slave-localhost.key_secret"
     ```
   * Add `localhost` as a worker
     ```
     lava-server manage workers add localhost
     ```
   * Restart the local lava-slave
     ```
     systemctl restart lava-slave
     ```

## LAVA slave
1. Install lava-dispatcher
   ```
   apt install -t stretch-backports lava-dispatcher
   ```
2. Configuring apache2

   Some test job deployments will require a working Apache2 server to offer deployment files over the network to device.

   ```
   apt install apache2
   cp /usr/share/lava-dispatcher/apache2/lava-dispatcher.conf /etc/apache2/sites-available/
   a2dissite 000-default
   a2ensite lava-dispatcher
   systemctl restart apache2
   wget http://localhost/tmp/
   rm index.html
   ```
3. Connect to remote lava-master
   * Use ZMQ authentication and encryption
     ```
     cd /etc/lava-dispatcher/certificates.d
     /usr/share/lava-dispatcher/create_certificate.py slave-t440
     ```
     Copy `master.key` from the above lava-master to this directory.
     Copy `slave-t440.key` to lava-master `/etc/lava-dispatcher/certificates.d`
   * Open `/etc/lava-dispatcher/lava-slave`, edit or uncomment the following lines.
     ```
     MASTER_URL="tcp://104.199.171.203:5556"
     LOGGER_URL="tcp://104.199.171.203:5555"
     HOSTNAME="--hostname t440"
     ENCRYPT="--encrypt"
     SLAVE_CERT="--slave-cert /etc/lava-dispatcher/certificates.d/slave-t440.key_secret"
     ```
   * Restart lava-slave
     ```
     systemctl restart lava-slave
     ```

## Add known supported device: qemu
1. Add qemu device in the database.
   * Open https://chase.lkft.org/admin/lava_scheduler_app/devicetype/, click on `ADD DEVICE TYPE` button, enter 'qemu' for device type name, leave the rest elements empty and click on `SAVE` button to add device type qemu.
   * Open https://chase.lkft.org/admin/lava_scheduler_app/device/, click `ADD DEVICE` button, fill in the following elements:
     * Device type: qemu
     * Hostname: qemu-01
     * Worker Host: T440
     * Device Version: v1.0
     * User: admin
     * User with physical access: admin
     * Select `Is public`
     * Select `Pipeline device`
     * Choose `good` for `Health` status

2. On lava-master:
   * Add device dictionary
     ```
     cp ./devices/qemu-01.jinja2 /etc/lava-server/dispatcher-config/devices/
     ```
     Open https://chase.lkft.org/admin/lava_scheduler_app/device/qemu-01/change/, click into `Advanced properties`, `Device dictionary jinja` should be updated with the above lines.
   * Add health check job for the new added device.
     ```
     cp ./health-checks/qemu-01.yaml /etc/lava-server/dispatcher-config/health-checks/
     ```
     The health test job will tell you if the instance deployed correctly.

## Add known supported device: lxc
1. The same as above, create lxc device type and device lxc-01.
2. Set up lxcbr0 bridge network for LXC on lava-slave.
   * Create /etc/default/lxc-net with the following line[deploy-distributed-lava-instance](./LAVA/deploy-distributed-lava-instance.md):
     ```
     USE_LXC_BRIDGE="true"
     ```

   * Edit /etc/lxc/default.conf and change the default
     ```
     lxc.network.type = empty
     ```
     to this:
     ```
     lxc.network.type = veth
     lxc.network.link = lxcbr0
     lxc.network.flags = up
     lxc.network.hwaddr = 00:16:3e:xx:xx:xx
     ```
     This will create a template for newly created containers.
   * Restart lxc-net service.
     ```
     systemctl restart lxc-net
     ```
5. Add device dictionary.
   ```
   cp ./devices/lxc-01.jinja2 /etc/lava-server/dispatcher-config/devices/
   ```
6. Add health check job.
```
cp ./health-checks/lxc.yaml /etc/lava-server/dispatcher-config/health-checks/
```
## Add known supported device: hikey
1. Set up serial console.
   * Connect hikey serial port to lava-slave.
   * Edit `/etc/ser2net.conf` to add:
     ```
     7001:telnet:0:/dev/ttyUSB0:115200 8DATABITS NONE 1STOPBIT
     ```
   Adjust serial port `ttyUSB0` when needed.
   * Restart ser2net
     ```
     systemctl restart ser2net
     ```
2. Set up power/OTG on/off/reboot controller.
   Refer to [LAVA woker](https://i.imgur.com/xTwC7LZ.jpg) and [power-control](./power-control.md) to:
   * Connect OTG port via RPi_Relay_Board to lava-slave.
   * Connect power cable via RPi_Relay_Board to lava-slave.
   * Update power/otg control commands defined in `./devices/hi6220-hikey-01.jinja2`
4. Add hi6220-hikey device type and hi6220-hikey-01 device in django admin console.
5. Add device dictionary.
   ```
   cp ./devices/hi6220-hikey-01.jinja2 /etc/lava-server/dispatcher-config/devices/
   ```
6. Add health check job.
   ```
   cp ./health-checks/hi6220-hikey.yaml /etc/lava-server/dispatcher-config/health-checks/
   ```
7. Install prerequisites on lava-slave T440.
   ```
   apt install -y simg2img img2simg
   ```

## References
[First steps installing LAVA](https://validation.linaro.org/static/docs/v2/first-installation.html)

[Installing LAVA on a Debian system](https://validation.linaro.org/static/docs/v2/installing_on_debian.html)

[Setting up a LAVA instance](https://validation.linaro.org/static/docs/v2/pipeline-server.html#setting-up-a-lava-instance)

[Adding your first devices](https://validation.linaro.org/static/docs/v2/first-devices.html#adding-your-first-devices)

[Debugging a LAVA instance](https://validation.linaro.org/static/docs/v2/pipeline-debug.html)

[How To Secure Apache with Let's Encrypt on Debian 8](https://www.digitalocean.com/community/tutorials/how-to-secure-apache-with-let-s-encrypt-on-debian-8)

[certbot - Apache on Debian 9 (stretch)](https://certbot.eff.org/#debianstretch-apache)

[Configs using in Cambridge lava-lab](https://git.linaro.org/lava/lava-lab.git)
