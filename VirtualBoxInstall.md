## Installing VirtualBox on ArchLinux for testing

Download the VirtualBox extension pack at https://www.virtualbox.org/wiki/Downloads then:

    sudo pacman virtualbox virtualbox-guest-iso net-tools virtualbox-host-dkms linux-headers linux-lts-headers
    sudo modprobe vboxdrv
    sudo VBoxManage extpack install ~/Downloads/Oracle_VM_VirtualBox_Extension_Pack-5.0.4-102546.vbox-extpack
    VBoxManage createvm --name ArchLinux --ostype ArchLinux --register
    VBoxManage modifyvm ArchLinux --memory 4096 --acpi on --boot1 dvd
    VBoxManage modifyvm ArchLinux --nic1 bridged --bridgeadapter1 eth0
    VBoxManage createhd --filename ./ArchLinux.vdi --size 10000
    VBoxManage storageattach

