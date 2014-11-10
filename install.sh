#!/usr/bin/env bash

#### VERSION ####
echo 'Arch Install Script Version 0.2.17'
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
[[ $PRIVATE_GIT ]] || PRIVATE_GIT='git@bitbucket.org:philat'

PACMAN='pacman -S --noconfirm --noprogressbar --needed'
AUR='pacman -U --noconfirm --noprogressbar --needed'
LOG="/home/$NEWUSER/install.log"
MNT_LOG="/mnt$LOG"
TMP_LOG="/tmp/install.log"

#### USER INPUT ####

if [[ ! $MACHINE ]]; then
  echo 'Enter a machine name (Used as hostname)'
  read -s MACHINE
fi

[[ ! $MACHINE ]] && echo 'No machine specified (MACHINE=)' && exit 1

[[ $INSTALL = dryrun ]] && PASSWORD='pass1234'

if [[ ! $PASSWORD ]]; then
  echo 'Choose a user password (Asks once, used for root as well)'
  read -s PASSWORD
fi

echo "MACHINE: $MACHINE"
echo "INSTALL: $INSTALL"

#### OPTIONS #####

if [[ $INSTALL = all || $INSTALL = dryrun ]]; then
  [[ $MACHINE = server ]] && SERVER=true

  [[ $BASE ]] || BASE=true
  [[ $LOCALE ]] || LOCALE=true
  [[ $SWAPFILE ]] || SWAPFILE=true
  [[ $BOOTLOADER ]] || BOOTLOADER=true
  [[ $UEFI ]] || UEFI=true
  [[ $NETWORK ]] || NETWORK=true
  [[ $ADD_USER ]] || ADD_USER=true
  [[ $STANDARD ]] || STANDARD=true
  [[ $VIRTUALBOX ]] || VIRTUALBOX=true
  [[ $AUR_FLAGS ]] || AUR_FLAGS=true
  [[ $RBENV ]] || RBENV=true
  [[ $RUBY_BUILD ]] || RUBY_BUILD=true
  [[ $ATOM ]] || ATOM=true
  [[ $TTF_MS_FONTS ]] || TTF_MS_FONTS=true
  [[ $CUSTOMIZATION ]] || CUSTOMIZATION=true
  [[ $XWINDOWS ]] || XWINDOWS=true
  [[ $SSH_KEY ]] || SSH_KEY=true

  [[ $CREATE_WORKSPACE ]] || CREATE_WORKSPACE=true
  [[ $BIN ]] || BIN=true
  [[ $DOTFILES ]] || DOTFILES=true
  [[ $VIM_CONFIG ]] || VIM_CONFIG=true
  [[ $SET_PASSWORD ]] || SET_PASSWORD=true
fi

# Setup some assumptions based on target machine
$(lspci | grep -q VirtualBox) || VIRTUALBOX=false
[[ $SERVER = true ]] && XWINDOWS=false UEFI=false
[[ $XWINDOWS = false ]] && ATOM=false TTF_MS_FONTS=false VIRTUALBOX=false
[[ $LAPTOP = true ]] && WIFI=true

#### FUNCTIONS ####

# pull out functions from arch-root and include them
# A newer version of Arch in development has moved the
# functions into a common script that can be included
# instead. So extracting them will no longer be needed.
sed '/^usage\(\).*/,/^SHELL=.*/d' /usr/bin/arch-chroot > ~/chroot-common
source ~/chroot-common

chroot_cmd () {
  title="$1"
  cmds="$2"
  run="$3"
  user="$4"

  if [[ $run = true ]]; then
    echo -e "\n" >> $MNT_LOG
    echo -e "/===================================" >> $MNT_LOG
    echo -e "$title" | tee -a $MNT_LOG
    echo -e "------------------------------------" >> $MNT_LOG
    echo -e "$cmds" | sed "s/$PASSWORD/*********/" >> $MNT_LOG

    if [[ $INSTALL != dryrun ]]; then
      echo -e "------------------------------------" >> $MNT_LOG
      LANG=C chroot /mnt su $user -c "$cmds" >> $MNT_LOG 2>&1
    fi

    echo -e "-----------------------------------/" >> $MNT_LOG
  fi
}

chuser_cmd () {
  chroot_cmd "$1" "$2" "$3" $NEWUSER
}

# Move to dotfiles
aur_cmd () {
  url=$1
  run=$2

  name=`basename $url .tar.gz`
  chuser_cmd "build AUR package: $name" "
mkdir -p ~/packages
cd ~/packages
curl -s $url | tar -zx
cd $name
echo $PASSWORD | sudo -S ls
makepkg -sf --noprogressbar >> $LOG 2>&1
" $run

  chroot_cmd "install AUR package: $name" "
$AUR /tmp/$name*.pkg.tar >> $LOG 2>&1
" $run
}

