In LKFT test framework, Jenkins monitors changes from specified kernel tree, builds images and triggers test jobs. This guide will talk about how to deploy Jenkins instance with the master and slave images that developed by Linaro Building and Baseline team.

## Common
[Install Docker](https://docs.docker.com/install/)

## Run Jenkins master
1. Create `VOLUME` directory on host. Use `/media/data/docker/jenkins` here.
   ```
   mkdir /media/data/docker/jenkins
   chown -R 1000:1000 /media/data/docker/jenkins
   ```
2. Run Jenkins master.
   ```
   docker run \
       --log-driver=journald \
       --privileged \
       --name jenkins-master \
       --volume /media/data/docker/jenkins/:/var/jenkins_home:rw \
       --publish 0.0.0.0:2222:2222 \
       --publish 0.0.0.0:2233:2233 \
       --publish 0.0.0.0:50000:50000 \
       --publish 0.0.0.0:8080:8080 \
       linaro/ci-x86_64-jenkins-master-debian:lts
   ```
3. When you see the following output
   ```
   *************************************************************

   Jenkins initial setup is required. An admin user has been created and a password generated.
   Please use the following password to proceed to installation:

   8874397957c841c98ea9fd8dcf4fe1dd

   This may also be found at: /var/jenkins_home/secrets/initialAdminPassword

   *************************************************************
   ```
   - open `http://localhost:8080`, enter the above password and click on the `CONTINUE` button.
   - On the following `Customize Jenkins` page, click `Install suggested plugins`
   - On the following `Create First Admin User` page, create a new user. e.g. admin
   - Login to the Jenkins master with the new user.

## Add Jenkins docker slave
1. Pull linaro Jenkins slave docker image. Take Debian Stretch for example:
   ```
   docker pull linaro/ci-amd64-debian:stretch
   ```
2. Enable remote Docker Remote API.
   - Debian
     - Open `/lib/systemd/system/docker.service`, modify the following line that starts with ExecStart to look like:
       ```
       ExecStart=/usr/bin/docker daemon -H fd:// -H tcp://0.0.0.0:2375
       ```
     - Make sure the Docker service notices the modified configuration:
       ```
       systemctl daemon-reload
       systemctl restart docker
       ```
     - Test that the Docker API is accessible:
       ```
       curl http://localhost:2375/version
       ```
     - As docker service restart will kill running jenkins-master container, to start it again run:
       ```
       docker start jenkins-master
       ```
   - CentOS
     Edit `/etc/systemd/system/multi-user.target.wants/docker.service` instead. The rest steps are the same.

   Note: Once the remote API enabled, you may want to edit your firewall rule to limit the access to it.
3. Make sure [Yet Another Docker Plugin](https://wiki.jenkins.io/display/JENKINS/Yet+Another+Docker+Plugin) installed.
4. Generate the SSH key pairs for slave lunch method using SSH.
   ```
   mkdir -p /srv/docker/ssh/
   ssh-keygen -t rsa -f id_rsa_buildslave -N ''
   ```
5. Go to `Jenkins -> Credentials -> System -> Global credentials (unrestricted)`, click `Add Credentials` to add the above SSH private key with username `buildslave`.
6. Go to `Manage Jenkins` -> `Configure System`, scroll down to `YADocker Settings` section, set `Docker Cloud Provisioning Strategy Order` to `least loaded with fallback to random`. Click on `Save` button located on the bottom to save the change.
7. Go to `Manage Jenkins` -> `Configure System`, scroll down to `Cloud` section, click `Add a new cloud` drop-down menu, and choose `Yet Another Docker`.
   - Then follow the following steps to fill the elements.
     - Cloud Name: YetAnotherDocker
     - Docker URL: `tcp://<host-IP>:2375`

     Leave the rest as it is, a click on `Test Connection` button should pass and show the version info of remote docker API.

   - Click `Add Docker Template` drop-down menu, and choose `Docker Template`, then  fill in the elements as the following:
     - Docker Image Name: linaro/ci-amd64-debian:stretch

   - Click `Create Container Settings` button, fill in `Volumes` with the following lines to pass public key to docker slave.
     ```
     /srv/docker/ssh/buildslave.known_hosts:/home/buildslave/.ssh/known_hosts:rw
     /srv/docker/ssh/id_rsa_buildslave.pub:/home/buildslave/.ssh/authorized_keys:ro
     ```
   - In `Jenkins Slave Config` section, fill in the elements with the following values:
     ```
     Remote Filing System Root: /home/buildslave
     Labels: docker-stretch-amd64
     Launch method: Docker SSH computer launcher
     Credentials: buildslave
     Host Key Verification Strategy: Non verifying Verification Strategy
     ```
   - Click on `Save` button located on the bottom to save the changes.

## Setup `publish over ssh`
Refer to [Publish Over SSH Plugin](https://wiki.jenkins.io/display/JENKINS/Publish+Over+SSH+Plugin)

## Add LKFT projects using JJB
1. Install Jenkins Job Builder.
   ```
   pip install --user jenkins-job-builder
   ```
2. Modify `configs/jenkins_jobs.ini` to use your own username, password and url.
3. Modify `./configs/openembedded-lkft-linux-mainline.yaml` to use your own SSH file server, LAVA server and Squad project, then add the build job and related trigger.
   ```
   cd configs
   jenkins-jobs --conf jenkins_jobs.ini update openembedded-lkft-linux-mainline.yaml
   jenkins-jobs --conf jenkins_jobs.ini update trigger-openembedded-lkft-linux-mainline.yaml
   ```
4. Generate a token for job submission in `squad`. Go to `Jenkins -> Credentials -> System -> Global credentials (unrestricted)`, click `Add Credentials` to add a new secret text type credential with `QA_REPORTS_TOKEN` as description.

## Reference
[Jenkins job configs on `ci.linaro.org`](https://git.linaro.org/ci/job/configs.git)
