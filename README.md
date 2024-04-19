# raspberry pi provisioning utility

In order to better manage mutliple PI instances  

## intial imaging
- [sdm](https://github.com/gitbls/sdm)
    - [issue with copying auth keys](https://github.com/gitbls/sdm/issues/196)
- [image.sh](src/sdm/image.sh)
    - builds image with initial ansible user
    - assumes bookworm.img in img folder
- [burn.sh](src/sdm/burn.sh)
    - burns image to sd card at /dev/sdc

## provisioning image
- [ansible](https://docs.ansible.com/)
    - [install latest on PI](https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html#installing-ansible-on-debian)