if [[ $INSTALL = 'dryrun' ]]; then
  LOG='install.log'
  MNT_LOG=$LOG
fi


#### BASE INSTALL ####

if [[ $BASE = true && $INSTALL != dryrun ]]; then
  echo -e "\n\nstarting installation" | tee -a $TMP_LOG

  echo 'keyboard' | tee -a $TMP_LOG
  loadkeys uk

  echo 'filesystem' | tee -a $TMP_LOG
  partprobe /dev/$DRIVE
  sgdisk --zap-all /dev/$DRIVE >> $TMP_LOG 2>&1
  if [[ $UEFI = true ]]; then
    sgdisk --new=0:0:0 /dev/$DRIVE >> $TMP_LOG 2>&1
  else
    echo ,,,\* | sfdisk /dev/$DRIVE
  fi
  mkfs.ext4 -F /dev/${DRIVE}1 >> $TMP_LOG 2>&1
  mount /dev/${DRIVE}1 /mnt
  partprobe /dev/$DRIVE

  echo 'create log folder' | tee -a $TMP_LOG
  mkdir -p $(dirname $MNT_LOG)
  mv $TMP_LOG $MNT_LOG


  echo 'arch linux base' | tee -a $MNT_LOG
  mkdir -p /mnt/etc/pacman.d
  cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist.original
  URL="https://www.archlinux.org/mirrorlist/?country=GB&protocol=http&ip_version=4&use_mirror_status=on"
  curl -s $URL | sed 's/^#Server/Server/' > /etc/pacman.d/mirrorlist
  pacman -Syy >> $MNT_LOG 2>&1 # Refresh package lists
  pacstrap /mnt base >> $MNT_LOG 2>&1
  genfstab -p /mnt >> /mnt/etc/fstab
fi


#### MOUNTS FOR CHROOT ####

api_fs_mount /mnt || echo 'api_fs_mount failed' >> $MNT_LOG
track_mount /etc/resolv.conf /mnt/etc/resolv.conf --bind


#### ROOT SETUP ####


chroot_cmd 'time, locale, keyboard' "
ln -s /usr/share/zoneinfo/GB /etc/localtime >> $LOG 2>&1
sed -i s/#en_GB.UTF-8/en_GB.UTF-8/ /etc/locale.gen
locale-gen >> $LOG 2>&1
echo LANG=\"en_GB.UTF-8\" > /etc/locale.conf
$PACMAN ntp >> $LOG 2>&1
systemctl enable ntpd >> $LOG 2>&1
ntpd -qg >> $LOG 2>&1
hwclock --systohc >> $LOG 2>&1
echo KEYMAP=\"uk\" > /etc/vconsole.conf
" $LOCALE

chroot_cmd 'swap file' "
fallocate -l 512M /swapfile >> $LOG 2>&1
chmod 600 /swapfile >> $LOG 2>&1
mkswap /swapfile >> $LOG 2>&1
echo /swapfile none swap defaults 0 0 >> /etc/fstab
" $SWAPFILE

if [[ $UEFI = true ]]; then
  chroot_cmd 'bootloader (UEFI)' "
