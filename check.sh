DIFF="diff --changed-group-format='%>' --unchanged-group-format=''"


#LOCALE=true
cat /etc/vconsole.conf
ps ax | grep -i ntp

#SWAPFILE=true
swapon -s

#NETWORK=true
cat /etc/hostname
cat /etc/hosts
ps ax | grep -i ssh


#ADD_USER=true
# Can I log in?

#STANDARD=true
autoconf --version
git --version
vim --version

#VIRTUALBOX=true
ps ax | grep -i vbox

#AUR_BUILD_FLAGS=true
cat /etc/makepkg.conf

#RBENV=true
#RUBY_BUILD=true
rbenv install -l | grep 2.1.2

#TTF_MS_FONTS=true
pacman -Qm ttf-ms-fonts

#CUSTOMIZATION=true
$DIFF /etc/pacman.conf.original /etc/pacman.conf

#XWINDOWS=true
feh --version


#SET_ROOTPASS=true

#BIN=true
ls ~/bin
cat ~/.pwconfig

#DOTFILES=true
ls -la ~/.*

#SET_USERPASS=true

