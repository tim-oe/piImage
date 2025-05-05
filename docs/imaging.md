# disk imaging stuff

had o hack around with this to get it to min size as with m.2 conv=sparse did not work.

- image main OS disk tec-desktop (round 1)
    - use gparted to minize main partions down close to used space
    - record used space partition size
    - read boot partition ```sudo dd if=/dev/sda1 of=./sda1.img```
    - read main partition ```sudo dd if=/dev/sda2 of=./sda2.img```
    - use gparted for the following
    - create 1G boot fat32 boot partion
    - set boot, esp flags
    - create ext4 main (used space/reduced partition size) partion
    - write boot image ```sudo dd if=./sda1.img of=/dev/sda1```
    - write main image ```sudo dd if=./sda2.img of=/dev/sda2```
    - verify and cleanup partitions with gparted