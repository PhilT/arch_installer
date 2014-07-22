#!/bin/bash

# VARIABLES
HOST=server
PACMAN='pacman -S --noconfirm'
AUR='pacman -U --noconfirm'
USER=phil
CHROOT='arch-chroot /mnt /bin/bash -c'

# SETUP KEYBOARD
loadkeys uk

# FILE SYSTEM
# (Single partition, no swap)
# (Line breaks are significant)
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
$CHROOT "
echo $HOST > /etc/hostname
echo 127.0.0.1 localhost.localdomain localhost $HOST > /etc/hosts
echo ::1       localhost.localdomain localhost >> /etc/hosts
systemctl enable dhcpcd@enp0s3.service
$PACMAN openssh
"

# TIME, LOCALE, KEYBOARD
$CHROOT "
ln -s /usr/share/zoneinfo/GB /etc/localtime
echo en_GB.UTF-8 UTF-8 >> /etc/locale.gen
locale-gen
echo KEYMAP=\"uk\" >> /etc/vconsole.conf
hwclock --systohc --utc
"

# BOOTLOADER
$CHROOT "
$PACMAN grub
grub-install --target=i386-pc --recheck /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
"

# USER
$CHROOT "useradd -m -G wheel -s /bin/bash $USER"

# PACKAGES
$CHROOT "$PACMAN xorg-server xorg-server-utils xorg-xinit elementary-icon-theme xcursor-vanilla-dmz gnome-themes-standard ttf-ubuntu-font-family feh lxappearance rxvt-unicode pcmanfm suckless-tools xautolock git"

# AUR
# rbenv ruby-build ttf-ms-fonts

# DWM
$CHROOT "git clone git@github.com:PhilT/dwm.git && cd dwm && make clean install"


# CUSTOMIZATION
$CHROOT "sed -i s/#Color/Color/ /etc/pacman.conf
echo '$USER ALL=NOPASSWD:/sbin/shutdown' >> /etc/sudoers.d/shutdown
echo '$USER ALL=NOPASSWD:/sbin/reboot' >> /etc/sudoers.d/shutdown
chmod 440 /etc/sudoers.d/shutdown"


# ROOT PASSWORD
$CHROOT "passwd"

# FINALISE
umount -R /mnt
reboot
