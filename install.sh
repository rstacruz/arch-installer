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
INSTALLER_TITLE="Welcome to Arch Linux"
ARCH_MIRROR=""

# Dialog implementation to use.
DIALOG=${DIALOG:-dialog}

WIDTH_MD=72

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
  config__show_system_dialog
  config__show_user_dialog
  run_confirm
}

config__show_system_dialog() {
  message="
  Welcome to Arch Linux!
  Configure your installation here, then hit 'Proceed'.
  "
  $DIALOG \
    --backtitle "$INSTALLER_TITLE" \
    --title "Configure your system" \
    --no-cancel \
    --no-shadow \
    --ok-label "Change" \
    --extra-button \
    --extra-label "Next" \
    --menu "$message"\
    20 $WIDTH_MD 3 \
    "Keyboard layout" "[$KEYBOARD_LAYOUT]" \
    "Time zone" "[$TIMEZONE]" \
    "Locale" "[en_US.UTF-8]"
}

config__show_user_dialog() {
  message="
  Your user

  Tell me avout the user you wanna use.  This ie a configuration dialog with some text in it that explains whats going on.
  "
  eval $(resize)
  $DIALOG \
    --backtitle "$INSTALLER_TITLE" \
    --title "Configure your user" \
    --no-cancel \
    --no-shadow \
    --ok-label "Change" \
    --extra-button \
    --extra-label "Next" \
    --menu "$message"\
    20 $WIDTH_MD 4 \
    "Hostname" "[$HOSTNAME]" \
    "Your username" "[$PRIMARY_USERNAME]" \
    "Your password" "[password1]" \
    "Root password" "[password1]"
}



config__export_variables() {
  echo HOSTNAME="$HOSTNAME"
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
     /P^         ^q\\

Welcome to Arch Linux! Lets get started. Before we begin, a few things:

- Be sure to read the wiki.
  Nte tuhon tuhoen utoehu noetuhoe ntu.

- It probably wont work.
  Nte tuhon tuhoen utoehu noetuhoe ntu.

- Have fun anyway!
  "
  $DIALOG \
    --backtitle "$INSTALLER_TITLE" \
    --title "Arch Installer" \
    --no-shadow \
    --scrollbar \
    --msgbox "$message" \
    18 $WIDTH_MD
}

run_confirm() {
  message="
  Confirm these details:
  "
  $DIALOG \
    --backtitle "$INSTALLER_TITLE" \
    --title "Confirm" \
    --no-shadow \
    --scrollbar \
    --msgbox "$message" \
    18 $WIDTH_MD
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
