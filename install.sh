#!/usr/bin/env bash

#### VERSION ####
echo 'Arch Install Script Version 0.4.17'
echo '=================================='
echo ''

#### ABORT if interupted
control_c() {
  exit 1
}
trap control_c SIGINT

#### VARIABLES ####

[[ $NEWUSER ]] || NEWUSER='phil'
[[ $WORKSPACE ]] || WORKSPACE='~/ws' # keeping it short for window titles
[[ $DRIVE ]] || DRIVE='sda'
[[ $PUBLIC_GIT ]] || PUBLIC_GIT='git@github.com:PhilT'
[[ $DOTFILES_SYNC_CMD ]] || DOTFILES_SYNC_CMD='bin/symlink.sh'

PACMAN='pacman -S --noconfirm --noprogressbar --needed'
LOG='install.log'
MNT_LOG=$LOG

#### USER INPUT ####

if [[ ! $MACHINE ]]; then
  echo 'Enter machine name (hostname)'
  echo 'evm, evx, evs (Desktop, Laptop, Server):'
  read MACHINE
fi

[[ ! $MACHINE ]] && echo 'No machine specified (MACHINE=)' && exit 1

[[ $INSTALL = dryrun ]] && PASSWORD='pass1234'

if [[ ! $PASSWORD ]]; then
  echo 'Choose a user password (Asks once, used for root as well)'
  read -s PASSWORD
fi

echo "MACHINE: $MACHINE"
echo "INSTALL: $INSTALL"
echo "DRIVE: $DRIVE"

echo "Press ENTER to repartition $DRIVE and install Arch Linux"
read

#### OPTIONS #####

if [[ $INSTALL = all || $INSTALL = dryrun ]]; then
  [[ $SERVER ]] || SERVER=false

  [[ $BASE ]] || BASE=true
  [[ $LOCALE ]] || LOCALE=true
  [[ $SWAPFILE ]] || SWAPFILE=true
  [[ $INTEL ]] || INTEL=false # causes kernel panic at the moment
  [[ $BOOTLOADER ]] || BOOTLOADER=true
  [[ $UEFI ]] || UEFI=true
  [[ $NETWORK ]] || NETWORK=true
  [[ $SENSORS ]] || SENSORS=true
  [[ $ADD_USER ]] || ADD_USER=true
  [[ $STANDARD ]] || STANDARD=true
  [[ $AUR_FLAGS ]] || AUR_FLAGS=true
  [[ $PACMAN_CONF ]] || PACMAN_CONF=true
  [[ $NOPASS_BOOT ]] || NOPASS_BOOT=true
  [[ $INFINALITY ]] || INFINALITY=true
  [[ $SSH_KEY ]] || SSH_KEY=true
  [[ $DOTFILES ]] || DOTFILES=true
  [[ $SET_PASSWORD ]] || SET_PASSWORD=true
fi

# Setup some assumptions based on target machine
$(lspci | grep -q VirtualBox) && SENSORS=false INTEL=false
[[ $SERVER = true ]] && UEFI=false INTEL=false


#### FUNCTIONS ####

