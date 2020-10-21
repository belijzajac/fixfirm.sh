#!/bin/bash

linux_firmware_git="git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git"
firmware_dir="linux-firmware"               # directory created after cloning the linux-firmware.git
update_initramfs="sudo update-initramfs -u" # -u means to update
firmware_paths=()                           # stores firmware module paths
firmware_prefix="/lib/firmware/"            # where firmware modules live

# silents commands' output
stfu () {
  "$@" >/dev/null 2>&1
  return $?
}

# get missing firmware
get_missing_firmware () {
  # 1. redirect stderr to stdout
  # 2. redirect stdout to /dev/null
  # 3. use the $() to capture the redirected stderr
  missing_firmware=$(${update_initramfs} 2>&1 >/dev/null)
}

# cuts out a single name
cut_out_firmware_name () {
  firm_token=$(echo "${missing_firmware}" | cut -d ' ' -f "$1" -s)

  # cut out the prefix `/lib/firmware/`
  firm_token=${firm_token/#$firmware_prefix}
}

# tokenizes (cuts out all) module names
tokenize_firmware () {
  counter=5

  # the below while loop needs a value upon which to check on
  cut_out_firmware_name $counter

  # while firm_token has something in it
  while [ -n "$firm_token" ]
  do
    firmware_paths+=("$firm_token")
    counter=$((counter+8))
    cut_out_firmware_name $counter
  done
}

# clone Linux firmware repository
clone_git () {
  # maybe we have already cloned the linux-firmware.git earlier?
  if [ -d "${firmware_dir}" ]; then
    cd ${firmware_dir}
    stfu git pull origin master
  else
    stfu git clone ${linux_firmware_git}
    cd ${firmware_dir}
  fi
}

# copies missing firmware modules from `firmware/` to `/lib/firmware/`
copy_modules () {
  for mod in "${firmware_paths[@]}"; do
    # cuts out firmware's name (e.g. firmware.bin)
    # `rev` reverses the string, so we cut out its name as the first field
    name=$(echo "${mod}" | rev | cut -d '/' -f 1 | rev)

    # path to the firmware omitting its name
    path="${mod%${name}}"

    # create directory if not existing, and copy the firmware over to it
    mkdir -p ${firmware_prefix}"${path}"
    stfu cp "${mod}" "${firmware_prefix}${path}${name}"
  done
}

# check for missing dependencies
dep_check() {
  if ! stfu command -v "$1"
  then
    print_message error "Missing package: $1"
    exit 1
  fi
}

# check if the script is run as root
is_root () {
  if [[ $EUID -ne 0 ]]; then
    print_message error "Please run as root"
    exit 1
  fi
}

# did we find any missing firmware modules, at all?
is_firmware_missing () {
  # if the length of `missing_firmware` is zero
  if [[ -z "$missing_firmware" ]]; then
    print_message good "No missing firmware found"
    exit 0
  fi
}

# set the script's initial working directory
set_working_dir () {
  working_dir=$(pwd)
}

# removes temporary files
clean_up () {
  #stfu rm -rf "${working_dir}/${firmware_dir}" # you may want to keep this
  stfu rm "${working_dir}/0"                   # some file descriptor
}

# outputs missing firmware modules
found_missing_firmware () {
  for i in "${firmware_paths[@]}"; do
      echo "$i"
  done
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

# runs the script
run () {
  set_working_dir
  dep_check git
  is_root
  
  print_message good "Searching for missing firmware modules"
  get_missing_firmware

  is_firmware_missing
  tokenize_firmware

  print_message good "Found the following missing modules:"
  found_missing_firmware

  print_message good "Cloning: linux-firmware.git"
  clone_git

  print_message good "Copying modules to /lib/firmware/"
  copy_modules

  print_message good "Issuing: update-initramfs -u"
  get_missing_firmware
  found_missing_firmware # TODO: output the non-existent firmware modules

  print_message good "Cleaning up"
  clean_up
  print_message good "All done!"
}

run
