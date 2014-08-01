# Install and Configure Arch Linux

Simple script to install and configure Arch Linux.

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

then ssh into the ip address shown and run the bash-curl line:

    ssh root@ipaddress
    bash <(curl -Ls http://goo.gl/tKEBG9)


you can preset all options for non-interactive (note passwords are insecure but useful for testing):

    MACHINE=server USERPASS=password INSTALL=all REBOOT=true bash <(curl -Ls http://goo.gl/tKEBG9)



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

The only user input is the password taken at the start to ensure the installation can complete unattended.

All other options are specified as env variables.

* `MACHINE` - specify 'server' to ensure X and anything that depends on X is not installed
* `USERPASS` - Insecure but handy for testing (prompts when none already specified)
* `INSTALL` -  `all` - selects all options except for `REBOOT`
               `dryrun` - selects  all options but echos commands to log files instead of executing
* `REBOOT=` - `true` if you wish to unmount and reboot once the installation is complete
* `OPTION=` - `false` to turn off options

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
