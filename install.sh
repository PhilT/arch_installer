#!/usr/bin/env sh

# VARIABLES
USER=phil
WORKSPACE='~/workspace'
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
  ;;
'full')
'dryrun')
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
  TTF_MS_FONTS=true
  CUSTOMIZATION=true
  XWINDOWS=true
  SET_ROOTPASS=true
  BIN=true
  DOTFILES=true
  SET_USERPASS=true
  ;;
'selected')
  ;;
esac

if [ $INSTALL_TYPE = 'dryrun' ]; then
  CHROOT="echo $CHROOT"
  CHUSER="echo $CHUSER"
fi


[[ $HOST = 'server' ]] || SWAPFILE=false
[[ lspci | grep -q VirtualBox ]] || VIRTUALBOX=false
[[ $HOST != 'server' ]] || XWINDOWS=false

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

install_from_aur () {
  chroot_cmd $1 "install from aur: $2" "
cd /usr/local/src
curl -0 $3 | tar -zx >> $LOG
cd $2
makepkg -s >> $LOG
$AUR $2.pkg.tar
"
}

#################################################

echo 'keyboard'
loadkeys uk

echo 'filesystem (Line breaks are significant)'
sgdisk --zap-all /dev/sda
fdisk /dev/sda << EOF
n




w
EOF > /dev/null
mkfs.ext4 /dev/sda1 > /dev/null
mount /dev/sda1 /mnt > /dev/null

echo 'arch linux base' | tee -a $LOG
pacstrap /mnt base > /dev/null
genfstab -p /mnt >> /mnt/etc/fstab


if [ $INSTALL_TYPE = '1' ]; then
  echo 'Install base system only (option 1 selected)'
  exit
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

# Build for specific architecture and improve build times
chroot_cmd $AUR_BUILD_FLAGS 'aur build flags' "
cp /etc/makepkg.conf /etc/makepkg.conf.original
sed -i s/CFLAGS=.*/CFLAGS=\"-march=native -O2 -pipe -fstack-protector --param=ssp-buffer-size=4\"/ /etc/makepkg.conf
sed -i s/CXXFLAGS=.*/CXXFLAGS=\"\${CFLAGS}\"/ /etc/makepkg.conf
sed -i s/.*MAKEFLAGS=.*/MAKEFLAGS=\"-j`nproc`\"/ /etc/makepkg.conf
sed -i s/#BUILDDIR=/BUILDDIR=/ /etc/makepkg.conf
sed -i s/.*PKGEXT=.*/PKGEXT='.pkg.tar'/ /etc/makepkg.conf
"

aur_cmd $RBENV 'rbenv' 'https://aur.archlinux.org/packages/rb/rbenv/rbenv.tar.gz'
aur_cmd $RUBY_BUILD 'ruby-build' 'https://aur.archlinux.org/packages/ru/ruby-build/ruby-build.tar.gz'
aur_cmd $TTF_MS_FONTS 'ttf-ms-fonts' 'https://aur.archlinux.org/packages/tt/ttf-ms-fonts/ttf-ms-fonts.tar.gz'

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

chuser_cmd $SET_USERPASS 'user password' "echo -e '$USERPASS\n$USERPASS\n' passwd >> $USER_LOG"

# FINALISE
umount -R /mnt
reboot
