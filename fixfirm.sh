#!/bin/bash

linux_firmware_git="git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git"
update_initramfs="sudo update-initramfs -u" # -u means to update

# check for missing firmware
is_missing () {
	# 1. redirect stderr to stdout
	# 2. redirect stdout to /dev/null
	# 3. use the $() to capture the redirected stderr
	missing_firmware=$(${update_initramfs} 2>&1 > /dev/null)
	echo ${missing_firmware}
}

# clone Linux firmware repository
clone_git () {
	mkdir -p __temp && cd __temp
	git clone ${linux_firmware_git}
}

# print informational messages
print_message () {
	case "$1" in
		"good")
			printf '\E[32m'; echo "GOOD: $2"; printf '\E[0m'
			;;
		"warning")
			printf '\E[33m'; echo "WARNING: $2"; printf '\E[0m'
			;;
		"error")
			printf '\E[31m'; echo "ERROR: $2"; printf '\E[0m'
			;;
	esac
}

# --------------------------------------------------- #
# 					RUN THE SCRIPT
# --------------------------------------------------- #

#clone_git

# Check if is run under root
if [[ $EUID -ne 0 ]]; then
	print_message error "Please run as root"
	exit 1
fi

is_missing

# `-z STRING` ==> the length of STRING is zero
if [[ -z "$missing_firmware" ]]; then
	print_message good "No missing firmware"
	exit 1
fi
