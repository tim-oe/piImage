# sudo apt install qemu-guest-agent
# install the vm commandline
virt-install \
	--name _VM_NAME_\
	--description '_VM_DESC_' \ 
	--memory 4096 \ 
	--vcpus 1 \ 
	--disk _VM_DISK_,bus=sata \
	--import \
	--os-variant _VM_OS_ \
	--virt-type kvm \
	--autostart \
	--noautoconsole \
	--network network=host-bridge