source <(curl -Ls https://raw.githubusercontent.com/PhilT/arch_installer/master/common)

title () {
  echo -e "\n\n\n\n########## $1 ##########" >> $MNT_LOG
  echo -e $1
}

ch_cmd () {
  run="$1"; shift
  title="$1"; shift
  user="$1"; shift
  cmds=""

  while (( "$#" )); do
    cmds="$cmds$1 >> $LOG 2>&1"$'\n'
    shift
  done

  if [[ $run = true ]]; then
    title "$title"
    echo "$cmds" | sed "s/$PASSWORD/*********/g" >> $MNT_LOG

    if [[ $INSTALL != dryrun ]]; then
      LANG=C chroot /mnt su $user -c "$cmds" >> $MNT_LOG 2>&1
    fi
  fi
}

chroot_cmd () {
  run="$1"; shift
  title="$1"; shift
  ch_cmd "$run" "$title" 'root' "$@"
}

chuser_cmd () {
  run="$1"; shift
  title="$1"; shift
  ch_cmd "$run" "$title" "$NEWUSER" "$@"
}


#### BASE INSTALL ####

if [[ $BASE = true && $INSTALL != dryrun ]]; then
  title 'keyboard'
  loadkeys uk

  title 'filesystem'
  partprobe /dev/$DRIVE
  sgdisk --zap-all /dev/$DRIVE >> $MNT_LOG 2>&1
  sgdisk --new=1:0:512M --typecode=1:ef00 /dev/$DRIVE >> $MNT_LOG 2>&1
  mkfs.fat -F32 /dev/${DRIVE}p1 >> $MNT_LOG 2>&1
  sgdisk --new=2:0:0 /dev/$DRIVE >> $MNT_LOG 2>&1
  sgdisk /dev/$DRIVE --attributes=1:set:2
  mkfs.ext4 -F /dev/${DRIVE}p2 >> $MNT_LOG 2>&1
  mount /dev/${DRIVE}p2 /mnt
  mkdir -p /mnt/boot
  mount /dev/${DRIVE}p1 /mnt/boot
  partprobe /dev/$DRIVE

  title 'log file'
  TMP_LOG=$LOG
  LOG="/home/$NEWUSER/install.log"
  MNT_LOG="/mnt$LOG"
  mkdir -p $(dirname $MNT_LOG)
  mv $TMP_LOG $MNT_LOG

  title 'arch linux base'
  mkdir -p /mnt/etc/pacman.d
  cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist.original
  URL="https://www.archlinux.org/mirrorlist/?country=GB&protocol=http&ip_version=4&use_mirror_status=on"
  curl -s $URL | sed 's/^#Server/Server/' > /etc/pacman.d/mirrorlist
  pacman -Syy >> $MNT_LOG 2>&1 # Refresh package lists
  pacstrap /mnt base >> $MNT_LOG 2>&1

  title 'fstab'
  genfstab -U -p /mnt >> /mnt/etc/fstab
  cat /mnt/etc/fstab >> $MNT_LOG 2>&1
fi


#### MOUNTS FOR CHROOT ####

title 'chroot mounts'
chroot_setup /mnt || echo 'failed to mount filesystems (chroot_setup)' >> $MNT_LOG 2>&1
chroot_add_mount /etc/resolv.conf /mnt/etc/resolv.conf --bind >> $MNT_LOG 2>&1
chroot_cmd 'setup /dev/null' "mknod -m 777 /dev/null c 1 3" true >> $MNT_LOG 2>&1


#### ROOT SETUP ####

chroot_cmd $LOCALE 'time, locale, keyboard' \
  "ln -s /usr/share/zoneinfo/GB /etc/localtime" \
  "sed -i s/#en_GB.UTF-8/en_GB.UTF-8/ /etc/locale.gen" \
  "locale-gen" \
  "echo LANG=\"en_GB.UTF-8\" | tee /etc/locale.conf" \
  "$PACMAN ntp" \
  "systemctl enable ntpd" \
  "ntpd -qg" \
  "hwclock --systohc" \
  "echo KEYMAP=\"uk\" | tee /etc/vconsole.conf"

chroot_cmd $SWAPFILE 'swap file' \
  "fallocate -l 2G /swapfile" \
  "chmod 600 /swapfile" \
  "mkswap /swapfile" \
  "echo /swapfile none swap defaults 0 0 | tee -a /etc/fstab"


BOOTLOADER_PACKAGES='syslinux'

if [[ $UEFI = true ]]; then
  modprobe efivarfs
  PARENT='../'
  BOOTLOADER_PACKAGES="$BOOTLOADER_PACKAGES efibootmgr"
  SYSLINUX_CONFIG='/boot/EFI/syslinux/syslinux.cfg'
  BOOTLOADER_EXTRA="mkdir -p /boot/EFI/syslinux
cp -r /usr/lib/syslinux/efi64/* /boot/EFI/syslinux
efibootmgr -c -l /EFI/syslinux/syslinux.efi -L Syslinux
"
else
  PARENT=''
  BOOTLOADER_EXTRA="mkdir -p /boot/syslinux
cp -r /usr/lib/syslinux/bios/*.c32 /boot/syslinux/
extlinux --install /boot/syslinux
dd bs=440 conv=notrunc count=1 if=/usr/lib/syslinux/bios/gptmbr.bin of=/dev/$DRIVE
"
  SYSLINUX_CONFIG='/boot/syslinux/syslinux.cfg'
fi

if [[ $INTEL = true ]]; then
  BOOTLOADER_PACKAGES="$BOOTLOADER_PACKAGES intel-ucode"
  INTEL_IMG='$PARENT../intel-ucode.img '
else
  INTEL_IMG=''
fi

chroot_cmd $BOOTLOADER 'bootloader' \
  "$PACMAN $BOOTLOADER_PACKAGES" \
  "$BOOTLOADER_EXTRA" \
  "echo \"PROMPT 0
TIMEOUT 50
DEFAULT arch

LABEL arch
  LINUX $PARENT../vmlinuz-linux
  APPEND root=/dev/${DRIVE}p2 rw resume=/swapfile
  INITRD ${INTEL_IMG}$PARENT../initramfs-linux.img

LABEL arch-lts
  LINUX $PARENT../vmlinuz-linux-lts
  APPEND root=/dev/${DRIVE}p2 rw
  INITRD ${INTEL_IMG}$PARENT../initramfs-linux-lts.img\" | tee $SYSLINUX_CONFIG"

chroot_cmd $NETWORK 'network (inc ssh)' \
  "cp /etc/hosts /etc/hosts.original" \
  "echo $MACHINE | tee /etc/hostname" \
  "$PACMAN openssh netctl" \
  "sed -i '/^127.0.0.1/ s/$/ $MACHINE/' /etc/hosts" \
  "[[ `ls /sys/class/net | grep en` != '' ]] && $PACMAN ifplugd" \
  "[[ `ls /sys/class/net | grep wl` != '' ]] && $PACMAN wpa_supplicant wpa_actiond"

chroot_cmd $SERVER 'server packages' \
  "sed -i 's/#?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config" \
  "systemctl enable sshd"

chroot_cmd $SENSORS 'sensors' \
  "$PACMAN lm_sensors" \
  "sensors-detect --auto"

chroot_cmd $STANDARD 'standard packages' "$PACMAN base-devel git vim dialog bash-completion"

chroot_cmd $ADD_USER 'user' \
  "useradd -G wheel -s /bin/bash $NEWUSER" \
  "echo \"$NEWUSER ALL=(ALL) ALL\" | tee -a /etc/sudoers.d/general" \
  "chmod 440 /etc/sudoers.d/general" \
  "chown phil:phil /home/$NEWUSER"

chroot_cmd $SET_PASSWORD 'root password' "echo -e '$PASSWORD\n$PASSWORD\n' | passwd"
chroot_cmd $SET_PASSWORD 'user password' "echo -e '$PASSWORD\n$PASSWORD\n' | passwd $NEWUSER"

# optimised for specific architecture and build times
chroot_cmd $AUR_FLAGS 'aur build flags' \
  "cp /etc/makepkg.conf /etc/makepkg.conf.original" \
  "sed -i 's/CFLAGS=.*/CFLAGS=\"-march=native -O2 -pipe -fstack-protector-strong --param=ssp-buffer-size=4\"/' /etc/makepkg.conf" \
  "sed -i 's/CXXFLAGS=.*/CXXFLAGS=\"\${CFLAGS}\"/' /etc/makepkg.conf" \
  "sed -i 's/.*MAKEFLAGS=.*/MAKEFLAGS=\"-j`nproc`\"/' /etc/makepkg.conf" \
  "sed -i s/#BUILDDIR=/BUILDDIR=/ /etc/makepkg.conf" \
  "sed -i 's/#PKGDEST=.*/PKGDEST=\/tmp/' /etc/makepkg.conf" \
  "sed -i s/.*PKGEXT=.*/PKGEXT='.pkg.tar'/ /etc/makepkg.conf"

chroot_cmd $PACMAN_CONF 'pacman.conf' \
  "cp /etc/pacman.conf /etc/pacman.conf.original" \
  "sed -i s/#Color/Color/ /etc/pacman.conf" \
  "echo -e '\n\n# Enabled by arch_installer\n' | tee -a /etc/pacman.conf" \
  "echo -e '[multilib]\nInclude = /etc/pacman.d/mirrorlist' | tee -a /etc/pacman.conf" \
  "pacman -Syy"

chroot_cmd $NOPASS_BOOT 'no password on shutdown/reboot' \
  "echo '$NEWUSER $MACHINE =NOPASSWD: /usr/bin/systemctl poweroff,/usr/bin/systemctl reboot,/usr/bin/systemctl suspend' | tee -a /etc/sudoers.d/shutdown" \
  "chmod 600 /etc/sudoers.d/shutdown"


#### USER SETUP ####

chroot_cmd true 'install.log ownership' \
  "cd /home/$NEWUSER" \
  "touch install.log" \
  "chown phil:phil install.log"

mkdir -p /mnt/home/$NEWUSER/.ssh
cp id_rsa* /mnt/home/$NEWUSER/.ssh
chroot_cmd $SSH_KEY 'ssh key ownership' \
  "cd /home/$NEWUSER" \
  "cp .ssh/id_rsa.pub .ssh/authorized_keys" \
  "chown -R phil:phil .ssh" \
  "chmod 400 .ssh/id_rsa"

chuser_cmd $SSH_KEY 'trusted hosts' \
  "ssh-keyscan -H github.com | tee -a ~/.ssh/known_hosts"

chuser_cmd $DOTFILES 'dotfiles repo' \
  "mkdir -p $WORKSPACE" \
  "cd $WORKSPACE" \
  "git clone $PUBLIC_GIT/dotfiles.git" \
  "cd dotfiles" \
  "$DOTFILES_SYNC_CMD"


#### REBOOT ####

if [[ $REBOOT = true ]]; then
  echo 'rebooting...'
  umount -R /mnt && reboot
fi


#### DONE ####

title 'finished'

