#!/bin/bash

# VARIABLES
HOST=server

# SETUP KEYBOARD
loadkeys uk

# FILE SYSTEM
fdisk /dev/sda << EOF
n




w
EOF
mkfs.ext4 /dev/sda1
mount /dev/sda1 /mnt

# INSTALL ARCH BASE
pacstrap /mnt base
genfstab -p /mnt >> /mnt/etc/fstab

# NETWORK (INC SSHD)
arch-chroot /mnt /bin/bash -c "
echo $HOST > /etc/hostname
echo 127.0.0.1 localhost.localdomain localhost $HOST > /etc/hosts
echo ::1       localhost.localdomain localhost >> /etc/hosts
systemctl enable dhcpcd@enp0s3.service
pacman -S --noconfirm openssh
"

# TIME, LOCALE, KEYBOARD
arch-chroot /mnt /bin/bash -c "
ln -s /usr/share/zoneinfo/GB /etc/localtime
echo en_GB.UTF-8 UTF-8 >> /etc/locale.gen
locale-gen
echo KEYMAP=\"uk\" >> /etc/vconsole.conf
hwclock --systohc --utc
"

# BOOTLOADER
arch-chroot /mnt /bin/bash -c "
pacman -S --noconfirm grub
grub-install --target=i386-pc --recheck /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
"

# ROOT PASSWORD
arch-chroot /mnt /bin/bash -c "passwd"

# FINALISE
umount -R /mnt
reboot
