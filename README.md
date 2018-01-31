# LKFT remote lab

The LKFT framework is a collection of software tools and hardware devices.  LKFT is composed of a builds scheduler (Jenkins), a device management framework (LAVA), an LKFT LAVA hardware micro-instance, and a scheduling framework and reporting framework (SQUAD).

This project documents the steps required to deploy a such LKFT test lab. It is named as `lkft-remote-lab` as it is able to share the following components that Linaro maintaining.
- Jenkins: https://ci.linaro.org/
- LKFT lava-master: https://lkft.validation.linaro.org/
- Scheduling and reporting framework: https://qa-reports.linaro.org/

A `lkft-remote-lab` could be either of the following types:
- Partially Hosted: only hosts a local lava-slave
- Fully Hosted: hosts lava-slave plus lava-master with a public domain
- Ultra secure: hosts everything except squad

The documents and configs included in the project is trying to cover all the aspects required to deploy a LKFT remote lab with step by step guidelines.

## Ultra secure
1. [deploy-distributed-lava-instance](./LAVA/deploy-distributed-lava-instance.md)
2. [deploy-docker-based-jenkins](./Jenkins/deploy-docker-based-jenkins.md)
3. [setup-report-system](./Squad/setup-report-system.md)

## Fully hosted
1. [deploy-distributed-lava-instance](./LAVA/deploy-distributed-lava-instance.md)
2. [setup-report-system](./Squad/setup-report-system.md)

## Partially hosted
1. Refer to [deploy-distributed-lava-instance](./LAVA/deploy-distributed-lava-instance.md) to install lava-slave.
2. [setup-report-system](./Squad/setup-report-system.md)

Once local lava-slave installed and test devices connected, talk to administrator of [Linaro's LKFT lava-master](https://lkft.validation.linaro.org/) to:
1. Establish openvpn connection to the lab
2. Add your local lava-slave as a worker
3. Add your test devices

## CI flow
Once LKFT remote lab set properly, a new commit will trigger a new build from Jekkins, the build job will submit test jobs via `squad` to `lava-master`, and test results will be pull back and presented instantly. Once all test jobs finished, `squad` will send a report with the comparison with last build.

Refer to the below diagram for `ultra secure` mode for the flow
![LKFT remote lab diagram](https://i.imgur.com/j5KYit5.png)

## How a micro local LAVA worker looks like
![LAVA woker](https://i.imgur.com/xTwC7LZ.jpg)

Components used:
- Thinkpad T440 running Debian9.3 as lava-slave
- Raspberry Pi3 plus relay module for power/OTG on/off/reboot control. Refer to [power-control.md](./LAVA/power-control.md)
- [ORICO USB3.0 Hub with Gigabit Ethernet Converter](http://ca.orico.cc/goods.php?id=4780) for:
  - Connection to HiKey's serial and OTG USB ports
  - Connection to Raspberry Pi3's Ethernet port to control reply module over ssh
- Test device: [HiKey](https://www.96boards.org/product/hikey/)
