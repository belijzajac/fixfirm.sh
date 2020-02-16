# fixfirm.sh

[![License](https://img.shields.io/static/v1?label=license&message=UNLICENSE&color=9cf)](LICENSE)

![FixFirm-preview](img/fixfirm_preview.gif)

## About

It's a simple Bash script that detects missing firmware in different modules, and fixes them with the existing ones found in the most recent Linux firmware repository.

### How it works

1.   Issues `update-initramfs -u` and collects infromation about missing firmware
2.   Clones `git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git`
3.   Copies the missing firmware to `/lib/firmware/`

### Why

As a matter of fact, I'm a regular user of the Liquorix kernel on Debian testing/sid, and whenever I update the kernel to a newer version, I get the following warning messages:

![missing-modules](img/missing_modules.png)

It shows that the Intel i915 chip lacks some firmware, even though I have already installed the package `xserver-xorg-video-intel` that supports the Intel i9xx family chipset. Since doing everything by hand on different machines became tiresome, I came up with this project idea.

## License

This project is available under the Unlicense License. See the LICENSE file for more info.
