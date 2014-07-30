#!/usr/bin/env bash

#### VERSION ####
echo 'Arch Install Script Version 0.1.43'
echo '=================================='
echo ''


#### VARIABLES ####

[[ $NEWUSER ]] || NEWUSER='phil'
[[ $WORKSPACE ]] || WORKSPACE='~/ws' # keep it short for window titles
PACMAN='pacman -S --noconfirm --noprogressbar'
AUR='pacman -U --noconfirm --noprogressbar'
REPO='git@github.com:PhilT'
LOG="/var/log/install.log"
USER_LOG="/home/$NEWUSER/install.log"
MNT_LOG="/mnt$LOG"
MNT_USER_LOG="/mnt$USER_LOG"


#### USER INPUT ####

[[ $MACHINE ]] || MACHINE='(not specified)'

[[ $INSTALL = dryrun ]] && USERPASS='userpass'

if [[ ! $USERPASS ]]; then
  echo 'Choose a user password (Be careful, only asks once)'
  read -s USERPASS
fi

echo "MACHINE: $MACHINE"
echo "INSTALL: $INSTALL"

#### OPTIONS #####

if [[ $INSTALL = all || $INSTALL = dryrun ]]; then
  [[ $BASE ]] || BASE=true
  [[ $LOCALE ]] || LOCALE=true
  [[ $SWAPFILE ]] || SWAPFILE=true
  [[ $BOOTLOADER ]] || BOOTLOADER=true
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
  [[ $SET_USERPASS ]] || SET_USERPASS=true
fi

$(lspci | grep -q VirtualBox) || VIRTUALBOX=false
[[ $MACHINE = 'server' ]] && XWINDOWS=false
[[ ! $XWINDOW ]] && ATOM=false && TTF_MS_FONTS=false && VIRTUALBOX=false


#### FUNCTIONS ####

# pull out functions from arch-root and include them
# A newer version of Arch in development has moved the
# functions into a common script that can be included
# instead. So extracting them will no longer be needed.
sed '/^usage\(\).*/,/^SHELL=.*/d' /usr/bin/arch-chroot > ~/chroot-common
source ~/chroot-common

chroot_exec () {
  commands="$1"
  user=$2

  chroot /mnt su $user -c "$commands"
}

run_or_dry () {
  commands="$1"
  logfile="$2"
  title="$3"
  user="$4"

  if [[ $INSTALL = dryrun ]]; then
    if [[ $title =~ password ]]; then
      echo -e "$title" "$commands" >> $logfile
    else
      echo -e "$commands" >> $logfile
    fi
  else
    chroot_exec "$commands" "$user"
  fi
}

chroot_cmd () {
  title="$1"
  commands="$2"
  run="$3"

  if [[ $run = true ]]; then
    echo -e "\n\n" >> $MNT_LOG
    echo -e "$title" | tee -a $MNT_LOG
    echo -e "------------------------------------" >> $MNT_LOG
    run_or_dry "$commands" $MNT_LOG "$title"
  fi
}

chuser_cmd () {
  title="$1"
  commands="$2"
  run="$3"

  if [[ $run = true ]]; then
    echo -e "\n\n" >> $MNT_USER_LOG
    echo -e "$title" | tee -a $MNT_USER_LOG
    echo -e "------------------------------------" >> $MNT_USER_LOG
    run_or_dry "$commands" $MNT_USER_LOG "$title" $NEWUSER
  fi
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
makepkg -s -f --noprogressbar >> $USER_LOG 2>&1
" $run

  chroot_cmd "install AUR package: $name" "
$AUR /tmp/$name*.pkg.tar >> $USER_LOG 2>&1
" $run
}

if [[ $INSTALL = 'dryrun' ]]; then
  MNT_LOG=$LOG
  USER_LOG="install.log"
  MNT_USER_LOG=$USER_LOG
fi


#### BASE INSTALL ####

if [[ $BASE = true && $INSTALL != dryrun ]]; then
  echo -e "\n\nstarting installation" | tee -a $LOG

  echo 'keyboard' | tee -a $LOG
  loadkeys uk

  echo 'filesystem' | tee -a $LOG
  partprobe /dev/sda
  sgdisk --zap-all /dev/sda >> $LOG 2>&1
  echo -e "n\n\n\n\n\nw\n" | fdisk /dev/sda >> $LOG 2>&1
  mkfs.ext4 -F /dev/sda1 >> $LOG 2>&1
  mount /dev/sda1 /mnt
  partprobe /dev/sda

  echo 'create log folders'
  mkdir -p $(dirname $MNT_LOG)
  mkdir -p $(dirname $MNT_USER_LOG)

  rm -f $MNT_LOG $MNT_USER_LOG

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
echo en_GB.UTF-8 UTF-8 >> /etc/locale.gen
locale-gen >> $LOG 2>&1
$PACMAN ntp >> $LOG 2>&1
systemctl enable ntpd.service >> $LOG 2>&1
ntpd -qg >> $LOG 2>&1
hwclock --systohc >> $LOG 2>&1
echo KEYMAP=\"uk\" >> /etc/vconsole.conf
" $LOCALE

chroot_cmd 'swap file' "
fallocate -l 512M /swapfile >> $LOG 2>&1
chmod 600 /swapfile >> $LOG 2>&1
mkswap /swapfile >> $LOG 2>&1
echo /swapfile none swap defaults 0 0 >> /etc/fstab
" $SWAPFILE

chroot_cmd 'bootloader' "
$PACMAN grub >> $LOG 2>&1
grub-install --target=i386-pc --recheck /dev/sda >> $LOG 2>&1
grub-mkconfig -o /boot/grub/grub.cfg >> $LOG 2>&1
" $BOOTLOADER

