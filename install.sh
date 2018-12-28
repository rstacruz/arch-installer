#!/usr/bin/env bash
# vim:foldmethod=marker:foldmarker={,}
set -eo pipefail

# Default config
app:set_defaults() {
  # Defaults
  KEYBOARD_LAYOUT=${KEYBOARD_LAYOUT:-us}
  PRIMARY_LOCALE="en_US.UTF-8 UTF-8"
  TIMEZONE="Asia/Manila"

  SYSTEM_HOSTNAME="my-arch"
  PRIMARY_USERNAME="anon"
  PRIMARY_PASSWORD="password1"

  FS_DISK="/dev/sda"
  FS_ROOT="/dev/sda2"
  FS_EFI="/dev/sda1"

  INSTALLER_TITLE="Arch Linux Installer"
  INSTALLER_URL="https://github.com/rstacruz/arch-installer"
  ARCH_MIRROR=""

  # Dialog implementation to use.
  DIALOG=${DIALOG:-dialog}
  DIALOG_OPTS=( \
    --no-collapse \
    --backtitle "$INSTALLER_TITLE (press [Esc] twice to exit)" \
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

# Ensures that the system is booted in UEFI mode, and not
# Legacy mode. Exits the installer if it fails.
ensure_efi() {
  if [[ ! -d /sys/firmware/efi/efivars ]]; then
    echo "You don't seem to be booted in EFI mode."
    exit 1
  fi
}

# Exits the installer if were offline.
ensure_online() {
  if ! ping -c 1 -W 1 8.8.8.8 &>/dev/null; then
    echo "You don't seem to be online."
    exit 1
  fi
}

ensure_arch() {
  if [[ ! -e /etc/pacman.d/mirrorlist ]]; then
    echo "You don't seem to have pacman available."
    echo "Please run this from the Arch Linux live USB."
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

config:system() {
  set +e; while true; do
    choice="$(config:show_system_dialog)"
    case "$?" in
      0)
        case "$choice" in
          Keyboard\ layout)
            KEYBOARD_LAYOUT=$(form:text_input "Keyboard layout:" "$KEYBOARD_LAYOUT")
            ;;
          Time\ zone)
            TIMEZONE=$(form:text_input "Time zone:" "$TIMEZONE")
            ;;
          Locale)
            PRIMARY_LOCALE=$(form:text_input "Locale:" "$PRIMARY_LOCALE")
            ;;
        esac
        ;;
      3) break ;; # "Next"
      *) app:abort ;; # "Cancel"
    esac
  done; set -e
}

# Form helper
form:text_input() {
  label="$1"
  value="$2"
  description="$3"
  $DIALOG "${DIALOG_OPTS[@]}" \
    --title "" \
    --no-cancel \
    --inputbox \
    "$label\n$description" \
    8 $WIDTH_MD \
    "$value" \
    3>&1 1>&2 2>&3
}

# Config: Show system dialog
config:show_system_dialog() {
  message="\nWelcome to Arch Linux!\nConfigure your installation here, then hit 'Next'.\n "
  $DIALOG "${DIALOG_OPTS[@]}" \
    --title "Configure your system" \
    --no-cancel \
    --ok-label "Change" \
    --extra-button \
    --extra-label "Next" \
    --menu "$message" \
    14 $WIDTH_MD 3 \
    "Keyboard layout" "[$KEYBOARD_LAYOUT]" \
    "Time zone" "[$TIMEZONE]" \
    "Locale" "[$PRIMARY_LOCALE]" \
    3>&1 1>&2 2>&3
}

config:user() {
  set +e; while true; do
    choice="$(config:show_user_dialog)"
    case "$?" in
      0)
        case "$choice" in
          Hostname)
            SYSTEM_HOSTNAME=$( \
              form:text_input \
              "System hostname:" "$SYSTEM_HOSTNAME" \
              "This is how your system will identify itself in the network.")
            ;;
          Your\ username)
            PRIMARY_USERNAME=$(\
              form:text_input \
              "Username:" "$PRIMARY_USERNAME" \
              "This is the user you will be using on a day-to-day basis.")
            ;;
          Your\ password)
            PRIMARY_PASSWORD=$( \
              form:text_input \
              "Password:" "$PRIMARY_PASSWORD" \
              "Password for your primary user."
            )
            ;;
        esac
        ;;
      3) break ;; # "Next"
      *) app:abort ;; # "Cancel"
    esac
  done; set -e
}

# Config: Show user dialog
config:show_user_dialog() {
  message="\nTell me about the user you're going to use day-to-day. This is a configuration dialog with some text in it that explains what's going on.\n "
  $DIALOG "${DIALOG_OPTS[@]}" \
    --title "Configure your user" \
    --no-cancel \
    --no-shadow \
    --ok-label "Change" \
    --extra-button \
    --extra-label "Next" \
    --menu "$message"\
    14 $WIDTH_MD 3 \
    "Hostname" "[$SYSTEM_HOSTNAME]" \
    "Your username" "[$PRIMARY_USERNAME]" \
    "Your password" "[$PRIMARY_PASSWORD]" \
    3>&1 1>&2 2>&3
}

