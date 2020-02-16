#!/bin/bash

linux_firmware_git="git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git"
firmware_dir="linux-firmware"               # directory created after cloning the linux-firmware.git
update_initramfs="sudo update-initramfs -u" # -u means to update
firmware_paths=()                           # stores firmware module paths
firmware_prefix="/lib/firmware/"            # where firmware modules live

# get missing firmware
get_missing_firmware () {
  # 1. redirect stderr to stdout
  # 2. redirect stdout to /dev/null
  # 3. use the $() to capture the redirected stderr
  missing_firmware=$(${update_initramfs} 2>&1 > /dev/null)
}

# cuts out a single name
cut_out_firmware_name () {
  firm_token=$(echo ${missing_firmware} | cut -d ' ' -f $1 -s)

  # cut out the prefix `/lib/firmware/`
  firm_token=${firm_token/#$firmware_prefix}
}

# tokenizes (cuts out all) module names
tokenize_firmware () {
  counter=5

  # the below while loop needs a value upon which to check on
  cut_out_firmware_name $counter

  # while firm_token has something in it
  while [ $firm_token > 0 ]
  do
    firmware_paths+=($firm_token)
    counter=$((counter+8))

    cut_out_firmware_name $counter
  done
}

# clone Linux firmware repository
clone_git () {
  mkdir -p __temp && cd __temp

  # maybe we have already cloned the linux-firmware.git earlier?
  if [ -d "${firmware_dir}" ]; then
    cd ${firmware_dir}
    git pull origin master
  else
    git clone ${linux_firmware_git}
    cd ${firmware_dir}
  fi
}

# copies missing firmware modules from `firmware/` to `/lib/firmware/`
copy_modules () {
  for mod in "${firmware_paths[@]}"; do
    dest_dir=$(echo ${mod} | cut -d '/' -f 1)
    cp "${mod}" "${firmware_prefix}${dest_dir}/"
  done
}

clean_up () {
  rm 0 # remove the empty descriptor
}

# print informational messages
print_message () {
  case "$1" in
    "good")
      printf '\E[32m'; echo "GOOD: $2"; printf '\E[0m'
      ;;
    "error")
      printf '\E[31m'; echo "ERROR: $2"; printf '\E[0m'
      ;;
  esac
}

# --------------------------------------------------- #
#                   RUN THE SCRIPT
# --------------------------------------------------- #

# Check if is run under root
if [[ $EUID -ne 0 ]]; then
  print_message error "Please run as root"
  exit 1
fi

print_message good "Searching for missing firmware modules"
get_missing_firmware

# `-z STRING` ==> the length of STRING is zero
if [[ -z "$missing_firmware" ]]; then
  print_message good "No missing firmware found"
  exit 1
fi

tokenize_firmware

print_message good "Found the following missing modules:"
for i in "${firmware_paths[@]}"; do
    echo "$i"
done

print_message good "Cloning: linux-firmware.git"
clone_git

print_message good "Copying modules to /lib/firmware/"
copy_modules

print_message good "Issuing: update-initramfs -u"
get_missing_firmware

clean_up
print_message good "All done"
