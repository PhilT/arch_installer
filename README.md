# Install and Configure Arch Linux

Simple script to install and configure Arch Linux.


## Usage

Boot an Arch Linux Live CD and run the following command

    bash <(curl -s http://goo.gl/tKEBG9)


## Configurations


Detects if using VirtualBox and installs guest additions.

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

The file system is setup with a single partition and no swap file.

All user input is taken at the start to ensure the installation can complete unattended.


## Development

This downloads and runs install.sh on the `dev` branch:

    bash <(curl -s http://goo.gl/1vmj59)



## References

* https://wiki.archlinux.org/index.php/Installation_Guide
* https://wiki.archlinux.org/index.php/Beginners'_Guide
* https://www.archlinux.org/mirrorlist/
* install.txt (from booted live CD)
