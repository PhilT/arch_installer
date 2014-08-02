# Install and Configure Arch Linux

Simple script to install and configure Arch Linux. Fork for your needs.

## Assumptions

* Drive to install to is assumed to be `sda`
* Single network card (name is detected)



## Usage

Boot an Arch Linux Live CD and run the following commands:

    systemctl start sshd
    passwd
    ip a

copy over the SSH keys to be used for the machine:

    scp .ssh/id_rsa* root@ipaddress:~

then ssh into the ip address shown and run the bash-curl line which will ask you for a hostname and password (used for root and your user):

    ssh root@ipaddress
    INSTALL=all bash <(curl -Ls http://goo.gl/tKEBG9)

Non-interactive install (handy for testing):

    MACHINE=server PASSWORD=password INSTALL=dryrun bash <(curl -Ls http://goo.gl/tKEBG9)

Instead of installing everything omit INSTALL and specify what you want:

    MACHINE=server RBENV=true bash <(curl -Ls http://goo.gl/tKEBG9)

Take a look at the script for all the options.


## Notes

System-wide configuration files that will be modified by this script are first copied to a file with the extension .original (e.g. /etc/pacman.conf.original).

The file system is setup with a single partition and swap file.

The only user input is the password taken at the start to ensure the installation can complete unattended.

All other options are specified as env variables.

* `MACHINE` - specify the hostname (and sets some options). Prompts if not specified
* `PASSWORD` - Insecure but handy for testing (prompts if not specified)
* `INSTALL` -  `all` - everything except `REBOOT`
               `dryrun` - does not execute commands (only logs)
* `REBOOT=` - `true` if you wish to unmount and reboot at the end
* `OPTION=` - `false` to turn off options

Before partition creation all commands and output is sent to `/tmp/install.log`. Once the partition is mounted the log file is moved to `/mnt/home/user/install.log`. On a `dryrun` logging is simply sent to the `~/install.log`.


## Development

This downloads and runs install.sh on the `dev` branch:

    bash <(curl -Ls https://raw.githubusercontent.com/PhilT/arch_installer/dev/install.sh)



## References

Basically all of https://wiki.archlinux.org! It's an amazing resource!

* https://wiki.archlinux.org/index.php/Installation_Guide
* https://wiki.archlinux.org/index.php/Beginners'_Guide
* https://www.archlinux.org/mirrorlist/
* install.txt (from booted live CD)
