#!/usr/bin/env bash

#### VERSION ####
echo 'Arch Install Script Version 0.1.23'
echo '=================================='
echo ''


#### VARIABLES ####

USER='phil'
WORKSPACE='~/ws' # keep it short for window titles
PACMAN='pacman -S --noconfirm --noprogressbar'
AUR='pacman -U --noconfirm --noprogressbar'
CHROOT='arch-chroot /mnt /bin/bash -c'
CHUSER="arch-chroot /mnt /bin/su $USER -c"
REPO='git@github.com:PhilT'
LOG="/var/log/install.log"
USER_LOG="/home/$USER/install.log"
MNT_LOG="/mnt$LOG"
MNT_USER_LOG="/mnt$USER_LOG"



#### USER INPUT ####

echo 'Choose HOST [server|desktop|laptop]:'
read HOST

echo 'Choose a user password (Be careful, only asks once)'
echo 'Press enter to skip and do a dryrun'
read -s USERPASS

[[ ! $USERPASS ]] && INSTALL_TYPE=dryrun

if [[ $INSTALL_TYPE != 'dryrun' ]]; then
  echo 'Choose an option to begin installation'
  echo 'base - base system only (does not reboot)'
  echo 'all - complete install except reboot'
  echo 'full - complete install including reboot'
  echo 'dryrun - echo all commands instead of executing them (default)'
  echo 'selected - selected options only - set ENV vars to install'
  echo '.'
  read INSTALL_TYPE
fi

if [[ ! $INSTALL_TYPE || $INSTALL_TYPE = 'dryrun' ]]; then
  INSTALL_TYPE='dryrun'
  USERPASS='userpass'
fi

echo "Option Choosen: $INSTALL_TYPE"

#### OPTIONS #####

case $INSTALL_TYPE in
'base')
  BASE=true
  ;;
'all' | 'full' | 'dryrun')
  if [[ $INSTALL_TYPE = 'full' ]]; then
    BASE=true
    FINALISE=true
  elif [[ $INSTALL_TYPE = 'all' ]]; then
    BASE=true
  fi
  LOCALE=true
  SWAPFILE=true
  BOOTLOADER=true
  NETWORK=true
  ADD_USER=true
  STANDARD=true
  VIRTUALBOX=true
  AUR_BUILD_FLAGS=true
  RBENV=true
  RUBY_BUILD=true
  ATOM=true
  TTF_MS_FONTS=true
  CUSTOMIZATION=true
  XWINDOWS=true
  CREATE_WORKSPACE=true
  BIN=true
  DOTFILES=true
  VIM=true
  SET_USERPASS=true
  ;;
'selected')
  ;;
esac

[[ $HOST != 'server' ]] && unset SWAPFILE
$(lspci | grep -q VirtualBox) || unset VIRTUALBOX
[[ $HOST = 'server' ]] && unset XWINDOWS
[[ ! $XWINDOW ]] && unset ATOM && unset TTF_MS_FONTS


#### FUNCTIONS ####

run_or_dry () {
  chroot=$1
  commands=$2
  logfile=$3
  title=$4

  if [[ $INSTALL_TYPE = 'dryrun' ]]; then
    if [[ $title =~ password ]]; then
      echo -e "$title" "$commands" >> $logfile
    else
      echo -e "$commands" >> $logfile
    fi
  else
    $chroot "$commands"
  fi
}

chroot_cmd () {
  title="$1"
  commands="$2"
  run="$3"

  if [[ $run ]]; then
    echo -e "\n\n" >> $MNT_LOG
    echo -e "$title" | tee -a $MNT_LOG
    echo -e "------------------------------------" >> $MNT_LOG
    run_or_dry "$CHROOT" "$commands" $MNT_LOG "$title"
  fi
}

chuser_cmd () {
  title="$1"
  commands="$2"
  run="$3"

  if [[ $run ]]; then
    echo -e "\n\n" >> $MNT_USER_LOG
    echo -e "$title" | tee -a $MNT_USER_LOG
    echo -e "------------------------------------" >> $MNT_USER_LOG
    run_or_dry "$CHUSER" "$commands" $MNT_USER_LOG "$title"
  fi
}

