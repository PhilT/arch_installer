# Install and Configure Arch Linux

A script to install and configure Arch Linux for server, desktop or laptop. This is
executable documentation for my setup and probably requires modifying for your needs. It also
serves as a useful reference for how to setup a basic Arch Linux system. Fork for your pleasure.

It's got a few assumptions:

* WARNING - Existing partitions will be deleted
* GPT is the default partition type
* syslinux is the default bootloader
* UEFI is enabled by default (`UEFI=false` to disable)
* `phil` (me!) is the default user
* `ws` is the default ~/workspace
* Single partition and swap file (plus UEFI partition)
* You may not want all the VIM plugins I've installed
* X is installed except when `MACHINE=server`
* VirtualBox guest utils installed when running on a VM
* Packages such as pcmanfm, urxvt, feh, xautolock are installed
* English Language and UK keyboard, UK mirrorlist
* Makepkg will fail if dependencies are not previously installed (as it needs sudo and
  will ask for a password)

Everything is installed via chroot so no reboot is done until the end (and it's
an optional step should you prefer to check the installation before booting into
Arch for the first time).


## Motives

* I like to have executable, repeatable documentation of everything I do
* I'm always (re)installing new or old machines and tinkering (read: breaking)
* I like to have a setup I can replicate across my machines
* I find it's a great way to learn


## Usage

I need SSH keys for access to my github and bitbucket repos. For testing I have a Windows host
and VirtualBox VM guest.

Boot an Arch Linux Live CD (https://www.archlinux.org/download/) and run the following commands:

    systemctl start sshd
    passwd
    ip a

On the host, copy over the SSH keys to be used for the machine (I use the host ones for testing):

    scp ~/.ssh/id_rsa* root@ipaddress:~

then ssh into the ip address shown and run install.sh (http://goo.gl/tKEBG9 points to my github
repo) which will ask you for a hostname and password (used for root and your user):

    ssh root@ipaddress
    INSTALL=all bash <(curl -Ls http://goo.gl/tKEBG9)

I do it this way round as I don't always have sshd available on the host (Windows machine). Also,
SSHing into the guest to run the install gives you scrollback on the host (and it's easier to
copy the command to run or rerun it).

Non-interactive install (handy for testing):

    MACHINE=server PASSWORD=password INSTALL=dryrun bash <(curl -Ls http://goo.gl/tKEBG9)

Instead of installing everything omit INSTALL and specify what you want:

    MACHINE=server RBENV=true bash <(curl -Ls http://goo.gl/tKEBG9)

Install everything except the Vim config:

    MACHINE=desktop INSTALL=all VIM_CONFIG=false bash <(curl -Ls http://goo.gl/tKEBG9)

`MACHINE=server` sets some things like no XWINDOWS and no UEFI. Any other name just sets it as
the host name.

If you mess something up and need to rerun the installation, simply unmount the drive and
rerun the install. The existing partition will be removed. The bootloader will get upset,
however, so once you're done testing it's best to start from scratch:

    umount -R /mnt
    MACHINE=server bash <(curl -Ls http://goo.gl/tKEBG9)

Take a look at the script for all the options and variables.


## Notes

System-wide configuration files that will be modified by this script are first copied to a
file with the extension .original (e.g. /etc/pacman.conf.original).

The only user input is the password taken at the start to ensure the installation can complete
unattended. Both root and user are set with the same password (you may want to change this).

All other options are specified as env variables.

* `MACHINE` - specify the hostname (and sets some options). Prompts if not specified
* `PASSWORD` - Insecure but handy for testing (prompts if not specified)
* `INSTALL` -  `all` - everything except `REBOOT`
               `dryrun` - does not execute commands (only logs)
* `LAPTOP`  - Set extra options such as `$WIFI`
* `REBOOT=` - `true` if you wish to unmount and reboot at the end
* `OPTION=` - `false` to turn off options

Before partition creation all commands and output is sent to `/tmp/install.log`. Once the
partition is mounted the log file is moved to `/mnt/home/user/install.log`. On a `dryrun`
logging is simply sent to the `~/install.log`.

While running the install script open another terminal and ssh in then tail both files.
Change `phil` to what you specified for `NEWUSER`:

    tail -f /tmp/install.log /mnt/home/phil/install.log

Or afterwards:

    less /mnt/home/phil/install.log


## Development

This downloads and runs install.sh on the `dev` branch:

    bash <(curl -Ls http://goo.gl/1vmj59)

Login with chroot (after installation but before reboot). Useful for further testing:

    arch-chroot /mnt su [username]

Specify username if you want to login as a user instead of root.


## References

Basically all of https://wiki.archlinux.org! It's an amazing resource!

* https://wiki.archlinux.org/index.php/Installation_Guide
* https://wiki.archlinux.org/index.php/Beginners'_Guide
* https://www.archlinux.org/mirrorlist/
* install.txt (from booted live CD)
