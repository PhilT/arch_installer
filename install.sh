#!/usr/bin/env sh

# VARIABLES
USER=phil
WORKSPACE='~/ws'
PACMAN='pacman -S --noconfirm'
AUR='pacman -U --noconfirm'
CHROOT='arch-chroot /mnt /bin/bash -c'
CHUSER="arch-chroot /mnt /bin/su $USER -c"
REPO='git@github.com:PhilT'
LOG='/var/log/install.log'
USER_LOG='~/install.log'


# USER INPUT
echo 'Choose HOST [server|desktop|laptop]:'
read HOST

echo 'Choose passwords (Be careful, only asks once)'
echo 'for root:'
read -s ROOTPASS

echo 'for $USER:'
read -s USERPASS

echo 'Choose an option to begin installation'
echo 'base - base system only (does not reboot)'
echo 'full - complete install including reboot'
echo 'dryrun - dry run - echo all commands instead of executing them'
echo 'selected - selected options only - set ENV vars to install'
read INSTALL_TYPE

# OPTIONS
case $INSTALL_TYPE in
'base')
  BASE=true
  ;;
'full' | 'dryrun')
  BASE=true
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
*)
  echo "Invalid option: $INSTALL_TYPE"
  exit 1
esac

if [ $INSTALL_TYPE = 'dryrun' ]; then
  CHROOT="echo $CHROOT"
  CHUSER="echo $CHUSER"
fi

[[ $HOST != 'server' ]] && unset SWAPFILE
[[ `lspci | grep -q VirtualBox` ]] || unset VIRTUALBOX
[[ $HOST = 'server' ]] && unset XWINDOWS
[[ ! $XWINDOW ]] && unset ATOM && unset TTF_MS_FONTS

# FUNCTIONS
chroot_cmd () {
  if [ $1 ]; then
    echo $2 | tee -a $LOG
    echo '-------------------------------------------------------------------' >> $LOG
    echo -e "\n\n\n" >> $LOG
    $CHROOT $3
  fi
}

chuser_cmd () {
  if [ $1 ]; then
    echo $2 | tee -a $USER_LOG
    echo '-------------------------------------------------------------------' >> $USER_LOG
    echo -e "\n\n\n" >> $USER_LOG
    $CHUSER $3
  fi
}

aur_cmd () {
  name=`basename $2 .tar.gz`
  chroot_cmd $1 "install from aur: $name" "
cd /usr/local/src
curl -0 $2 | tar -zx >> $LOG
cd $name
makepkg -s >> $LOG
$AUR $name.pkg.tar
"
}

#################################################
# Base install

if [ $BASE ]; then
  echo 'keyboard'
  loadkeys uk

  echo 'filesystem'
  sgdisk --zap-all /dev/sda

# Line breaks are significant
  fdisk /dev/sda << EOF
n




w
EOF > /dev/null
  mkfs.ext4 /dev/sda1 > /dev/null
  mount /dev/sda1 /mnt > /dev/null

  echo 'arch linux base' | tee -a $LOG
  pacstrap /mnt base > /dev/null
  genfstab -p /mnt >> /mnt/etc/fstab
fi

#######################################
# root setup ($CHROOT)

chroot_cmd $LOCALE 'time, locale, keyboard' "
ln -s /usr/share/zoneinfo/GB /etc/localtime >> $LOG
echo en_GB.UTF-8 UTF-8 >> /etc/locale.gen
locale-gen >> $LOG
$PACMAN ntp >> $LOG
systemctl enable ntpd.service >> $LOG
ntpd -qg >> $LOG
hwclock --systohc >> $LOG
echo KEYMAP=\"uk\" >> /etc/vconsole.conf
"

chroot_cmd $SWAPFILE 'swap file' "
fallocate -l 512M /swapfile >> $LOG
chmod 600 /swapfile >> $LOG
mkswap /swapfile >> $LOG
echo /swapfile none swap defaults 0 0 >> /etc/fstab
"

chroot_cmd $BOOTLOADER 'bootloader' "
$PACMAN grub >> $LOG
grub-install --target=i386-pc --recheck /dev/sda >> $LOG
grub-mkconfig -o /boot/grub/grub.cfg >> $LOG
"

chroot_cmd $NETWORK 'network (inc sshd)' "
cp /etc/hosts /etc/hosts.original
echo $HOST > /etc/hostname
echo 127.0.0.1 localhost.localdomain localhost $HOST > /etc/hosts
echo ::1       localhost.localdomain localhost >> /etc/hosts
systemctl enable dhcpcd@enp0s3.service >> $LOG
$PACMAN openssh >> $LOG
"