aur_cmd () {
  url=$1
  run=$2

  name=`basename $url .tar.gz`
  chuser_cmd "install from aur: $name" "
mkdir -p ~/packages
cd ~/packages
curl -0 $url | tar -zx >> $LOG
cd $name
makepkg -s >> $LOG
sudo $AUR /tmp/$name.pkg.tar
" $run
}

if [[ $INSTALL_TYPE = 'dryrun' ]]; then
  MNT_LOG=$LOG
  USER_LOG="install.log"
  MNT_USER_LOG=$USER_LOG
fi


#### BASE INSTALL ####

if [[ $BASE ]]; then
  echo -e "\n\nstarting installation" | tee -a $LOG

  echo 'keyboard' | tee -a $LOG
  loadkeys uk

  echo 'filesystem' | tee -a $LOG
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
  curl $URL | sed 's/^#Server/Server/' > /etc/pacman.d/mirrorlist
  pacman -Syy >> $MNT_LOG 2>&1 # Refresh package lists
  pacstrap /mnt base >> $MNT_LOG 2>&1
  genfstab -p /mnt >> /mnt/etc/fstab
fi

#### $CHROOT SETUP ####

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
echo $HOST > /etc/hostname
echo 127.0.0.1 localhost.localdomain localhost $HOST > /etc/hosts
echo ::1       localhost.localdomain localhost >> /etc/hosts
systemctl enable dhcpcd@enp0s3.service >> $LOG 2>&1
$PACMAN openssh >> $LOG 2>&1
" $NETWORK

chroot_cmd 'user' "
useradd -G wheel -s /bin/bash $USER >> $LOG 2>&1
echo \"$USER ALL=(ALL) ALL\" >> /etc/sudoers.d/general
chmod 440 /etc/sudoers.d/general >> $LOG 2>&1
echo /etc/sudoers.d/general >> $LOG
cat /etc/sudoers.d/general >> $LOG 2>&1
" $ADD_USER

chroot_cmd 'user password' "echo -e '$USERPASS\n$USERPASS\n' | passwd $USER >> $LOG" $SET_USERPASS

chroot_cmd 'standard packages' "$PACMAN base-devel git vim >> $LOG 2>&1" $STANDARD

chroot_cmd 'virtualbox guest' "
$PACMAN virtualbox-guest-utils virtualbox-guest-dkms >> $LOG 2>&1
echo vboxguest >> /etc/modules-load.d/virtualbox.conf
echo vboxsf >> /etc/modules-load.d/virtualbox.conf
echo vboxvideo >> /etc/modules-load.d/virtualbox.conf
systemctl enable vboxservice.service >> $LOG 2>&1
echo /etc/modules-load.d/virtualbox.conf >> $LOG 2>&1
cat /etc/modules-load.d/virtualbox.conf >> $LOG 2>&1
" $VIRTUALBOX

# optimised for specific architecture and build times
chroot_cmd 'aur build flags' "
cp /etc/makepkg.conf /etc/makepkg.conf.original
sed -i 's/CFLAGS=.*/CFLAGS=\"-march=native -O2 -pipe -fstack-protector-strong --param=ssp-buffer-size=4\"/' /etc/makepkg.conf
sed -i 's/CXXFLAGS=.*/CXXFLAGS=\"\${CFLAGS}\"/' /etc/makepkg.conf
sed -i 's/.*MAKEFLAGS=.*/MAKEFLAGS=\"-j`nproc`\"/' /etc/makepkg.conf
sed -i s/#BUILDDIR=/BUILDDIR=/ /etc/makepkg.conf
sed -i s/.*PKGEXT=.*/PKGEXT='.pkg.tar'/ /etc/makepkg.conf
grep '^CFLAGS' /etc/makepkg.conf >> $LOG 2>&1
grep '^CXXFLAGS' /etc/makepkg.conf >> $LOG 2>&1
grep '^MAKEFLAGS' /etc/makepkg.conf >> $LOG 2>&1
grep '^BUILDDIR' /etc/makepkg.conf >> $LOG 2>&1
grep '^PKGEXT' /etc/makepkg.conf >> $LOG 2>&1

" $AUR_BUILD_FLAGS