$PACMAN syslinux efibootmgr >> $LOG 2>&1
mkdir -p /boot/EFI/syslinux
cp -r /usr/lib/syslinux/efi64/* /boot/EFI/syslinux
efibootmgr -c -d /dev/$DRIVE -p 1 -l /EFI/syslinux/syslinux.efi -L \"Syslinux\" >> $LOG 2>&1
echo \"PROMPT 0
TIMEOUT 50
DEFAULT arch

LABEL arch
  LINUX ../vmlinuz-linux
  APPEND root=/dev/${DRIVE}1 rw
  APPEND init=/usr/lib/systemd/systemd
  INITRD ../initramfs-linux.img

LABEL archfallback
  LINUX ../vmlinuz-linux
  APPEND root=/dev/${DRIVE}2 rw
  APPEND init=/usr/lib/systemd/systemd
  INITRD ../initramfs-linux-fallback.img\" > /boot/EFI/syslinux/syslinux.cfg
" $BOOTLOADER
else
  chroot_cmd 'bootloader (MBR)' "
$PACMAN grub >> $LOG 2>&1
grub-install --target=i386-pc --recheck /dev/$DRIVE >> $LOG 2>&1
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 init=\/usr\/lib\/systemd\/systemd\"/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg >> $LOG 2>&1
pacman -Rs --noconfirm --noprogressbar systemd-sysvcompat >> $LOG 2>&1
" $BOOTLOADER
fi

chroot_cmd 'network (inc ssh)' "
cp /etc/hosts /etc/hosts.original
echo $MACHINE > /etc/hostname
sed -i '/^127.0.0.1/ s/$/ $MACHINE/' /etc/hosts
nic_name=$(ls /sys/class/net | grep -vm 1 lo)
systemctl enable dhcpcd@\$nic_name >> $LOG 2>&1
$PACMAN openssh >> $LOG 2>&1
" $NETWORK

chroot_cmd 'wifi' "
$PACMAN wpa_supplicant wpa_actiond
" $WIFI

chroot_cmd 'server packages' "
sed -i 's/#?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl enable sshd >> $LOG 2>&1

$PACMAN lm_sensors
yes '
' | sensors-detect
" $SERVER

chroot_cmd 'standard packages' "
$PACMAN base-devel git vim unison dialog >> $LOG 2>&1
" $STANDARD

chroot_cmd 'user' "
useradd -G wheel -s /bin/bash $NEWUSER >> $LOG 2>&1
echo \"$NEWUSER ALL=(ALL) ALL\" >> /etc/sudoers.d/general
chmod 440 /etc/sudoers.d/general >> $LOG 2>&1
chown phil:phil /home/$NEWUSER >> $LOG 2>&1
echo /etc/sudoers.d/general >> $LOG
cat /etc/sudoers.d/general >> $LOG 2>&1
" $ADD_USER

chroot_cmd 'root password' "echo -e '$PASSWORD\n$PASSWORD\n' | passwd >> $LOG 2>&1" $SET_PASSWORD

chroot_cmd 'user password' "echo -e '$PASSWORD\n$PASSWORD\n' | passwd $NEWUSER >> $LOG 2>&1" $SET_PASSWORD

# optimised for specific architecture and build times
chroot_cmd 'build flags (AUR)' "
cp /etc/makepkg.conf /etc/makepkg.conf.original
sed -i 's/CFLAGS=.*/CFLAGS=\"-march=native -O2 -pipe -fstack-protector-strong --param=ssp-buffer-size=4\"/' /etc/makepkg.conf
sed -i 's/CXXFLAGS=.*/CXXFLAGS=\"\${CFLAGS}\"/' /etc/makepkg.conf
sed -i 's/.*MAKEFLAGS=.*/MAKEFLAGS=\"-j`nproc`\"/' /etc/makepkg.conf
sed -i s/#BUILDDIR=/BUILDDIR=/ /etc/makepkg.conf
sed -i 's/#PKGDEST=.*/PKGDEST=\/tmp/' /etc/makepkg.conf
sed -i s/.*PKGEXT=.*/PKGEXT='.pkg.tar'/ /etc/makepkg.conf
grep '^CFLAGS' /etc/makepkg.conf >> $LOG 2>&1
grep '^CXXFLAGS' /etc/makepkg.conf >> $LOG 2>&1
grep '^MAKEFLAGS' /etc/makepkg.conf >> $LOG 2>&1
grep '^BUILDDIR' /etc/makepkg.conf >> $LOG 2>&1
grep '^PKGDEST' /etc/makepkg.conf >> $LOG 2>&1
grep '^PKGEXT' /etc/makepkg.conf >> $LOG 2>&1
" $AUR_FLAGS

chroot_cmd 'pacman & sudoer customization' "
cp /etc/pacman.conf /etc/pacman.conf.original
sed -i s/#Color/Color/ /etc/pacman.conf
echo '$NEWUSER ALL=NOPASSWD:/sbin/shutdown' >> /etc/sudoers.d/shutdown
echo '$NEWUSER ALL=NOPASSWD:/sbin/reboot' >> /etc/sudoers.d/shutdown
chmod 440 /etc/sudoers.d/shutdown >> $LOG 2>&1
echo /etc/sudoers.d/shutdown >> $LOG
cat /etc/sudoers.d/shutdown >> $LOG 2>&1
" $CUSTOMIZATION

chroot_cmd 'xwindows packages and applications' "
$PACMAN xorg-server xorg-server-utils xorg-xinit elementary-icon-theme xcursor-vanilla-dmz gnome-themes-standard ttf-ubuntu-font-family feh lxappearance rxvt-unicode pcmanfm slock xautolock conky >> $LOG
" $XWINDOWS

chroot_cmd 'virtualbox guest' "
$PACMAN virtualbox-guest-utils virtualbox-guest-dkms >> $LOG 2>&1
echo vboxguest >> /etc/modules-load.d/virtualbox.conf
echo vboxsf >> /etc/modules-load.d/virtualbox.conf
echo vboxvideo >> /etc/modules-load.d/virtualbox.conf
systemctl enable vboxservice >> $LOG 2>&1
echo /etc/modules-load.d/virtualbox.conf >> $LOG 2>&1
cat /etc/modules-load.d/virtualbox.conf >> $LOG 2>&1
" $VIRTUALBOX