chroot_cmd $ADD_USER 'user' "
useradd -m -G wheel -s /bin/bash $USER >> $LOG
echo $USER ALL=(ALL) ALL >> /etc/sudoers.d/general
"

chroot_cmd $STANDARD 'standard packages' "$PACMAN base-devel git vim >> $LOG"

chroot_cmd $VIRTUALBOX 'virtualbox guest' "
$PACMAN virtualbox-guest-utils virtualbox-guest-dkms >> $LOG
echo vboxguest >> /etc/modules-load.d/virtualbox.conf
echo vboxsf >> /etc/modules-load.d/virtualbox.conf
echo vboxvideo >> /etc/modules-load.d/virtualbox.conf
systemctl enable vboxservice.service >> $LOG
"

# Setup for specific architecture and improve build times
chroot_cmd $AUR_BUILD_FLAGS 'aur build flags' "
cp /etc/makepkg.conf /etc/makepkg.conf.original
sed -i s/CFLAGS=.*/CFLAGS=\"-march=native -O2 -pipe -fstack-protector --param=ssp-buffer-size=4\"/ /etc/makepkg.conf
sed -i s/CXXFLAGS=.*/CXXFLAGS=\"\${CFLAGS}\"/ /etc/makepkg.conf
sed -i s/.*MAKEFLAGS=.*/MAKEFLAGS=\"-j`nproc`\"/ /etc/makepkg.conf
sed -i s/#BUILDDIR=/BUILDDIR=/ /etc/makepkg.conf
sed -i s/.*PKGEXT=.*/PKGEXT='.pkg.tar'/ /etc/makepkg.conf
"

aur_cmd $RBENV 'https://aur.archlinux.org/packages/rb/rbenv/rbenv.tar.gz'
aur_cmd $RUBY_BUILD 'https://aur.archlinux.org/packages/ru/ruby-build/ruby-build.tar.gz'
aur_cmd $TTF_MS_FONTS 'https://aur.archlinux.org/packages/tt/ttf-ms-fonts/ttf-ms-fonts.tar.gz'
aur_cmd $ATOM 'https://aur.archlinux.org/packages/at/atom-editor/atom-editor.tar.gz'

chroot_cmd $CUSTOMIZATION 'pacman & sudoer customization' "
cp /etc/pacman.conf /etc/pacman.conf.original
sed -i s/#Color/Color/ /etc/pacman.conf
echo '$USER ALL=NOPASSWD:/sbin/shutdown' >> /etc/sudoers.d/shutdown
echo '$USER ALL=NOPASSWD:/sbin/reboot' >> /etc/sudoers.d/shutdown
chmod 440 /etc/sudoers.d/shutdown >> $LOG
"

chroot_cmd $XWINDOWS 'xwindows packages and applications' "
$PACMAN xorg-server xorg-server-utils xorg-xinit elementary-icon-theme xcursor-vanilla-dmz gnome-themes-standard ttf-ubuntu-font-family feh lxappearance rxvt-unicode pcmanfm suckless-tools xautolock conky >> $LOG
"

chroot_cmd $SET_ROOTPASS 'root password' "echo -e '$ROOTPASS\n$ROOTPASS\n' passwd >> $LOG"


#######################################
# user setup ($CHUSER)

chuser_cmd $XWINDOWS 'create workspace' "mkdir -p $WORKSPACE >> $USER_LOG"
chuser_cmd $XWINDOWS 'dwm' "cd $WORKSPACE && git clone $REPO/dwm.git >> $USER_LOG && cd dwm && make clean install >> $USER_LOG"

chuser_cmd $BIN 'clone and configure bin' "
git clone $REPO/bin.git >> $USER_LOG
echo PASSWORD_DIR=$WORKSPACE/documents >> ~/.pwconfig
echo PASSWORD_FILE=.passwords.csv >> ~/.pwconfig
echo EDIT=vim >> ~/.pwconfig
"

chuser_cmd $DOTFILES 'clone dotfiles' "
cd $WORKSPACE
git clone $REPO/dotfiles.git >> $USER_LOG
cd dotfiles
bin/sync.sh >> $USER_LOG
"

chuser_cmd $VIM 'vim plugins and theme' "
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
"

chuser_cmd $SET_USERPASS 'user password' "echo -e '$USERPASS\n$USERPASS\n' passwd >> $USER_LOG"

# FINALISE
umount -R /mnt
reboot
