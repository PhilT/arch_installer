#!/usr/bin/env bash

#### VERSION ####
echo 'Arch Install Script Version 0.1.14'


#### VARIABLES ####

USER=phil
WORKSPACE='~/ws'
PACMAN='pacman -S --noconfirm'
AUR='pacman -U --noconfirm'
CHROOT='arch-chroot /mnt /bin/bash -c'
CHUSER="arch-chroot /mnt /bin/su $USER -c"
REPO='git@github.com:PhilT'


#### USER INPUT ####

echo 'Choose HOST [server|desktop|laptop]:'
read HOST

echo 'Choose passwords (Be careful, only asks once)'
echo 'Press enter to skip and do a dryrun'
echo 'for root:'
read -s ROOTPASS

echo "for $USER:"
read -s USERPASS

[[ ! $ROOTPASS || ! $USERPASS ]] && INSTALL_TYPE=dryrun

if [[ $INSTALL_TYPE != 'dryrun' ]]; then
  echo 'Choose an option to begin installation'
  echo 'base - base system only (does not reboot)'
  echo 'full - complete install including reboot'
  echo 'dryrun - echo all commands instead of executing them (default)'
  echo 'selected - selected options only - set ENV vars to install'
  echo '.'
  read INSTALL_TYPE
fi

if [[ ! $INSTALL_TYPE || $INSTALL_TYPE = 'dryrun' ]]; then
  INSTALL_TYPE='dryrun'
  ROOTPASS='rootpass'
  USERPASS='userpass'
fi

#### OPTIONS #####

case $INSTALL_TYPE in
'base')
  BASE=true
  ;;
'full' | 'dryrun')
  if [[ $INSTALL_TYPE != 'dryrun' ]]; then
    FINALISE=true
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
  SET_ROOTPASS=true
  BIN=true
  DOTFILES=true
  VIM=true
  SET_USERPASS=true
  ;;
'selected')
  ;;
esac

[[ $HOST != 'server' ]] && unset SWAPFILE
[[ $(lspci | grep -q VirtualBox) ]] || unset VIRTUALBOX
[[ $HOST = 'server' ]] && unset XWINDOWS
[[ ! $XWINDOW ]] && unset ATOM && unset TTF_MS_FONTS


#### FUNCTIONS ####

echo_title () {
  title="$1"
  echo -e "\n\n$title"
  echo -e "------------------------------------"
}

run_or_dry () {
  chroot=$1
  commands=$2

  if [[ $INSTALL_TYPE = 'dryrun' ]]; then
    echo -e "$commands"
  else
    $chroot "$commands"
  fi
}

chroot_cmd () {
  title="$1"
  commands="$2"
  run="$3"

  if [[ $run ]]; then
    echo_title "$title"
    run_or_dry "$CHROOT" "$commands"
  fi
}

chuser_cmd () {
  title="$1"
  commands="$2"
  run="$3"

  if [[ $run ]]; then
    echo_title "$title"
    run_or_dry "$CHUSER" "$commands"
  fi
}

aur_cmd () {
  url=$1
  run=$2

  name=`basename $url .tar.gz`
  chroot_cmd "install from aur: $name" "
cd /usr/local/src
curl -0 $url | tar -zx
cd $name
makepkg -s
$AUR $name.pkg.tar
" $run
}


#### BASE INSTALL ####

if [[ $BASE ]]; then
  echo -e "\n\nstarting installation"

  echo 'keyboard'
  loadkeys uk

  echo 'filesystem'
  sgdisk --zap-all /dev/sda

  echo -e "n\n\n\n\n\nw\n" | fdisk /dev/sda
  mkfs.ext4 -F /dev/sda1
  mount /dev/sda1 /mnt

  echo 'arch linux base'
  mkdir /mnt/etc/pacman.d
  cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist.original
  URL="https://www.archlinux.org/mirrorlist/?country=GB&protocol=http&ip_version=4&use_mirror_status=on"
  curl $URL | sed 's/^#Server/Server/' > /etc/pacman.d/mirrorlist
  pacman -Syy # Refresh package lists
  pacstrap /mnt base
  genfstab -p /mnt >> /mnt/etc/fstab
fi

#### $CHROOT SETUP ####

chroot_cmd 'time, locale, keyboard' "
ln -s /usr/share/zoneinfo/GB /etc/localtime
echo en_GB.UTF-8 UTF-8 >> /etc/locale.gen
locale-gen
$PACMAN ntp
systemctl enable ntpd.service
ntpd -qg
hwclock --systohc
echo KEYMAP=\"uk\" >> /etc/vconsole.conf
" $LOCALE

chroot_cmd 'swap file' "
fallocate -l 512M /swapfile
chmod 600 /swapfile
mkswap /swapfile
echo /swapfile none swap defaults 0 0 >> /etc/fstab
" $SWAPFILE

chroot_cmd 'bootloader' "
$PACMAN grub
grub-install --target=i386-pc --recheck /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
" $BOOTLOADER

chroot_cmd 'network (inc sshd)' "
cp /etc/hosts /etc/hosts.original
echo $HOST > /etc/hostname
echo 127.0.0.1 localhost.localdomain localhost $HOST > /etc/hosts
echo ::1       localhost.localdomain localhost >> /etc/hosts
systemctl enable dhcpcd@enp0s3.service
$PACMAN openssh
" $NETWORK

