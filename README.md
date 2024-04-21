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
- [burn.sh](src/sdm/burn.sh)
    - burns image to sd card at /dev/sdc

## provisioning image
the first instance to setup is the provisioning system.  
this a pi with ths project and ansible installed.  
- [ansible](https://docs.ansible.com/)
    - [install latest on PI](https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html#installing-ansible-on-debian)

## utility scripts
I went with gradle as i'm familiur with it and it's used in my day job.  
I used [sdkman](https://sdkman.io/) to setup java and gradle
