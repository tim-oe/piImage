# raspberry pi provisioning utility

In order to better manage mutliple PI instances my plan is to to use a 2 phased approach.
1. sdm to initialize the image.
2. ansible to setup system specific configurations and software 

## intial imaging
- [sdm](https://github.com/gitbls/sdm)
    - [issue with copying auth keys](https://github.com/gitbls/sdm/issues/196)
- [image.sh](src/sdm/image.sh)
    - builds image with initial ansible user
    - assumes bookworm.img in img folder

## provisioning image
the first instance to setup is the provisioning system.  
this a pi with ths project and ansible installed.  
- [ansible](https://docs.ansible.com/)
    - [install latest on PI](https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html#installing-ansible-on-debian)

## utility scripts
I went with gradle as i'm familiur with it and it's used in my day job.  
I used [sdkman](https://sdkman.io/) to setup java and gradle

## hardware stuff
- pi5 with m2 drive


## telegraf-grafana-influx
- [github](https://github.com/influxdata/telegraf/blob/master/docs/CONFIGURATION.md)
- [monitor pi temp](https://github.com/TheMickeyMike/raspberrypi-temperature-telegraf)
- [influx template](https://github.com/influxdata/community-templates/tree/master/raspberry-pi)
    - [influx cli](https://docs.influxdata.com/influxdb/cloud/reference/cli/influx/?t=Linux#provide-required-authentication-credentials)
    - ```influx config create --config-name tec --host-url $INFLUX_HOST --org $INFLUX_ORG --token $INFLUX_TOKEN --active```
    - ```influx apply -f https://raw.githubusercontent.com/influxdata/community-templates/master/raspberry-pi/raspberry-pi-system.yml```
- [grafana template](https://grafana.com/grafana/dashboards/10578-raspberry-pi-monitoring/)
- [grafana datasource](https://www.influxdata.com/blog/getting-started-influxdb-grafana/)

- setup
    - [sample conf](https://gist.github.com/atanasyanew/5c5db975a7179fc271daea43b6592b5b)
    - [example 1](https://community.influxdata.com/t/use-telegraf-to-get-metrics-from-raspberry-pi/26686)
    - [example 2](https://randomnerdtutorials.com/monitor-raspberry-pi-influxdb-telegraf/)
    - [grafana pwd](https://signoz.io/guides/what-is-the-default-username-and-password-for-grafana-login-page/)

## ansible
- [tips n trix](https://docs.ansible.com/ansible/latest/tips_tricks/index.html)
- [dir hierarchy](https://docs.ansible.com/ansible/latest/tips_tricks/sample_setup.html)
- [vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html)
    - [inline encryption](https://docs.ansible.com/ansible/latest/vault_guide/vault_encrypting_content.html)
    - [howto 1](https://www.digitalocean.com/community/tutorials/how-to-use-vault-to-protect-sensitive-ansible-data)

## TODOs
- [git bash prompt](https://git-scm.com/book/pl/v2/Appendix-A:-Git-in-Other-Environments-Git-in-Bash)
    - [example 1](https://code.mendhak.com/simple-bash-prompt-for-developers-ps1-git/)
    - [example 2](https://www.baeldung.com/linux/bash-prompt-git)
- gdrive backup
    - [possible solution](https://github.com/dtsvetkov1/Google-Drive-sync)
- pi montoring grafana influx telegraf
    - [telegraf setup](https://randomnerdtutorials.com/monitor-raspberry-pi-influxdb-telegraf/)
    - [blog](https://www.kevsrobots.com/blog/telegraf-on-pi.html)
    - [video](https://www.youtube.com/watch?v=CrWh34bQK7M)
