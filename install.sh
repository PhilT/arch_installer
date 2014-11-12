#!/usr/bin/env bash

#### VERSION ####
echo 'Arch Install Script Version 0.3.3'
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
LOG='install.log'
MNT_LOG=$LOG

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

print_title () {
  echo -e "\n\n\n\n\n########## $1 ##########" >> $MNT_LOG
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
    print_title "$title"
    echo "$cmds" | sed "s/$PASSWORD/*********/" >> $MNT_LOG

    if [[ $INSTALL != dryrun ]]; then
      LANG=C chroot /mnt su $user -c "$cmds" >> $MNT_LOG 2>&1
    fi
  fi
}

chroot_cmd () {
  run="$1"; shift
  title="$1"; shift
  ch_cmd "$run" "$title" 'root' $@
}

chuser_cmd () {
  run="$1"; shift
  title="$1"; shift
  ch_cmd "$run" "$title" "$NEWUSER" $@
}

# Move to dotfiles
aur_cmd () {
  run=$1
  url=$2

  name=`basename $url .tar.gz`
  chuser_cmd $run "$name build" \
    "mkdir -p ~/packages" \
    "cd ~/packages" \
    "curl -s $url | tar -zx" \
    "cd $name" \
    "makepkg -cf --noprogressbar" \


  chroot_cmd $run "$name install" \
    "$AUR /tmp/$name*.pkg.tar"
}


#### BASE INSTALL ####

if [[ $BASE = true && $INSTALL != dryrun ]]; then
  print_title "\n\nstarting installation\n-------------------------------"

  print_title 'keyboard'
  loadkeys uk

  print_title 'filesystem'
  partprobe /dev/$DRIVE
  sgdisk --zap-all /dev/$DRIVE >> $MNT_LOG 2>&1
  sgdisk --new=1:0:512M --typecode=1:ef00 /dev/$DRIVE >> $MNT_LOG 2>&1
  mkfs.fat -F32 /dev/${DRIVE}1 >> $MNT_LOG 2>&1
  sgdisk --new=2:0:0 /dev/$DRIVE >> $MNT_LOG 2>&1
  mkfs.ext4 -F /dev/${DRIVE}2 >> $MNT_LOG 2>&1
  mount /dev/${DRIVE}2 /mnt
  mkdir -p /mnt/boot
  mount /dev/${DRIVE}1 /mnt/boot
  partprobe /dev/$DRIVE

  print_title 'log file'
  TMP_LOG=$LOG
  LOG="/home/$NEWUSER/install.log"
  MNT_LOG="/mnt$LOG"
  mkdir -p $(dirname $MNT_LOG)
  mv $TMP_LOG $MNT_LOG

  print_title 'arch linux base'
  mkdir -p /mnt/etc/pacman.d
  cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist.original
  URL="https://www.archlinux.org/mirrorlist/?country=GB&protocol=http&ip_version=4&use_mirror_status=on"
  curl -s $URL | sed 's/^#Server/Server/' > /etc/pacman.d/mirrorlist
  pacman -Syy >> $MNT_LOG 2>&1 # Refresh package lists
  pacstrap /mnt base >> $MNT_LOG 2>&1

  print_title 'fstab'
  genfstab -U -p /mnt >> /mnt/etc/fstab
  cat /mnt/etc/fstab >> $MNT_LOG 2>&1
fi


#### MOUNTS FOR CHROOT ####

print_title 'chroot mounts'
api_fs_mount /mnt || echo 'api_fs_mount failed' >> $MNT_LOG 2>&1
track_mount /etc/resolv.conf /mnt/etc/resolv.conf --bind >> $MNT_LOG 2>&1
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
  "echo KEYMAP=\"uk\" | tee /etc/vconsole.conf" \

chroot_cmd $SWAPFILE 'swap file' \
  "fallocate -l 512M /swapfile" \
  "chmod 600 /swapfile" \
  "mkswap /swapfile" \
  "echo /swapfile none swap defaults 0 0 | tee -a /etc/fstab"


BOOTLOADER_PACKAGES='syslinux'

if [[ $INTEL = true ]]; then
  BOOTLOADER_PACKAGES="$BOOTLOADER_PACKAGES intel-ucode"
  INITRD='../../intel-ucode.img ../../initramfs-linux.img'
else
  INITRD='../../initramfs-linux.img'
fi

if [[ $UEFI = true ]]; then
  BOOTLOADER_PACKAGES="$BOOTLOADER_PACKAGES efibootmgr"
  SYSLINUX_CONFIG='/boot/EFI/syslinux/syslinux.cfg'
  BOOTLOADER_EXTRA="mkdir -p /boot/EFI/syslinux