#### USER SETUP ####

chroot_cmd 'install.log ownership' "
cd /home/$NEWUSER
touch install.log
chown phil:phil install.log
" true

mkdir -p /mnt/home/$NEWUSER/.ssh
cp id_rsa* /mnt/home/$NEWUSER/.ssh
chroot_cmd 'ssh key ownership' "
cd /home/$NEWUSER
cp .ssh/id_rsa.pub .ssh/authorized_keys
chown -R phil:phil .ssh
chmod 400 .ssh/id_rsa
" $SSH_KEY

chuser_cmd 'trusted hosts' "
ssh-keyscan -H github.com > ~/.ssh/known_hosts 2>> $LOG
" $SSH_KEY

chuser_cmd 'create workspace' "mkdir -p $WORKSPACE >> $LOG 2>&1" $CREATE_WORKSPACE

# Currently getting `sudo: no tty present and no askpass program specified` when trying to
# install dependencies for Atom. The following installs the dependencies first as a
# workaround for now.
chroot_cmd 'dependencies for Atom' "
$PACMAN --asdeps alsa-lib git gconf gtk2 libatomic_ops libgcrypt libgnome-keyring libnotify libxtst nodejs nss python2
" $ATOM

aur_cmd 'https://aur.archlinux.org/packages/rb/rbenv/rbenv.tar.gz' $RBENV
aur_cmd 'https://aur.archlinux.org/packages/ru/ruby-build/ruby-build.tar.gz' $RUBY_BUILD
aur_cmd 'https://aur.archlinux.org/packages/tt/ttf-ms-fonts/ttf-ms-fonts.tar.gz' $TTF_MS_FONTS
aur_cmd 'https://aur.archlinux.org/packages/at/atom-editor/atom-editor.tar.gz' $ATOM

chuser_cmd 'dwm' "
sudo $PASSWORD | sudo -S $PACMAN libxinerama libxft >> $LOG 2>&1
cd $WORKSPACE
git clone $PUBLIC_GIT/dwm.git >> $LOG 2>&1
cd dwm
echo $PASSWORD | sudo -S make clean install >> $LOG 2>&1
" $XWINDOWS

chuser_cmd 'clone and configure bin' "
cd ~
git clone $PUBLIC_GIT/bin.git >> $LOG 2>&1
echo PASSWORD_DIR=$WORKSPACE/documents >> ~/.pwconfig
echo PASSWORD_FILE=.passwords.csv >> ~/.pwconfig
echo EDIT=vim >> ~/.pwconfig
" $BIN

chuser_cmd 'clone dotfiles' "
cd $WORKSPACE
git clone $PUBLIC_GIT/dotfiles.git >> $LOG 2>&1
cd dotfiles
bin/sync.sh >> $LOG 2>&1
" $DOTFILES

chuser_cmd 'vim plugins and theme' "
mkdir -p ~/.vim/bundle
cd ~/.vim/bundle
git clone https://github.com/tpope/vim-pathogen.git >> $LOG 2>&1
git clone https://github.com/tpope/vim-surround.git >> $LOG 2>&1
git clone https://github.com/msanders/snipmate.vim.git >> $LOG 2>&1
git clone https://github.com/scrooloose/nerdtree.git >> $LOG 2>&1
git clone https://github.com/vim-ruby/vim-ruby.git >> $LOG 2>&1
git clone https://github.com/tpope/vim-rails.git >> $LOG 2>&1
git clone https://github.com/tpope/vim-rake.git >> $LOG 2>&1
git clone https://github.com/tpope/vim-bundler.git >> $LOG 2>&1
git clone https://github.com/slim-template/vim-slim.git >> $LOG 2>&1
git clone https://github.com/tpope/vim-git.git >> $LOG 2>&1
git clone https://github.com/tpope/vim-fugitive.git >> $LOG 2>&1
git clone https://github.com/tpope/vim-markdown.git >> $LOG 2>&1
git clone https://github.com/tpope/vim-dispatch.git >> $LOG 2>&1
git clone https://github.com/Keithbsmiley/rspec.vim.git >> $LOG 2>&1
git clone https://github.com/mileszs/ack.vim.git >> $LOG 2>&1
git clone https://github.com/bling/vim-airline.git >> $LOG 2>&1
git clone https://github.com/kien/ctrlp.vim.git >> $LOG 2>&1

mkdir -p ~/.vim/colors
cd ~/.vim/colors
curl -s -O https://raw.githubusercontent.com/tomasr/molokai/master/colors/molokai.vim >> $LOG 2>&1

vim -c 'Helptags | q'
" $VIM_CONFIG


#### REBOOT ####

if [[ $REBOOT = true ]]; then
  echo 'rebooting...'
  umount -R /mnt && reboot
fi
