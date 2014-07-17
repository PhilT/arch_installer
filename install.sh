#!/bin/bash

if [ -z $1 ]; then
  echo 'Arch Linux SSH Installation'
  echo 'Download ISO from https://www.archlinux.org/download/'
  echo '  I used UK2: http://archlinux.mirrors.uk2.net/iso/2014.07.03/'
  echo '####'
  echo 'Boot CD and run the following:'
  echo '    systemctl start sshd'
  echo '    passwd'
  echo '    ip a'
  echo '####'
  echo 'Then run this script with the IP address from `ip a`'
  echo '    install.sh <ip address>'
  exit
fi

ssh -t root@$1 "
loadkeys uk
fdisk /dev/sda << EOF
n




w
EOF
mkfs.ext4 /dev/sda1
mount /dev/sda1 /mnt
systemctl enable dhcpcd@enp0s3.service
pacstrap /mnt base
genfstab -p /mnt >> /mnt/etc/fstab
arch-chroot /mnt /bin/bash -c \"
echo server > /etc/hostname
echo 127.0.0.1 localhost.localdomain localhost server > /etc/hosts
echo ::1       localhost.localdomain localhost >> /etc/hosts
ln -s /usr/share/zoneinfo/GB /etc/localtime
echo en_GB.UTF-8 UTF-8 >> /etc/locale.gen
locale-gen
echo KEYMAP=\"uk\" >> /etc/vconsole.conf
hwclock --systohc --utc
pacman -S --noconfirm grub
grub-install --target=i386-pc --recheck /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
passwd
\"
umount -R /mnt
reboot
"