utils:arch_logo() {
  echo "
            .
           /#\\
          /###\\                     #     | .   __
         /#^###\\       a#e #%' a#'e 6##%  | | |'  | |   | \\ /
        /##P^q##\\    .oOo# #   #    #  #  | | |   | |   |  X
       /##(   )##\\   %OoO# #   %#e' #  #  | | |   | '._.| / \\
      /###P   q##^\\
     /P^         ^q\\
  "
}

# Show welcome message
welcome:show_dialog() {
  message="
$(utils:arch_logo)

Welcome to Arch Linux! Lets get started. Before we begin, let's go
over a few things:

- This installer will not do anything until the end. It's safe to
  navigate this installer's options. There will be a confirmation
  dialog at the end of this process; nothing destructive will be
  done before that.

- Be sure to read the Arch Linux wiki. There's no substitute to
  understanding everything that's happening :)

- Press [Esc] twice at any time to exit this installer.

- Have fun!
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
    $(( $LINES - 6 )) $COLUMNS

  if [[ $? == 0 ]]; then
    app:run_script
  else
    app:abort
  fi
}

# Run the script
app:run_script() {
  clear
  echo ''
  utils:arch_logo
  echo ''
  echo "     Ready! Press [ENTER] to start installation."
  echo ''
  read
  bash "$SCRIPT_FILE"
}

# Write script
script:write() {
  script:write_start
  script:write_fdisk
  script:write_pacstrap
  script:write_end
}

script:write_start() {
  (
    echo '#!/usr/bin/env bash'
    echo "# This file was saved to $SCRIPT_FILE."
    echo "#"
    echo "set -euo pipefail"
    echo ''
  ) > "$SCRIPT_FILE"
  chmod +x "$SCRIPT_FILE"
}

script:write_fdisk() {
  (
    echo "# Partition $FS_DISK"
    echo "("
    echo "  echo g      # Clear everything and start as GPT"
    echo "  echo w      # Write and save"
    echo ") | fdisk $FS_DISK"
    echo "("
    echo "  echo n      # New partition"
    echo "  echo 1      # .. partition number = 1"
    echo "  echo ''     # .. start sector = default"
    echo "  echo +500M  # .. last sector"
    echo "  echo t      # Change type"
    echo "  echo 1      # .. type = 1 (EFI)"
    echo "  echo n      # New partition"
    echo "  echo 2      # .. partition number = 1"
    echo "  echo ''     # .. start sector = default"
    echo "  echo ''     # .. last sector = default"
    echo "  echo t      # Change type"
    echo "  echo 2      # .. partition number = 2"
    echo "  echo 20     # .. Linux filesystem"
    echo "  echo w      # Write and save"
    echo ") | fdisk $FS_DISK"
    echo ''
    echo "# Format EFI"
    echo "mkfs.fat $FS_EFI"
    echo ''
  ) >> "$SCRIPT_FILE"
}

script:write_pacstrap() {
  (
    echo "# Set keyboard layout"
    echo "loadkeys $KEYBOARD_LAYOUT"
    echo ''
    echo "# Enabling syncing clock via ntp"
    echo "timedatectl set-ntp true"
    echo ''
    echo "# Format drives"
    echo "yes | mkfs.ext4 $FS_ROOT"
    echo ''
    echo "# Mount your partitions"
    echo "mount $FS_ROOT /mnt"
    echo "mkdir -p /mnt/boot"
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
    echo "  hwclock --systohc"
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
    echo "  echo 'KEYMAP=$KEYBOARD_LAYOUT' > /etc/vconsole.conf"
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
    # echo "# Set root password"
    # echo "arch-chroot /mnt sh <<END"
    # echo "  echo -e '$ROOT_PASSWORD\\n$ROOT_PASSWORD' | passwd"
    # echo "END"
    # echo ''
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
  ) >> "$SCRIPT_FILE"
}

script:write_end() {
  (
    echo ""
    echo "echo \"┌──────────────────────────────────────────┐\""
    echo "echo \"│ You're done!                             │\""
    echo "echo \"│ Type 'reboot' and remove your USB drive. |\""
    echo "echo \"└──────────────────────────────────────────┘\""
    echo ""
    echo "# Generated by $INSTALLER_TITLE ($INSTALLER_URL)"
  ) >> "$SCRIPT_FILE"
}

# Parse options
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
  ensure_arch
  welcome:show_dialog
  config:system
  config:user
  script:write
  confirm:run
}

app:abort() {
  clear
  echo "Installer aborted"
  exit 1
}

# Lets go!
app:set_defaults
app:start
