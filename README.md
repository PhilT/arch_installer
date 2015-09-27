# Install and Configure Arch Linux

Basic Archlinux setup script. Install minimum system to enable
other apps and tools to be installed after a reboot.

Install X Windows, apps and configuration in separate scripts
(e.g. https://github.com/PhilT/dotfiles).

It makes some assumptions.

## Summary

* Only input is machine and a password (sets both user and root to the same)
* single GPT partition and swap file (plus UEFI partition)
  WARNING - Existing partitions will be deleted
* adds entries into `fstab`
* installs base system with chroot
* British English Language, UK keyboard and UK mirrorlist
* ntpd for time sync
* syslinux UEFI bootloader (`UEFI=false` for BIOS)
* Network management with netctl and systemd (WIFI and Ethernet)
* Sets hostname
* Enables sshd for servers
* sensors
* installs base-devel git vim dialog bash-completion
* For time sync, adds a user with sudo access
  Default: `phil` (me!), override with e.g. `NEWUSER=joe`
* enable multilib
* Sets some build flags for AUR to optimise build speed
* Adds no password needed for shutdown and reboot
* Adds users SSH keys to home dir
* Adds Github key to `known_hosts`
* clones my dotfiles into workspace (default: `~/ws`) and sets up symlinks
  Overrides:
  `WORKSPACE=~/myworkspace`
  `PUBLIC_GIT=git@github.com:YourName`
  `DOTFILES_SYNC_CMD=bin/sync.sh`


## Usage

Boot an Arch Linux Live CD (https://www.archlinux.org/download/) and run the following commands.
Make a note of the IP address:

    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
    systemctl start sshd
    passwd
    ip a

If setting up on a laptop you may need:

    wifi-menu

On the host, copy over the SSH keys (for Github):

    scp ~/.ssh/id_rsa* root@IPaddress:~

Then run the installer:

    ssh root@IPaddress
    INSTALL=all bash <(curl -Ls http://goo.gl/tKEBG9)

I do it this way round as I don't always have sshd available on the host (Windows machine). Also,
SSHing into the guest to run the install gives you scrollback on the host (and it's easier to
copy the command to run or rerun it).

If you don't want to install everything, omit INSTALL and specify what you want:

    NOPASS_BOOT=true bash <(curl -Ls http://goo.gl/tKEBG9)

Install everything except the no pass on boot:

    INSTALL=all NOPASS_BOOT=false bash <(curl -Ls http://goo.gl/tKEBG9)

If you mess something up and need to rerun the installation, simply unmount the drive and
rerun the install. The existing partition will be removed. The bootloader will get upset,
however, so once you're done testing it's best to start from scratch:

    umount -R /mnt

Take a look at the script for all the options and variables.


## Notes

System-wide configuration files that will be modified by this script are first copied to a
file with the extension .original (e.g. `/etc/pacman.conf.original`).

All other options are specified as env variables.

* `MACHINE=<name>` - specify the hostname (and sets some options). Prompts if not specified
* `PASSWORD=<password>` - Insecure but handy for testing (prompts if not specified)
* `INSTALL=all` - everything except `REBOOT`
* `INSTALL=dryrun` - does not execute commands (only logs)
* `REBOOT=true` - unmount and reboot at the end. You can also do this manually with `umount -R /mnt && reboot`


## Logging

Initially all commands and output is sent to `/tmp/install.log`. Once the
partition is mounted the log file is moved to `/mnt/home/user/install.log`. On a `dryrun`
logging is simply sent to `~/install.log`.


Login with chroot (after installation but before reboot). Useful for further testing:

    arch-chroot /mnt su [username]

Logs in with username or root.


## References

Basically all of https://wiki.archlinux.org! It's an amazing resource!

* https://wiki.archlinux.org/index.php/Installation_Guide
* https://wiki.archlinux.org/index.php/Beginners'_Guide
* https://www.archlinux.org/mirrorlist/
* install.txt (from booted live CD)