chroot_cmd 'user' "
useradd -m -G wheel -s /bin/bash $USER
echo $USER ALL=(ALL) ALL >> /etc/sudoers.d/general
" $ADD_USER

chroot_cmd 'standard packages' "$PACMAN base-devel git vim" $STANDARD

chroot_cmd 'virtualbox guest' "
$PACMAN virtualbox-guest-utils virtualbox-guest-dkms
echo vboxguest >> /etc/modules-load.d/virtualbox.conf
echo vboxsf >> /etc/modules-load.d/virtualbox.conf
echo vboxvideo >> /etc/modules-load.d/virtualbox.conf
systemctl enable vboxservice.service
" $VIRTUALBOX

# optimised for specific architecture and build times
chroot_cmd 'aur build flags' "
cp /etc/makepkg.conf /etc/makepkg.conf.original
sed -i s/CFLAGS=.*/CFLAGS=\"-march=native -O2 -pipe -fstack-protector --param=ssp-buffer-size=4\"/ /etc/makepkg.conf
sed -i s/CXXFLAGS=.*/CXXFLAGS=\"\${CFLAGS}\"/ /etc/makepkg.conf
sed -i s/.*MAKEFLAGS=.*/MAKEFLAGS=\"-j`nproc`\"/ /etc/makepkg.conf
sed -i s/#BUILDDIR=/BUILDDIR=/ /etc/makepkg.conf
sed -i s/.*PKGEXT=.*/PKGEXT='.pkg.tar'/ /etc/makepkg.conf
" $AUR_BUILD_FLAGS

aur_cmd 'https://aur.archlinux.org/packages/rb/rbenv/rbenv.tar.gz' $RBENV
aur_cmd 'https://aur.archlinux.org/packages/ru/ruby-build/ruby-build.tar.gz' $RUBY_BUILD
aur_cmd 'https://aur.archlinux.org/packages/tt/ttf-ms-fonts/ttf-ms-fonts.tar.gz' $TTF_MS_FONTS
aur_cmd 'https://aur.archlinux.org/packages/at/atom-editor/atom-editor.tar.gz' $ATOM

chroot_cmd 'pacman & sudoer customization' "
cp /etc/pacman.conf /etc/pacman.conf.original
sed -i s/#Color/Color/ /etc/pacman.conf
echo '$USER ALL=NOPASSWD:/sbin/shutdown' >> /etc/sudoers.d/shutdown
echo '$USER ALL=NOPASSWD:/sbin/reboot' >> /etc/sudoers.d/shutdown
chmod 440 /etc/sudoers.d/shutdown
" $CUSTOMIZATION

chroot_cmd 'xwindows packages and applications' "
$PACMAN xorg-server xorg-server-utils xorg-xinit elementary-icon-theme xcursor-vanilla-dmz gnome-themes-standard ttf-ubuntu-font-family feh lxappearance rxvt-unicode pcmanfm suckless-tools xautolock conky
" $XWINDOWS

chroot_cmd 'root password' "echo -e '$ROOTPASS\n$ROOTPASS\n' passwd" $SET_ROOTPASS


#### $CHUSER SETUP ####

chuser_cmd 'create workspace' "mkdir -p $WORKSPACE" $XWINDOWS
chuser_cmd 'dwm' "cd $WORKSPACE && git clone $REPO/dwm.git && cd dwm && make clean install" $XWINDOWS

chuser_cmd 'clone and configure bin' "
git clone $REPO/bin.git
echo PASSWORD_DIR=$WORKSPACE/documents >> ~/.pwconfig
echo PASSWORD_FILE=.passwords.csv >> ~/.pwconfig
echo EDIT=vim >> ~/.pwconfig
" $BIN

chuser_cmd 'clone dotfiles' "
cd $WORKSPACE
git clone $REPO/dotfiles.git
cd dotfiles
bin/sync.sh
" $DOTFILES

chuser_cmd 'vim plugins and theme' "
mkdir -p ~/.vim/bundle
cd ~/.vim/bundle
git clone https://github.com/tpope/vim-pathogen.git
git clone https://github.com/tpope/vim-surround.git
git clone https://github.com/msanders/snipmate.vim.git
git clone https://github.com/scrooloose/nerdtree.git
git clone https://github.com/vim-ruby/vim-ruby.git
git clone https://github.com/tpope/vim-rails.git
git clone https://github.com/tpope/vim-rake.git
git clone https://github.com/tpope/vim-bundler.git
git clone https://github.com/tpope/vim-haml.git
git clone https://github.com/tpope/vim-git.git
git clone https://github.com/tpope/vim-fugitive.git
git clone https://github.com/tpope/vim-markdown.git
git clone https://github.com/tpope/vim-dispatch.git
git clone https://github.com/Keithbsmiley/rspec.vim.git
git clone https://github.com/mileszs/ack.vim.git
git clone https://github.com/bling/vim-airline.git
git clone https://github.com/kien/ctrlp.vim.git

cd ..
mkdir colors
cd colors
curl -O https://raw.githubusercontent.com/tomasr/molokai/master/colors/molokai.vim

vim -c 'Helptags | q'
" $VIM

chuser_cmd 'user password' "echo -e '$USERPASS\n$USERPASS\n' passwd" $SET_USERPASS

#### FINALISE ####

if [[ $FINALISE ]]; then
  umount -R /mnt
  reboot
fi