cp -r /usr/lib/syslinux/efi64/* /boot/EFI/syslinux
efibootmgr -c -l /EFI/syslinux/syslinux.efi -L Syslinux
"
else
  BOOTLOADER_EXTRA=''
  SYSLINUX_CONFIG='/boot/syslinux/syslinux.cfg'
fi

chroot_cmd $BOOTLOADER 'bootloader' \
  "$PACMAN $BOOTLOADER_PACKAGES" \
  "$BOOTLOADER_EXTRA" \
  "echo \"PROMPT 0
TIMEOUT 50
DEFAULT arch

LABEL arch
  LINUX ../../vmlinuz-linux
  APPEND root=/dev/${DRIVE}2 rw
  APPEND init=/usr/lib/systemd/systemd
  INITRD $INITRD

LABEL archfallback
  LINUX ../../vmlinuz-linux
  APPEND root=/dev/${DRIVE}2 rw
  APPEND init=/usr/lib/systemd/systemd
  INITRD $INITRD\" | tee $SYSLINUX_CONFIG"

chroot_cmd $NETWORK 'network (inc ssh)' \
  "cp /etc/hosts /etc/hosts.original" \
  "echo $MACHINE | tee /etc/hostname" \
  "sed -i '/^127.0.0.1/ s/$/ $MACHINE/' /etc/hosts" \
  "nic_name=$(ls /sys/class/net | grep -vm 1 lo)" \
  "systemctl enable dhcpcd@\$nic_name" \
  "$PACMAN openssh" \

chroot_cmd $WIFI 'wifi' "$PACMAN wpa_supplicant wpa_actiond"

chroot_cmd $SERVER 'server packages' \
  "sed -i 's/#?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config" \
  "systemctl enable sshd" \
  "$PACMAN lm_sensors" \
  "sensors-detect --auto"

chroot_cmd $STANDARD 'standard packages' "$PACMAN base-devel git vim unison dialog"

chroot_cmd $ADD_USER 'user' \
  "useradd -G wheel -s /bin/bash $NEWUSER" \
  "echo \"$NEWUSER ALL=(ALL) ALL\" | tee -a /etc/sudoers.d/general" \
  "chmod 440 /etc/sudoers.d/general" \
  "chown phil:phil /home/$NEWUSER"

chroot_cmd $SET_PASSWORD 'root password' "echo -e '$PASSWORD\n$PASSWORD\n' | passwd"
chroot_cmd $SET_PASSWORD 'user password' "echo -e '$PASSWORD\n$PASSWORD\n' | passwd $NEWUSER"

# optimised for specific architecture and build times
chroot_cmd $AUR_FLAGS 'build flags (AUR)' \
  "cp /etc/makepkg.conf /etc/makepkg.conf.original" \
  "sed -i 's/CFLAGS=.*/CFLAGS=\"-march=native -O2 -pipe -fstack-protector-strong --param=ssp-buffer-size=4\"/' /etc/makepkg.conf" \
  "sed -i 's/CXXFLAGS=.*/CXXFLAGS=\"\${CFLAGS}\"/' /etc/makepkg.conf" \
  "sed -i 's/.*MAKEFLAGS=.*/MAKEFLAGS=\"-j`nproc`\"/' /etc/makepkg.conf" \
  "sed -i s/#BUILDDIR=/BUILDDIR=/ /etc/makepkg.conf" \
  "sed -i 's/#PKGDEST=.*/PKGDEST=\/tmp/' /etc/makepkg.conf" \
  "sed -i s/.*PKGEXT=.*/PKGEXT='.pkg.tar'/ /etc/makepkg.conf"

chroot_cmd $CUSTOMIZATION 'pacman & sudoer customization' \
  "cp /etc/pacman.conf /etc/pacman.conf.original" \
  "sed -i s/#Color/Color/ /etc/pacman.conf" \
  "echo '$NEWUSER ALL=NOPASSWD:/sbin/shutdown' | tee -a /etc/sudoers.d/shutdown" \
  "echo '$NEWUSER ALL=NOPASSWD:/sbin/reboot' | tee -a /etc/sudoers.d/shutdown" \
  "chmod 440 /etc/sudoers.d/shutdown"

chroot_cmd $XWINDOWS 'xwindows packages and applications' \
  "$PACMAN xorg-server xorg-server-utils xorg-xinit" \
  "$PACMAN conky elementary-icon-theme feh gnome-themes-standard lxappearance pcmanfm" \
  "$PACMAN rxvt-unicode slock xautolock xcursor-vanilla-dmz" \
  "cd /etc/fonts/conf.d" \
  "ln -s ../conf.avail/10-sub-pixel-rgb.conf"