chroot_cmd 'pacman & sudoer customization' "
cp /etc/pacman.conf /etc/pacman.conf.original
sed -i s/#Color/Color/ /etc/pacman.conf
echo '$USER ALL=NOPASSWD:/sbin/shutdown' >> /etc/sudoers.d/shutdown
echo '$USER ALL=NOPASSWD:/sbin/reboot' >> /etc/sudoers.d/shutdown
chmod 440 /etc/sudoers.d/shutdown >> $LOG 2>&1
echo /etc/sudoers.d/shutdown >> $LOG
cat /etc/sudoers.d/shutdown >> $LOG 2>&1
" $CUSTOMIZATION

chroot_cmd 'xwindows packages and applications' "
$PACMAN xorg-server xorg-server-utils xorg-xinit elementary-icon-theme xcursor-vanilla-dmz gnome-themes-standard ttf-ubuntu-font-family feh lxappearance rxvt-unicode pcmanfm suckless-tools xautolock conky >> $LOG
" $XWINDOWS


#### $CHUSER SETUP ####

chuser_cmd 'create workspace' "mkdir -p $WORKSPACE >> $USER_LOG" $CREATE_WORKSPACE

aur_cmd 'https://aur.archlinux.org/packages/rb/rbenv/rbenv.tar.gz' $RBENV
aur_cmd 'https://aur.archlinux.org/packages/ru/ruby-build/ruby-build.tar.gz' $RUBY_BUILD
aur_cmd 'https://aur.archlinux.org/packages/tt/ttf-ms-fonts/ttf-ms-fonts.tar.gz' $TTF_MS_FONTS
aur_cmd 'https://aur.archlinux.org/packages/at/atom-editor/atom-editor.tar.gz' $ATOM

chuser_cmd 'dwm' "
cd $WORKSPACE
git clone $REPO/dwm.git >> $USER_LOG
cd dwm
make clean install >> $USER_LOG
" $XWINDOWS

chuser_cmd 'clone and configure bin' "
cd ~
git clone $REPO/bin.git >> $USER_LOG
echo PASSWORD_DIR=$WORKSPACE/documents >> ~/.pwconfig
echo PASSWORD_FILE=.passwords.csv >> ~/.pwconfig
echo EDIT=vim >> ~/.pwconfig
" $BIN

chuser_cmd 'clone dotfiles' "
cd $WORKSPACE
git clone $REPO/dotfiles.git >> $USER_LOG
cd dotfiles
bin/sync.sh >> $USER_LOG
" $DOTFILES

chuser_cmd 'vim plugins and theme' "
mkdir -p ~/.vim/bundle
cd ~/.vim/bundle
git clone https://github.com/tpope/vim-pathogen.git >> $USER_LOG
git clone https://github.com/tpope/vim-surround.git >> $USER_LOG
git clone https://github.com/msanders/snipmate.vim.git >> $USER_LOG
git clone https://github.com/scrooloose/nerdtree.git >> $USER_LOG
git clone https://github.com/vim-ruby/vim-ruby.git >> $USER_LOG
git clone https://github.com/tpope/vim-rails.git >> $USER_LOG
git clone https://github.com/tpope/vim-rake.git >> $USER_LOG
git clone https://github.com/tpope/vim-bundler.git >> $USER_LOG
git clone https://github.com/tpope/vim-haml.git >> $USER_LOG
git clone https://github.com/tpope/vim-git.git >> $USER_LOG
git clone https://github.com/tpope/vim-fugitive.git >> $USER_LOG
git clone https://github.com/tpope/vim-markdown.git >> $USER_LOG
git clone https://github.com/tpope/vim-dispatch.git >> $USER_LOG
git clone https://github.com/Keithbsmiley/rspec.vim.git >> $USER_LOG
git clone https://github.com/mileszs/ack.vim.git >> $USER_LOG
git clone https://github.com/bling/vim-airline.git >> $USER_LOG
git clone https://github.com/kien/ctrlp.vim.git >> $USER_LOG

mkdir -p ~/.vim/colors
cd ~/.vim/colors
curl -O https://raw.githubusercontent.com/tomasr/molokai/master/colors/molokai.vim >> $USER_LOG

vim -c 'Helptags | q'
" $VIM


#### FINALISE ####

if [[ $FINALISE ]]; then
  umount -R /mnt
  reboot
fi