chroot_cmd 'network (inc sshd)' "
cp /etc/hosts /etc/hosts.original
echo $MACHINE > /etc/hostname
echo 127.0.0.1 localhost.localdomain localhost $MACHINE > /etc/hosts
echo ::1       localhost.localdomain localhost >> /etc/hosts
systemctl enable dhcpcd@enp0s3.service >> $LOG 2>&1
$PACMAN openssh >> $LOG 2>&1
" $NETWORK

chroot_cmd 'standard packages' "$PACMAN base-devel git vim >> $LOG 2>&1" $STANDARD

chroot_cmd 'user' "
useradd -G wheel -s /bin/bash $NEWUSER >> $LOG 2>&1
echo \"$NEWUSER ALL=(ALL) ALL\" >> /etc/sudoers.d/general
chmod 440 /etc/sudoers.d/general >> $LOG 2>&1
chown phil:phil /home/$NEWUSER >> $LOG 2>&1
echo /etc/sudoers.d/general >> $LOG
cat /etc/sudoers.d/general >> $LOG 2>&1
" $ADD_USER

chroot_cmd 'user password' "echo -e '$USERPASS\n$USERPASS\n' | passwd $NEWUSER >> $LOG 2>&1" $SET_USERPASS

# optimised for specific architecture and build times
chroot_cmd 'aur build flags' "
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
$PACMAN xorg-server xorg-server-utils xorg-xinit elementary-icon-theme xcursor-vanilla-dmz gnome-themes-standard ttf-ubuntu-font-family feh lxappearance rxvt-unicode pcmanfm suckless-tools xautolock conky >> $LOG
" $XWINDOWS

chroot_cmd 'virtualbox guest' "
$PACMAN virtualbox-guest-utils virtualbox-guest-dkms >> $LOG 2>&1
echo vboxguest >> /etc/modules-load.d/virtualbox.conf
echo vboxsf >> /etc/modules-load.d/virtualbox.conf
echo vboxvideo >> /etc/modules-load.d/virtualbox.conf
systemctl enable vboxservice.service >> $LOG 2>&1
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
ssh-keyscan -H github.com >> .ssh/known_hosts 2>> $LOG
" $SSH_KEY

chuser_cmd 'create workspace' "mkdir -p $WORKSPACE >> $USER_LOG 2>&1" $CREATE_WORKSPACE

aur_cmd 'https://aur.archlinux.org/packages/rb/rbenv/rbenv.tar.gz' $RBENV
aur_cmd 'https://aur.archlinux.org/packages/ru/ruby-build/ruby-build.tar.gz' $RUBY_BUILD
aur_cmd 'https://aur.archlinux.org/packages/tt/ttf-ms-fonts/ttf-ms-fonts.tar.gz' $TTF_MS_FONTS
aur_cmd 'https://aur.archlinux.org/packages/at/atom-editor/atom-editor.tar.gz' $ATOM

chuser_cmd 'dwm' "
cd $WORKSPACE
git clone $REPO/dwm.git >> $USER_LOG 2>&1
cd dwm
make clean install >> $USER_LOG 2>&1
" $XWINDOWS

chuser_cmd 'clone and configure bin' "
cd ~
git clone $REPO/bin.git >> $USER_LOG 2>&1
echo PASSWORD_DIR=$WORKSPACE/documents >> ~/.pwconfig
echo PASSWORD_FILE=.passwords.csv >> ~/.pwconfig
echo EDIT=vim >> ~/.pwconfig
" $BIN

chuser_cmd 'clone dotfiles' "
cd $WORKSPACE
git clone $REPO/dotfiles.git >> $USER_LOG 2>&1
cd dotfiles
bin/sync.sh >> $USER_LOG 2>&1
" $DOTFILES

chuser_cmd 'vim plugins and theme' "
mkdir -p ~/.vim/bundle
cd ~/.vim/bundle
git clone https://github.com/tpope/vim-pathogen.git >> $USER_LOG 2>&1
git clone https://github.com/tpope/vim-surround.git >> $USER_LOG 2>&1
git clone https://github.com/msanders/snipmate.vim.git >> $USER_LOG 2>&1
git clone https://github.com/scrooloose/nerdtree.git >> $USER_LOG 2>&1
git clone https://github.com/vim-ruby/vim-ruby.git >> $USER_LOG 2>&1
git clone https://github.com/tpope/vim-rails.git >> $USER_LOG 2>&1
git clone https://github.com/tpope/vim-rake.git >> $USER_LOG 2>&1
git clone https://github.com/tpope/vim-bundler.git >> $USER_LOG 2>&1
git clone https://github.com/tpope/vim-haml.git >> $USER_LOG 2>&1
git clone https://github.com/tpope/vim-git.git >> $USER_LOG 2>&1
git clone https://github.com/tpope/vim-fugitive.git >> $USER_LOG 2>&1
git clone https://github.com/tpope/vim-markdown.git >> $USER_LOG 2>&1
git clone https://github.com/tpope/vim-dispatch.git >> $USER_LOG 2>&1
git clone https://github.com/Keithbsmiley/rspec.vim.git >> $USER_LOG 2>&1
git clone https://github.com/mileszs/ack.vim.git >> $USER_LOG 2>&1
git clone https://github.com/bling/vim-airline.git >> $USER_LOG 2>&1
git clone https://github.com/kien/ctrlp.vim.git >> $USER_LOG 2>&1

mkdir -p ~/.vim/colors
cd ~/.vim/colors
curl -s -O https://raw.githubusercontent.com/tomasr/molokai/master/colors/molokai.vim >> $USER_LOG 2>&1

vim -c 'Helptags | q'
" $VIM_CONFIG


#### REBOOT ####

if [[ $REBOOT = true ]]; then
  umount -R /mnt
  reboot
fi
