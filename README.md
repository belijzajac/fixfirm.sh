# fixfirm.sh

[![license](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

![preview](docs/preview.mp4)

## About

Finds missing firmware kernel modules in initramfs images by running `update-initramfs -u` and then tries to fix them by populating missing binary modules from the official upstream Linux firmware git repository. It works only for Debian-based distros, such as Ubuntu and Linux Mint.

> An **initramfs** (**init**ial **ram** **f**ile **s**ystem) is used to prepare Linux systems during boot before the init process starts. The initramfs is a gzipped cpio archive. At boot time, the kernel unpacks that archive into RAM disk and takes care of mounting important file systems (by loading the proper kernel modules and drivers) such as /usr or /var, preparing the /dev file structure, etc.

### The process behind the script

1.   Runs `update-initramfs -u` to collect information about missing firmware
2.   Clones `git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git`
3.   Finds relevant missing binary modules and copies them over to `/lib/firmware/`
4.   Runs `update-initramfs -u` once again to update initramfs images

### Usage

| Argument            | Meaning                                                      |
| ------------------- | ------------------------------------------------------------ |
| `-h` or `--help`    | Display the help window and exit                             |
| `-m` or `--missing` | Print missing firmware modules and exit                      |
| `-k` or `--keep`    | Keep the cloned Linux firmware git repository from deletion<br />(useful if you don't want to download 1 GB of data each time you run the script) |

For instance, by typing `bash fixfirm.sh --help`, it will display the help window.

### Why was this needed?

I frequently use the Liquorix kernel on Debian Sid, and every time I update the kernel to a newer version, I receive the annoying warning messages that follow after building kernel modules for the newer kernel version:

![missing-modules](docs/missing_modules.png)

It shows that the Intel i915 chip lacks some firmware, even though I have already installed the `xserver-xorg-video-intel` package that supports the Intel i9xx family chipset. Since fixing the same issues by hand all over again on different Linux-powered machines has become cumbersome, I came up with this project idea to help me automate the system administration of my home servers.

## License

This project is available under the [GPLv3 license](LICENSE).