chroot_cmd $INFINALITY 'Infinality bundle fonts' \
  "echo -e '[infinality-bundle]\nServer = http://bohoomil.com/repo/\$arch' | tee -a /etc/pacman.conf" \
  "echo -e '[infinality-bundle-multilib]\nServer = http://bohoomil.com/repo/multilib/\$arch' | tee -a /etc/pacman.conf" \
  "echo -e '[infinality-bundle-fonts]\nServer = http://bohoomil.com/repo/fonts' | tee -a /etc/pacman.conf" \
  "pacman-key -r 962DDE58" \
  "pacman-key -f 962DDE58" \
  "pacman-key --lsign-key 962DDE58" \
  "pacman -Syy --noconfirm" \
  "pacman -Rdd --noconfirm --noprogressbar ttf-dejavu" \
  "$PACMAN ibfonts-meta-base"

chroot_cmd $IN_VM 'virtualbox guest' \
  "$PACMAN virtualbox-guest-utils virtualbox-guest-dkms" \
  "echo vboxguest | tee -a /etc/modules-load.d/virtualbox.conf" \
  "echo vboxsf | tee -a /etc/modules-load.d/virtualbox.conf" \
  "echo vboxvideo | tee -a /etc/modules-load.d/virtualbox.conf" \
  "systemctl enable vboxservice"


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
  "ssh-keyscan -H github.com > ~/.ssh/known_hosts"

chuser_cmd $CREATE_WORKSPACE 'workspace' "mkdir -p $WORKSPACE"

chroot_cmd $ATOM 'dependencies for Atom' \
  "$PACMAN --asdeps alsa-lib git gconf gtk2 libatomic_ops libgcrypt libgnome-keyring libnotify libxtst nodejs nss python2"

aur_cmd $RBENV 'https://aur.archlinux.org/packages/rb/rbenv/rbenv.tar.gz'
aur_cmd $RUBY_BUILD 'https://aur.archlinux.org/packages/ru/ruby-build/ruby-build.tar.gz'
aur_cmd $ATOM 'https://aur.archlinux.org/packages/at/atom-editor/atom-editor.tar.gz'

chuser_cmd $DWM 'dwm' \
  "sudo $PASSWORD | sudo -S $PACMAN libxinerama" \
  "cd $WORKSPACE" \
  "git clone $PUBLIC_GIT/dwm.git" \
  "cd dwm" \
  "echo $PASSWORD | sudo -S make clean install"

chuser_cmd $BIN '~/bin' \
  "cd ~" \
  "git clone $PUBLIC_GIT/bin.git" \
  "echo PASSWORD_DIR=$WORKSPACE/documents | tee -a ~/.pwconfig" \
  "echo PASSWORD_FILE=.passwords.csv | tee -a ~/.pwconfig" \
  "echo EDIT=vim | tee -a ~/.pwconfig"

chuser_cmd $DOTFILES 'dotfiles' \
  "cd $WORKSPACE" \
  "git clone $PUBLIC_GIT/dotfiles.git" \
  "cd dotfiles" \
  "bin/sync.sh"


chuser_cmd $VIM_CONFIG 'vim plugins and theme' \
  "mkdir -p ~/.vim/bundle" \
  "cd ~/.vim/bundle" \
  "git clone https://github.com/tpope/vim-pathogen.git" \
  "git clone https://github.com/tpope/vim-surround.git" \
  "git clone https://github.com/msanders/snipmate.vim.git" \
  "git clone https://github.com/scrooloose/nerdtree.git" \
  "git clone https://github.com/vim-ruby/vim-ruby.git" \
  "git clone https://github.com/tpope/vim-rails.git" \
  "git clone https://github.com/tpope/vim-rake.git" \
  "git clone https://github.com/tpope/vim-bundler.git" \
  "git clone https://github.com/slim-template/vim-slim.git" \
  "git clone https://github.com/tpope/vim-git.git" \
  "git clone https://github.com/tpope/vim-fugitive.git" \
  "git clone https://github.com/tpope/vim-markdown.git" \
  "git clone https://github.com/tpope/vim-dispatch.git" \
  "git clone https://github.com/Keithbsmiley/rspec.vim.git" \
  "git clone https://github.com/mileszs/ack.vim.git" \
  "git clone https://github.com/bling/vim-airline.git" \
  "git clone https://github.com/kien/ctrlp.vim.git" \
  "mkdir -p ~/.vim/colors" \
  "cd ~/.vim/colors" \
  "curl -s -O https://raw.githubusercontent.com/tomasr/molokai/master/colors/molokai.vim" \
  "vim -c 'Helptags | q'"


#### REBOOT ####

if [[ $REBOOT = true ]]; then
  echo 'rebooting...'
  umount -R /mnt && reboot
fi


#### DONE ####

print_title 'finished'
