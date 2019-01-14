# Install standalone LAVA instance

## Install LAVA
1. Install and boot into Debian 9.

2. Enable stretch-backports repo.

    ```bash
    echo "deb http://ftp.debian.org/debian stretch-backports main" > /etc/apt/sources.list.d/backports.list
    apt update
    ```
    
3. Add lavasoftware repo to install the latest release.

    ```bash
    apt install -y apt-transport-https
    wget https://apt.lavasoftware.org/lavasoftware.key.asc
    apt-key add lavasoftware.key.asc
    echo "deb https://apt.lavasoftware.org/release stretch-backports main" > /etc/apt/sources.list.d/lavasoftware.list
    apt update 
    ``` 
    
4. Check available versions and source priorities for package `lava-server`.

    ```bash
    root@stretch-lava:~# apt-cache policy lava
    lava:
      Installed: (none)
      Candidate: 2018.11+stretch
      Version table:
         2018.11+stretch 500
            500 https://apt.lavasoftware.org/release stretch-backports/main amd64 Packages
         2018.11-1~bpo9+1 100
            100 http://ftp.debian.org/debian stretch-backports/main amd64 Packages
         2016.12-3 500
            500 http://security.debian.org/debian-security stretch/updates/main amd64 Packages
            500 http://deb.debian.org/debian stretch/main amd64 Packages
    ```
    
5. Install `lava-server` from `stretch-backports`. `lava-dispatcher`,
   `lava-coordinator` and `lavacli` also will be installed as `lava-server`
   depends on them.
   
    ```bash
    apt install -y postgresql
    apt install -y -t stretch-backports lava-server
    ```   
    
6. Add local super user.

    ```bash
    root@stretch-lava:~# lava-server manage createsuperuser
    Username (leave blank to use 'root'): admin
    Email address: john.doe@example.com
    Password: 
    Password (again): 
    Superuser created successfully.
    ```
    
7. Access frontend UI and admin interface.

    Enable `lava-server.conf` with apache2.
    
    ```bash
    a2dissite 000-default
    a2enmod proxy
    a2enmod proxy_http
    a2ensite lava-server.conf
    systemctl reload apache2
    ```
    
   As django enforces CSRF cookies, disable these security features to allow
   user login with http://localhost/
    
    ```bash
    cp /etc/lava-server/settings.conf{,.original}
    sed -i '/{/a\    "CSRF_COOKIE_SECURE": false,\n    "SESSION_COOKIE_SECURE": false,' /etc/lava-server/settings.conf
    ```
    
    Restart `lava-server-gunicorn` service to put the changes into effects.
    
    ```bash
    systemctl restart lava-server-gunicorn
    ```
    
    Open link http://localhost/, you should be able to sign in with the super
    user created in the previous step.
    
    **WARNING**: http isn't secure enough, use it for local network only.
    Before putting the service online, you should re-enable the above security
    features and secure apache2 with https. You can fine an example with Let's
    Encrypt in `./deploy-distributed-lava-instance.md`
    
8. Optional, enable `event notifications`. The feature is required by Linaro's
   Software Quality Dashboard [squad](https://github.com/Linaro/squad). Refer
   to LAVA's doc for the detailed steps:
   [Configuring event notifications](https://master.lavasoftware.org/static/docs/v2/advanced-installation.html?#configuring-event-notifications)
   
9. Check if the local LAVA worker added successfully.

   Open http://localhost/scheduler/allworkers, you should see a worker added
   with the same hostname, in my case, it is `stretch-lava`. If its sate is
   online, congrats, you are good to add devices. Otherwise, check the
   following logs for debugging.
   
    ```bash
    /var/log/lava-server/lava-master.log
    /var/log/lava-dispatcher/lava-slave.log

    ```
   
## Add devices under test
### Add known supported device: qemu
1. Add new device type: qemu
   
   Open https://localhost/admin/lava_scheduler_app/devicetype/, click
   `ADD DEVICE TYPE` button, enter `qemu` for `device type` name, leave the
   rest elements empty and then click `SAVE` button.

2. Add new qemu device: qemu-01

   Open https://localhost/admin/lava_scheduler_app/device/, click `ADD DEVICE`
   button to add qemu-01 with the following settings.

    ```
    Hostname: qemu-01
    Device type: qemu
    Worker Host: stretch-lava
    Device Version: v1.0
    User: admin
    User with physical access: admin
    Select 'Is public'
    Select 'Pipeline device'
    Health: Unknown
    ```

3. Add device `CONFIG` file (aka device dictionary).
    
    If not done yet, clone `lkft-remove-lab` repo and enter `LAVA/configs`
    sub-dir.
    
    ```bash
    git clone https://github.com/Linaro/lkft-remote-lab
    cd lkft-remote-lab/LAVA/configs
    ``` 

    And then,

    ```bash
    cp ./devices/qemu-01.jinja2 /etc/lava-server/dispatcher-config/devices/
    ```
        
4. Add health check.

    ```bash
    cp ./health-checks/qemu.yaml /etc/lava-server/dispatcher-config/health-checks/
    ```

### Add known supported device: lxc
1. Similarly, add new device type `lxc` and device `lxc-01`.

2. Config bridged network for LXC.

   Enable `USE_LXC_BRIDGE`.
   
    ```bash
    echo 'USE_LXC_BRIDGE="true"' > /etc/default/lxc-net
    ```

   Create a template for new containers.
    ```bash
    cp /etc/lxc/default.conf{,.original}
 
    cat << EOF > /etc/lxc/default.conf
    lxc.network.type = veth
    lxc.network.link = lxcbr0
    lxc.network.flags = up
    lxc.network.hwaddr = 00:16:3e:xx:xx:xx   
    EOF
    ```
     
   Restart lxc-net service.
   
     ```
     systemctl restart lxc-net
     ```

3. Add device `CONFIG` file.

    ```bash
    cp ./devices/lxc-01.jinja2 /etc/lava-server/dispatcher-config/devices/
    ```

4. Add health check.
    ```bash
    cp ./health-checks/lxc.yaml /etc/lava-server/dispatcher-config/health-checks/
    ```

After health test job added, LAVA will submit health test job to test the newly
added devices. Once health test job passed, device sate will be marked as
`Good` which means it is good to accept and run normal test jobs. If health test
job failed, LAVA will put the device `offline` and mark its state as `bad`. In
the `bad` case, check health test job log for debugging.

Note: root permissions are required to execute most of the above commands.
