# Install and Configure Arch Linux

A simple script to install and configure Arch Linux for server, desktop or laptop.
Fork for your pleasure.

It's got a few assumptions:

* UEFI is default boot type
* Single partition and swap file



## Usage

I need SSH keys for access to my github and bitbucket repos. For testing I have a Windows host
and VirtualBox VM guest.

Boot an Arch Linux Live CD (https://www.archlinux.org/download/) and run the following commands:

    systemctl start sshd
    passwd
    ip a

On the host, copy over the SSH keys to be used for the machine (I use the host ones for testing):

    scp ~/.ssh/id_rsa* root@ipaddress:~

then ssh into the ip address shown and run install.sh which will ask you for a hostname and
password (used for root and your user):

    ssh root@ipaddress
    INSTALL=all bash <(curl -Ls http://goo.gl/tKEBG9)

I do it this way round as I don't always have sshd available on the host (Windows machine). Also,
SSHing into the guest to run the install gives you scrollback on the host (and it's easier to
copy the command to run or rerun it).

Non-interactive install (handy for testing):

    MACHINE=server PASSWORD=password INSTALL=dryrun bash <(curl -Ls http://goo.gl/tKEBG9)

Instead of installing everything omit INSTALL and specify what you want:

    MACHINE=server RBENV=true bash <(curl -Ls http://goo.gl/tKEBG9)

`MACHINE=server` sets some things like no XWINDOWS and no UEFI. Any other name just sets it as
the host name. Take a look at the script for all the options and variables.

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
* `REBOOT=` - `true` if you wish to unmount and reboot at the end
* `OPTION=` - `false` to turn off options

Before partition creation all commands and output is sent to `/tmp/install.log`. Once the
partition is mounted the log file is moved to `/mnt/home/user/install.log`. On a `dryrun`
logging is simply sent to the `~/install.log`.


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
