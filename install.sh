#!/usr/bin/env bash

#### VERSION ####
echo 'Arch Install Script Version 0.2.26'
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
  [[ $INTEL ]] || INTEL=true
  [[ $BOOTLOADER ]] || BOOTLOADER=true
  [[ $UEFI ]] || UEFI=true
  [[ $NETWORK ]] || NETWORK=true
  [[ $ADD_USER ]] || ADD_USER=true
  [[ $STANDARD ]] || STANDARD=true
  [[ $IN_VM ]] || IN_VM=true
  [[ $AUR_FLAGS ]] || AUR_FLAGS=true
  [[ $RBENV ]] || RBENV=true
  [[ $RUBY_BUILD ]] || RUBY_BUILD=true
  [[ $CUSTOMIZATION ]] || CUSTOMIZATION=true
  [[ $XWINDOWS ]] || XWINDOWS=true
  [[ $INFINALITY ]] || INFINALITY=true
  [[ $ATOM ]] || ATOM=true
  [[ $SSH_KEY ]] || SSH_KEY=true
  [[ $CREATE_WORKSPACE ]] || CREATE_WORKSPACE=true
  [[ $DWM ]] || DWM=true
  [[ $BIN ]] || BIN=true
  [[ $DOTFILES ]] || DOTFILES=true
  [[ $VIM_CONFIG ]] || VIM_CONFIG=true
  [[ $SET_PASSWORD ]] || SET_PASSWORD=true
fi

# Setup some assumptions based on target machine
$(lspci | grep -q VirtualBox) || IN_VM=false
[[ $SERVER = true ]] && XWINDOWS=false UEFI=false INTEL=false
[[ $XWINDOWS = false ]] && ATOM=false IN_VM=false INFINALITY=false DWM=false
[[ $LAPTOP = true ]] && WIFI=true
[[ $DWM = true || $DOTFILES = true ]] && CREATE_WORKSPACE=true


#### FUNCTIONS ####

