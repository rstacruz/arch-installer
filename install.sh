#!/usr/bin/env bash

# Defaults
KEYBOARD_LAYOUT="us"
PRIMARY_LOCALE="en_US.UTF-8"
TIMEZONE="Asia/Manila"

HOSTNAME="my-arch"
PRIMARY_USERNAME="anon"
PRIMARY_PASSWORD="password1"
ROOT_PASSWORD="password1"

FS_ROOT="/dev/sda2"
FS_EFI="/dev/sda1"

DEFAULT_LOCALE="en_US.UTF-8"
ARCH_MIRROR=""

# Start doing stuff
run_install() {
  ensure_efi
  ensure_online
  set_keyboard_layout
  enable_ntp
  partition_disk #(!)
  mount_disks
  update_mirrors
  do_pacstrap
  generate_fstab
  do_chroot
}

run_in_chroot() {
  ensure_chroot
  set_timezone
  set_locale
  set_keyboard_layout
  set_hostname
  update_hosts_file
  set_root_password
  install_grub_bootloader
  create_primary_user
  install_sudo
}

_() {
  echo $*
}


warn() {
  echo $*
}

info() {
  echo $*
}

# Ensures that the system is booted in UEFI mode, and not
# Legacy mode. Exits the installer if it fails.
ensure_efi() {
  if [[ ! -d /sys/firmware/efi/efivars ]]; then
    warn "You are not booted in EFI mode."
    exit 1
  fi
}

# Exits the installer if were offline.
ensure_online() {
  if ! ping -c 1 -W 1 8.8.8.8 &>/dev/null; then
    warn "You dont seem to be online."
    exit 1
  fi
}

set_keyboard_layout() {
  info "Setting keyboard layout"
  _ loadkeys $KEYBOARD_LAYOUT
}

enable_ntp() {
  info "Enabling syncing clock via ntp"
  _ timedatectl set-ntp true


}

run_config() {
  message="
  Welcome to Arch Linux!
  Configure your installation here, then hit 'Proceed'.
  "
  eval $(resize)
  whiptail \
    --title "Arch Installer" \
    --no-shadow \
    --ok-label "Change" \
    --extra-button \
    --extra-label "Proceed" \
    --menu "$message"\
    $LINES $COLUMNS $(( $LINES - 12 )) \
    "Hostname" "[$HOSTNAME]" \
    "Keyboard layout" "[$KEYBOARD_LAYOUT]" \
    "Time zone" "[$TIMEZONE]" \
    "Locale" "[en_US.UTF-8]" \
    "Your username" "[$PRIMARY_USERNAME]" \
    "Your password" "[password1]" \
    "Root password" "[password1]"
}

run_welcome() {
  message="
       .
      /#\\
     /###\\                     #     | *
    /p^###\\      a##e #%' a#'e 6##%  | | |-^-. |   | \\ /
   /##P^q##\\    .oOo# #   #    #  #  | | |   | |   |  X
  /##(   )##\\   %OoO# #   %#e' #  #  | | |   | ^._.| / \\
 /###P   q#,^\\
/P^         ^q\\ Welcome to Arch Linux! Lets get started.
  "
  whiptail \
    --title "Arch Installer" \
    --msgbox "$message" \
    20 64
}

# Router
action="welcome"
case "$action" in
  config)
    run_config
    ;;
  welcome)
    run_welcome
    ;;
  *)
    warn "Dunno"
    ;;
esac
# Lets go
run_config
