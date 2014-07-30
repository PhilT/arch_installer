# Install and Configure Arch Linux

Simple script to install and configure Arch Linux.


## Usage

Boot an Arch Linux Live CD and run the following commands:

    systemctl start sshd
    passwd
    ip a

copy over the SSH keys to be used for the machine:

    scp .ssh/id_rsa* root@ipaddress:~

then ssh into the ip address shown and run the bash-curl line:

    ssh root@ipaddress
    bash <(curl -Ls http://goo.gl/tKEBG9)



## Configurations


Detects if using VirtualBox and X and installs guest additions.

### server

Physical machine, currently a VIA C7 1.0Ghz with 1GB RAM.


### desktop

VirtualBox VM 10GB RAM

* Installs X and DWM

### laptop

VirtualBox VM 4GB RAM

* Installs X and DWM


## Notes

System-wide configuration files that will be modified by this script are first copied to a file with the extension .original (e.g. /etc/pacman.conf.original).

The file system is setup with a single partition and swap file.

All user input is taken at the start to ensure the installation can complete unattended. Options can be specified as env variables to avoid all interaction. HOST, USERPASS and INSTALL_TYPE can all be set along with all options (see install.sh for available options). Specify REBOOT=true if you wish to umount and reboot once the installation is complete. When specifying full or dryrun INSTALL_TYPE options can be turned off with OPTION=false.

There are 3 log files generated on installation.

* /var/log/install.log - Initial partition creation and formatting
* /mnt/var/log/install.log - For root commands once partition is available
* /mnt/home/user/install.log - Non root commands


## Development

This downloads and runs install.sh on the `dev` branch:

    bash <(curl -Ls https://raw.githubusercontent.com/PhilT/arch_installer/dev/install.sh)



## References

* https://wiki.archlinux.org/index.php/Installation_Guide
* https://wiki.archlinux.org/index.php/Beginners'_Guide
* https://www.archlinux.org/mirrorlist/
* install.txt (from booted live CD)
