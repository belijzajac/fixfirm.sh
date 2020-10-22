#!/bin/bash

linux_firmware_git="git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git"
firmware_dir="linux-firmware"               # directory created after cloning the linux-firmware.git
update_initramfs="sudo update-initramfs -u" # -u means to update
declare -A firmware_paths                   # stores firmware module paths in key-value pairs
firmware_prefix="/lib/firmware/"            # where firmware modules live
fixed_count=0                               # number of firmware modules we've managed to fix

# silents commands' output
stfu () {
  "$@" >/dev/null 2>&1
  return $?
}

# get missing firmware
get_missing_firmware () {
  print_message good "Searching for missing firmware modules"
  # 1. redirect stderr to stdout
  # 2. redirect stdout to /dev/null
  # 3. use the $() to capture the redirected stderr
  missing_firmware=$(${update_initramfs} 2>&1 >/dev/null)
}

# cuts out a single name
cut_out_firmware_name () {
  # shellcheck disable=SC2086
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
  while [[ -n $firm_token ]]
  do
    firmware_paths+=([$firm_token]="NOT FOUND")
    counter=$((counter+8))
    cut_out_firmware_name $counter
  done
}

# clone Linux firmware repository
clone_git () {
  print_message good "Cloning: linux-firmware.git"

  # maybe we have already cloned the linux-firmware.git earlier?
  if [[ -d ${firmware_dir} ]]; then
    cd ${firmware_dir}
    stfu git pull origin master
  else
    stfu git clone ${linux_firmware_git}
    cd ${firmware_dir}
  fi
}

# copies missing firmware modules from `firmware/` to `/lib/firmware/`
copy_modules () {
  print_message good "Copying modules to /lib/firmware/"

  for mod in "${!firmware_paths[@]}"; do
    # cuts out firmware's name (e.g. firmware.bin)
    # `rev` reverses the string, so we cut out its name as the first field
    name=$(echo "${mod}" | rev | cut -d '/' -f 1 | rev)

    # path to the firmware omitting its name
    path=${mod%${name}}
    check_if_source_exists "${mod}" "${name}" "${path}"
  done
}

# checks if the firmware module exists in the cloned git repository's directory
check_if_source_exists () {
  if [[ -f ${1} ]]; then
    mkdir -p ${firmware_prefix}"${3}"
    stfu cp "${1}" "${firmware_prefix}${3}${2}"

    # update the information about fixed firmware
    firmware_paths[${1}]="FIXED"
    fixed_count=$((fixed_count+1))
  fi
}

silently_update_initramfs () {
  print_message good "Issuing: update-initramfs -u"
  # shellcheck disable=SC2086
  stfu ${update_initramfs}
}

# check for missing dependencies
dep_check () {
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
  if [[ -z $missing_firmware ]]; then
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
  print_message good "Cleaning up"
  #stfu rm -rf "${working_dir}/${firmware_dir}" # you may want to keep this
  stfu rm "${working_dir}/0"                   # some file descriptor
}

# outputs missing firmware modules
found_missing_firmware () {
  print_message good "Found the following missing modules:"
  for firm in "${!firmware_paths[@]}"; do
    echo "$firm"
  done
}

# finds lenght of the longest string in firmware_paths
find_max_str_length () {
  max_str_len=0
  for firm in "${!firmware_paths[@]}"; do
    if [[ ${#firm} -gt ${max_str_len} ]]; then
      max_str_len=${#firm}
    fi
  done
}

print_firmware_status () {
  find_max_str_length

  # "const char * format" for printf
  format="%-${max_str_len}s ==> %s\n" # e.g. "%-58s ==> %s\n"

  for firm in "${!firmware_paths[@]}"; do
    # shellcheck disable=SC2182
    # shellcheck disable=SC2059
    printf "${format}" "${firm}" "${firmware_paths[${firm}]}"
  done
}

print_summary () {
  print_message good "Summary:"
  print_firmware_status
  printf "%s\n" "------------------------"
  printf "Fixed:     %s\n" ${fixed_count}
  printf "Not found: %s\n" $((${#firmware_paths[@]} - fixed_count))
  printf "%s\n" "------------------------"
  print_message good "All done!"
}

# print informational messages
print_message () {
  case "$1" in
    "good")
      printf '\E[32m'; echo "$2"; printf '\E[0m'
      ;;
    "error")
      printf '\E[31m'; echo "$2"; printf '\E[0m'
      ;;
  esac
}

# runs the script
run () {
  set_working_dir
  dep_check git
  is_root
  get_missing_firmware
  is_firmware_missing
  tokenize_firmware
  found_missing_firmware
  clone_git
  copy_modules
  silently_update_initramfs
  clean_up
  print_summary
}

run
