#!/bin/bash

linux_firmware_git="git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git"
update_initramfs="sudo update-initramfs -u" # -u means to update
firmware_array=()

# get missing firmware
get_missing_firmware () {
  # 1. redirect stderr to stdout
  # 2. redirect stdout to /dev/null
  # 3. use the $() to capture the redirected stderr
  missing_firmware=$(${update_initramfs} 2>&1 > /dev/null)
}

# cuts out a single name
cut_out_firmware_name () {
  firm_token=$(echo ${missing_firmware} | cut -d ' ' -f $1)
}

# tokenizes (cuts out all) module names
tokenize_firmware () {
  counter=5

  # the below while loop needs a value open which to check on
  cut_out_firmware_name $counter

  # while firm_token has something in it
  while [ $firm_token > 0 ]
  do
    firmware_array+=($firm_token)
    counter=$((counter+8))

    cut_out_firmware_name $counter
  done
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
#                   RUN THE SCRIPT
# --------------------------------------------------- #

#clone_git

# Check if is run under root
if [[ $EUID -ne 0 ]]; then
  print_message error "Please run as root"
  exit 1
fi

get_missing_firmware

# `-z STRING` ==> the length of STRING is zero
if [[ -z "$missing_firmware" ]]; then
  print_message good "No missing firmware detected. All good :)"
  exit 1
fi

tokenize_firmware

# Print all elements
for i in "${firmware_array[@]}"; do
    echo "$i"
done
