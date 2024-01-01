#!/bin/bash
# shellcheck disable=SC2086,SC2164
#
# Copyright (C) 2020-2024 Tautvydas Povilaitis (belijzajac) and contributors
# Distributed under the terms of The GNU Public License v3.0 (GPLv3)

version="1.0.16"
linux_firmware_git="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git"
firmware_dir="linux-firmware"               # directory created after cloning linux-firmware.git
update_initramfs="sudo update-initramfs -u" # -u means to update
declare -A firmware_paths                   # stores firmware module paths in key-value pairs
firmware_prefix="/lib/firmware/"            # path where firmware modules are located
fixed_count=0                               # number of firmware modules we've managed to fix
declare -A cmd_args=(["keep"]="False")      # command line arguments

print_logo () {
  cat << LOGO
   __ _       __ _                      _
  / _(_)     / _(_)                    | |
 | |_ ___  _| |_ _ _ __ _ __ ___    ___| |__
 |  _| \\ \\/ /  _| | '__| '_ \` _ \  / __| '_ \\
 | | | |>  <| | | | |  | | | | | |_\__ \ | | |
 |_| |_/_/\\_\\_| |_|_|  |_| |_| |_(_)___/_| |_| v$version

LOGO
}

print_usage () {
  cat << USAGE
Usage:
  bash fixfirm.sh [ARGUMENTS]

ARGUMENTS:
  -h,--help      Display this help and exit.
  -m,--missing   Print missing firmware modules and exit.
  -k,--keep      Keep the cloned Linux firmware repository from deletion.
USAGE
}

parse_arguments () {
  while [[ -n $# ]]; do
    case $1 in
      -h|--help)
        print_usage
        exit 0
        ;;
      -m|--missing)
        run_necessary_steps
        exit 0
        ;;
      -k|--keep)
        cmd_args["keep"]="True"
        break
        ;;
      -*)
        print_message error "Unknown parameter: $1"
        exit 1
        ;;
      *)
        break
        ;;
    esac;
  done
}

stfu () {
  "$@" >/dev/null 2>&1
  return $?
}

get_missing_firmware () {
  print_message good "Searching for missing firmware modules"
  # 1. redirect stderr to stdout
  # 2. redirect stdout to /dev/null
  # 3. use the $() to capture the redirected stderr
  missing_firmware=$(${update_initramfs} 2>&1 >/dev/null | grep "W: Possible missing firmware")
}

cut_out_firmware_name () {
  firm_token=$(echo ${missing_firmware} | cut -d ' ' -f "$1" -s)
  # cut out the `/lib/firmware/` prefix
  firm_token=${firm_token/#$firmware_prefix}
}

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

clone_git () {
  print_message good "Cloning Linux firmware repository"
  # maybe we have already cloned linux-firmware.git from earlier?
  if [[ -d $firmware_dir ]]; then
    cd $firmware_dir
    stfu git pull origin main
  else
    stfu git clone $linux_firmware_git
    cd $firmware_dir
  fi
}

copy_modules () {
  print_message good "Copying modules to /lib/firmware/"
  for mod in "${!firmware_paths[@]}"; do
    # cuts out firmware's name (e.g. firmware.bin)
    # `rev` reverses the string, so we cut out its name as the first field
    name=$(echo "$mod" | rev | cut -d '/' -f 1 | rev)
    # path to the firmware omitting its name
    path=${mod%"${name}"}
    check_if_source_exists "$mod" "$name" "$path"
  done
}

check_if_source_exists () {
  if [[ -f $1 ]]; then
    mkdir -p ${firmware_prefix}"${3}"
    stfu cp "$1" "${firmware_prefix}${3}${2}"
    # update the information about fixed firmware
    firmware_paths[$1]="FIXED"
    fixed_count=$((fixed_count+1))
  fi
}

silently_update_initramfs () {
  print_message good "Updating initramfs images"
  stfu ${update_initramfs}
}

dependency_check () {
  if ! stfu command -v "$1"
  then
    print_message error "Missing package: $1"
    exit 1
  fi
}

is_root () {
  if [[ $EUID -ne 0 ]]; then
    print_message error "Please run as root"
    exit 1
  fi
}

is_firmware_missing () {
  # if the length of `missing_firmware` is zero
  if [[ -z $missing_firmware ]]; then
    print_message good "No missing firmware found"
    exit 0
  fi
}

set_working_dir () {
  working_dir=$(pwd)
}

clean_up () {
  print_message good "Cleaning up"
  # remove linux git repo files
  if ! [[ ${cmd_args["keep"]} == "True" ]]; then
    stfu rm -rf "${working_dir}/${firmware_dir}"
  fi
  # some file descriptor
  stfu rm "${working_dir}/0"
}

print_missing_firmware () {
  print_message good "Found the following missing modules:"
  for firm in "${!firmware_paths[@]}"; do
    echo "$firm"
  done
}

find_max_string_length () {
  max_str_len=0
  for firm in "${!firmware_paths[@]}"; do
    if [[ ${#firm} -gt $max_str_len ]]; then
      max_str_len=${#firm}
    fi
  done
}

print_firmware_status () {
  find_max_string_length
  for firm in "${!firmware_paths[@]}"; do
    printf "%-${max_str_len}s ==> %s\n" "$firm" "${firmware_paths[$firm]}"
  done
}

print_summary () {
  print_message good "Summary:"
  print_firmware_status
  printf "%s\n" "------------------------"
  printf "Fixed:     %d\n" $fixed_count
  printf "Not found: %d\n" $((${#firmware_paths[@]} - fixed_count))
  printf "%s\n" "------------------------"
  print_message good "All done!"
}

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

run_necessary_steps () {
  set_working_dir
  dependency_check git
  is_root
  get_missing_firmware
  is_firmware_missing
  tokenize_firmware
  print_missing_firmware
}

run_optional_steps () {
  clone_git
  copy_modules
  silently_update_initramfs
  clean_up
  print_summary
}

run () {
  print_logo
  parse_arguments "$@"
  run_necessary_steps
  run_optional_steps
  exit 0
}

run "$@"
