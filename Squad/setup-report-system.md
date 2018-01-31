LKFT test framework uses https://qa-reports.linaro.org, powered by [squad](https://github.com/Linaro/squad), to submit test jobs to CI backend, pull and present test results, detect regressions, and send test report to developer's mailbox.

This guide will set up report system to connect the components in LKFT test framework, and to close the CI loop. The following components will be used in the guide for examples:
- lava-master: https://chase.lkft.org
- Linaro's squad instance: https://qa-reports.linaro.org
- Local Jenkins instance: http://192.168.11.205:8080

## Add CI backend - requires admin priviliges
Open `https://qa-reports.linaro.org/admin/ci/backend/`, click `ADD BACKEND` button, and fill in the following elements:
- Name: chase.lkft.org
- Url: https://chase.lkft.org/RPC2
- Username: username
- Token: tokens can be generated on https://chase.lkft.org/api/tokens/
- Implementation type: lava
- Poll interval: 60
- Max fetch attempts: 30

Click `SAVE` button to save the new backend.

## Create a project - requires admin priviliges
Open `https://qa-reports.linaro.org/admin/core/project/`, click `ADD PROJECT` button, and fill in the following elements:
- Group: lkft
- Slug: remote-lab-demo
- Name: remote-lab-demo
- Wait before notification: 600
- Notification timeout: 28800

Click `Add another Environment`, and fill in the following elements:
- Slug: hi6220-hikey
- Name: hi6220-hikey - arm64
- Expected test runs: 20

Click `Add another Subscription`, and fill in your email address.

Save the new project by clicking the `SAVE` button.

## Config Jenkins build job.
Make sure the following params in build job definition look like:
```
parameters:
     - string:
         name: LAVA_SERVER
         default: 'https://chase.lkft.org/RPC2/'
     - string:
         name: QA_SERVER
         default: 'https://qa-reports.linaro.org'
     - string:
         name: QA_SERVER_PROJECT
         default: 'remote-lab-demo'
```
