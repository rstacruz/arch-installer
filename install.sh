#!/usr/bin/env bash
# vim:foldmethod=marker:foldmarker={,}

# Default config
app:set_defaults() {
  # Defaults
  KEYBOARD_LAYOUT="us"
  PRIMARY_LOCALE="en_US.UTF-8 UTF-8"
  TIMEZONE="Asia/Manila"

  SYSTEM_HOSTNAME="my-arch"
  PRIMARY_USERNAME="anon"
  PRIMARY_PASSWORD="password1"
  ROOT_PASSWORD="password1"

  FS_ROOT="/dev/sda2"
  FS_EFI="/dev/sda1"

  INSTALLER_TITLE="Arch Linux Installer"
  INSTALLER_URL="https://github.com/rstacruz/arch-installer"
  ARCH_MIRROR=""

  # Dialog implementation to use.
  DIALOG=${DIALOG:-dialog}
  DIALOG_OPTS=( \
    --backtitle "$INSTALLER_TITLE" \
    --title "Arch Installer" \
  )

  # Dimensions
  WIDTH_MD=72

  # This variable isn't always available
  LINES="$(tput lines)"
  COLUMNS="$(tput cols)"

  # Where to write the script
  SCRIPT_FILE="$HOME/arch_installer.sh"
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

# Set keyboard layout
set_keyboard_layout() {
  info "Setting keyboard layout"
  _ loadkeys $KEYBOARD_LAYOUT
}

# Enable NTP
enable_ntp() {
  info "Enabling syncing clock via ntp"
  _ timedatectl set-ntp true
}

# Config: Show system dialog
config:show_system_dialog() {
  message="\nWelcome to Arch Linux!\nConfigure your installation here, then hit 'Next'.\n "
  $DIALOG "${DIALOG_OPTS[@]}" \
    --title "Configure your system" \
    --no-cancel \
    --no-shadow \
    --ok-label "Change" \
    --extra-button \
    --extra-label "Next" \
    --menu "$message" \
    14 $WIDTH_MD 3 \
    "Keyboard layout" "[$KEYBOARD_LAYOUT]" \
    "Time zone" "[$TIMEZONE]" \
    "Locale" "[en_US.UTF-8]"
}

# Config: Show user dialog
config:show_user_dialog() {
  message="\nTell me avout the user you wanna use.  This ie a configuration dialog with some text in it that explains whats going on.\n "
  $DIALOG "${DIALOG_OPTS[@]}" \
    --title "Configure your user" \
    --no-cancel \
    --no-shadow \
    --ok-label "Change" \
    --extra-button \
    --extra-label "Next" \
    --menu "$message"\
    20 $WIDTH_MD 4 \
    "Hostname" "[$SYSTEM_HOSTNAME]" \
    "Your username" "[$PRIMARY_USERNAME]" \
    "Your password" "[password1]" \
    "Root password" "[password1]"
}

# Show welcome message
welcome:show_dialog() {
  message="
            .
           /#\\
          /###\\                     #     | .   __
         /#^###\\       a#e #%' a#'e 6##%  | | |'  | |   | \\ /
        /##P^q##\\    .oOo# #   #    #  #  | | |   | |   |  X
       /##(   )##\\   %OoO# #   %#e' #  #  | | |   | '._.| / \\
      /###P   q##^\\
     /P^         ^q\\

Welcome to Arch Linux! Lets get started. Before we begin, a few things:

- Be sure to read the wiki.
  Nte tuhon tuhoen utoehu noetuhoe ntu.

- It probably wont work.
  Nte tuhon tuhoen utoehu noetuhoe ntu.

- Have fun anyway!
  "
  $DIALOG "${DIALOG_OPTS[@]}" \
    --msgbox "$message" \
    "$(( $LINES - 8 ))" $WIDTH_MD
}

# Confirm
confirm:run() {
  message="
    You are now ready to install, please review the install script.
  "
  $DIALOG "${DIALOG_OPTS[@]}" \
    --msgbox "$message" \
    7 $WIDTH_MD

  $DIALOG "${DIALOG_OPTS[@]}" \
    --title "Install script" \
    --backtitle "You are now ready to install! Review the install script below." \
    --ok-label "Install now" \
    --extra-button \
    --extra-label "Exit" \
    --textbox "$SCRIPT_FILE" \
    $(( $LINES - 4 )) $COLUMNS
}

script:write() {
  (
    echo '#!/usr/bin/env bash'
    echo "# This file was saved to $SCRIPT_FILE."
    echo "#"
    echo "set -euo pipefail"
    echo ''
    echo "# Set keyboard layout"
    echo "loadkeys $KEYBOARD_LAYOUT"
    echo ''
    echo "# Enabling syncing clock via ntp"
    echo "timedatectl set-ntp true"
    echo ''
    echo "# Format drives"
    echo "mkfs.ext4 $FS_ROOT"
    echo ''
    echo "# Mount your partitions"
    echo "mount $FS_ROOT /mnt"
    echo "mkdir -p $FS_ROOT /mnt/boot"
    echo "mount $FS_EFI /mnt/boot"
    echo ''
    echo "# Begin installing"
    echo "# TODO: vi /etc/pacman.d/mirrorlist"
    echo "pacstrap /mnt base"
    echo ''
    echo "# Generate fstab"
    echo "genfstab -U /mnt >> /mnt/etc/fstab"
    echo ''
    echo "# Set timezone"
    echo "arch-chroot /mnt sh <<END"
    echo "  ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime"
    echo "  hwclock --systohci"
    echo "END"
    echo ''
    echo "# Set locales"
    echo "arch-chroot /mnt sh <<END"
    echo "  echo '$PRIMARY_LOCALE' >> /etc/locale.gen"
    echo "  locale-gen"
    echo "END"
    echo ''
    echo "# Make keyboard layout persist on boot"
    echo "arch-chroot /mnt sh <<END"
    echo "  'KEYMAP=$KEYBOARD_LAYOUT' > /etc/vconsole.conf"
    echo "END"
    echo ''
    echo "# Set hostname"
    echo "arch-chroot /mnt sh <<END"
    echo "  echo '$SYSTEM_HOSTNAME' > /etc/hostname"
    echo "  echo '127.0.0.1 localhost' >> /etc/hosts"
    echo "  echo '::1 localhost' >> /etc/hosts"
    echo "  echo '127.0.1.1 $SYSTEM_HOSTNAME.localdomain $SYSTEM_HOSTNAME' >> /etc/hosts"
    echo "END"
    echo ''
    echo "# Set root password"
    echo "arch-chroot /mnt sh <<END"
    echo "  echo -e '$ROOT_PASSWORD\\n$ROOT_PASSWORD' | passwd"
    echo "END"
    echo ''
    echo "# GRUB boot loader"
    echo "arch-chroot /mnt sh <<END"
    echo "  pacman -Syu --noconfirm grub efibootmgr"
    echo "  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB"
    echo "  grub-mkconfig -o /boot/grub/grub.cfg"
    echo "END"
    echo ''
    echo "# Create your user"
    echo "arch-chroot /mnt sh <<END"
    echo "  useradd -Nm -g users -G wheel,sys $PRIMARY_USERNAME"
    echo "  echo -e '$PRIMARY_PASSWORD\\n$PRIMARY_PASSWORD' | passwd $PRIMARY_USERNAME"
    echo "END"
    echo ''
    echo "# Set up sudo"
    echo "arch-chroot /mnt sh <<END"
    echo "  pacman -Syu --noconfirm sudo"
    echo "  echo '%wheel ALL=(ALL:ALL) ALL' | sudo EDITOR='tee -a' visudo"
    echo "END"
    echo ''
    echo "# Generated by $INSTALLER_TITLE ($INSTALLER_URL)"
  ) > "$SCRIPT_FILE"
}

app:parse_options() {
  while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
    -V | --version )
      echo version
      exit
      ;;
    -s | --string )
      shift; string=$1
      ;;
    -f | --flag )
      flag=1
      ;;
  esac; shift; done
  if [[ "$1" == '--' ]]; then shift; fi
}

# Start everything
app:start() {
  app:parse_options
  ensure_efi
  ensure_online
  welcome:show_dialog
  config:show_system_dialog
  config:show_user_dialog
  script:write
  confirm:run
}

# Lets go!
app:set_defaults
app:start