source <(curl -Ls https://projects.archlinux.org/arch-install-scripts.git/plain/common)

chroot_cmd () {
  title="$1"
  cmds="$2"
  run="$3"
  user="$4"

  if [[ $run = true ]]; then
    echo -e "\n\n\n\n\n########## $title ##########" >> $MNT_LOG
    echo -e $title
    echo -e "$cmds" | sed "s/$PASSWORD/*********/" >> $MNT_LOG

    if [[ $INSTALL != dryrun ]]; then
      LANG=C chroot /mnt su $user -c "$cmds" >> $MNT_LOG 2>&1
    fi
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
makepkg -cf --noprogressbar >> $LOG 2>&1
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
  sgdisk --new=1:0:512M --typecode=1:ef00 /dev/$DRIVE >> $TMP_LOG 2>&1
  mkfs.fat -F32 /dev/${DRIVE}1 >> $TMP_LOG 2>&1
  sgdisk --new=2:0:0 /dev/$DRIVE >> $TMP_LOG 2>&1
  mkfs.ext4 -F /dev/${DRIVE}2 >> $TMP_LOG 2>&1
  mount /dev/${DRIVE}2 /mnt
  mkdir -p /mnt/boot
  mount /dev/${DRIVE}1 /mnt/boot
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
mount_conditionally "[[ -d /mnt/sys/firmware/efi/efivars ]]" efivarfs "/mnt/sys/firmware/efi/efivars" -t efivarfs -o nosuid,noexec,nodev
chroot_cmd 'setup /dev/null' "[[ -c /dev/null ]] || mknod -m 777 /dev/null c 1 3" true

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

BOOTLOADER_PACKAGES='syslinux'

if [[ $INTEL = true ]]; then
  BOOTLOADER_PACKAGES="$BOOTLOADER_PACKAGES intel-ucode"
  INITRD='../intel-ucode.img ../initramfs-linux.img'
else
  INITRD='../initramfs-linux.img'
fi

if [[ $UEFI = true ]]; then
  BOOTLOADER_PACKAGES="$BOOTLOADER_PACKAGES efibootmgr"
  SYSLINUX_CONFIG='/boot/EFI/syslinux/syslinux.cfg'
  BOOTLOADER_EXTRA="mkdir -p /boot/EFI/syslinux
cp -r /usr/lib/syslinux/efi64/* /boot/EFI/syslinux
efibootmgr -c -l /EFI/syslinux/syslinux.efi -L Syslinux >> $LOG 2>&1
"
else
  BOOTLOADER_EXTRA=''
  SYSLINUX_CONFIG='/boot/syslinux/syslinux.cfg'
fi

chroot_cmd 'bootloader' "
$PACMAN $BOOTLOADER_PACKAGES >> $LOG 2>&1
eval $BOOTLOADER_EXTRA
echo \"PROMPT 0
TIMEOUT 50
DEFAULT arch

LABEL arch
  LINUX ../vmlinuz-linux
  APPEND root=/dev/${DRIVE}2 rw
  APPEND init=/usr/lib/systemd/systemd
  INITRD $INITRD

LABEL archfallback
  LINUX ../vmlinuz-linux
  APPEND root=/dev/${DRIVE}2 rw
  APPEND init=/usr/lib/systemd/systemd
  INITRD $INITRD\" > $SYSLINUX_CONFIG
" $BOOTLOADER

chroot_cmd 'network (inc ssh)' "
cp /etc/hosts /etc/hosts.original
echo $MACHINE > /etc/hostname
sed -i '/^127.0.0.1/ s/$/ $MACHINE/' /etc/hosts
nic_name=$(ls /sys/class/net | grep -vm 1 lo)
systemctl enable dhcpcd@\$nic_name >> $LOG 2>&1
$PACMAN openssh >> $LOG 2>&1
" $NETWORK

chroot_cmd 'wifi' "
$PACMAN wpa_supplicant wpa_actiond >> $LOG 2>&1
" $WIFI

chroot_cmd 'server packages' "
sed -i 's/#?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl enable sshd >> $LOG 2>&1

$PACMAN lm_sensors >> $LOG 2>&1
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
" $AUR_FLAGS

chroot_cmd 'pacman & sudoer customization' "
cp /etc/pacman.conf /etc/pacman.conf.original
sed -i s/#Color/Color/ /etc/pacman.conf
echo '$NEWUSER ALL=NOPASSWD:/sbin/shutdown' >> /etc/sudoers.d/shutdown
echo '$NEWUSER ALL=NOPASSWD:/sbin/reboot' >> /etc/sudoers.d/shutdown
chmod 440 /etc/sudoers.d/shutdown >> $LOG 2>&1
" $CUSTOMIZATION

chroot_cmd 'xwindows packages and applications' "
$PACMAN xorg-server xorg-server-utils xorg-xinit >> $LOG 2>&1
$PACMAN conky elementary-icon-theme feh gnome-themes-standard lxappearance pcmanfm >> $LOG 2>&1
$PACMAN rxvt-unicode slock xautolock xcursor-vanilla-dmz >> $LOG 2>&1
cd /etc/fonts/conf.d
ln -s ../conf.avail/10-sub-pixel-rgb.conf
" $XWINDOWS

chroot_cmd 'Infinality bundle fonts' "
echo '[infinality-bundle]
Server = http://bohoomil.com/repo/\$arch
[infinality-bundle-multilib]
Server = http://bohoomil.com/repo/multilib/\$arch
[infinality-bundle-fonts]
Server = http://bohoomil.com/repo/fonts' >> /etc/pacman.conf
pacman-key -r 962DDE58 >> $LOG 2>&1
pacman-key -f 962DDE58 >> $LOG 2>&1
pacman-key --lsign-key 962DDE58 >> $LOG 2>&1
pacman -Syy --noconfirm >> $LOG 2>&1
pacman -Rdd --noconfirm --noprogressbar ttf-dejavu
$PACMAN ibfonts-meta-base >> $LOG 2>&1
" $INFINALITY

chroot_cmd 'virtualbox guest' "
$PACMAN virtualbox-guest-utils virtualbox-guest-dkms >> $LOG 2>&1
echo vboxguest >> /etc/modules-load.d/virtualbox.conf
echo vboxsf >> /etc/modules-load.d/virtualbox.conf
echo vboxvideo >> /etc/modules-load.d/virtualbox.conf
systemctl enable vboxservice >> $LOG 2>&1
" $IN_VM


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

chuser_cmd 'create workspace' "
mkdir -p $WORKSPACE >> $LOG 2>&1
" $CREATE_WORKSPACE

chroot_cmd 'dependencies for Atom' "
$PACMAN --asdeps alsa-lib git gconf gtk2 libatomic_ops libgcrypt libgnome-keyring libnotify libxtst nodejs nss python2
" $ATOM

aur_cmd 'https://aur.archlinux.org/packages/rb/rbenv/rbenv.tar.gz' $RBENV
aur_cmd 'https://aur.archlinux.org/packages/ru/ruby-build/ruby-build.tar.gz' $RUBY_BUILD
aur_cmd 'https://aur.archlinux.org/packages/at/atom-editor/atom-editor.tar.gz' $ATOM

chuser_cmd 'dwm' "
sudo $PASSWORD | sudo -S $PACMAN libxinerama >> $LOG 2>&1
cd $WORKSPACE
git clone $PUBLIC_GIT/dwm.git >> $LOG 2>&1
cd dwm
echo $PASSWORD | sudo -S make clean install >> $LOG 2>&1
" $DWM

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
