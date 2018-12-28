#!/usr/bin/env bash
# vim:foldmethod=marker:foldmarker={,}
set -eo pipefail

# Default config
app:set_defaults() {
  # Defaults
  KEYBOARD_LAYOUT=${KEYBOARD_LAYOUT:-us}
  PRIMARY_LOCALE="en_US.UTF-8 UTF-8"
  TIMEZONE=${TIMEZONE:-Etc/GMT}

  SYSTEM_HOSTNAME="my-arch"
  PRIMARY_USERNAME="anon"
  PRIMARY_PASSWORD="password1"

  FS_DISK="/dev/sda"
  FS_ROOT="${FS_DISK}2"
  FS_EFI="${FS_DISK}1"

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

  # This variable isn't always available
  LINES="$(tput lines)"
  COLUMNS="$(tput cols)"

  # Dimensions
  WIDTH_LG=$COLUMNS
  WIDTH_SM=60
  WIDTH_MD=72

  SKIP_WELCOME=0
  SKIP_CHECKS=0
  ENABLE_RECIPES=0

  # Where to write the script
  SCRIPT_FILE="$HOME/arch_installer.sh"

  # Where timezones are stored
  ZONES_PATH="/usr/share/zoneinfo"
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

config:system() {
  set +e; while true; do
    choice="$(config:show_system_dialog)"
    case "$?" in
      0)
        case "$choice" in
          Keyboard\ layout)
            choice="$(config:choose_keyboard_layout "$KEYBOARD_LAYOUT")"
            if [[ -n "$choice" ]]; then
              KEYBOARD_LAYOUT="$choice"
              loadkeys "$choice"
            fi
            ;;
          Time\ zone)
            choice="$(config:choose_timezone "$TIMEZONE")"
            if [[ -n "$choice" ]]; then TIMEZONE="$choice"; fi
            ;;
          Locales)
            choice="$(config:choose_locale)"
            if [[ -n "$choice" ]]; then PRIMARY_LOCALE="$choice"; fi
            ;;
        esac
        ;;
      3) break ;; # "Next"
      *) app:abort ;; # "Cancel"
    esac
  done; set -e
}

util:list_drives() {
  # NAME="sda" SIZE="883GB"
  lsblk -I 8 -o "NAME,SIZE" -P -d
}

config:disk() {
  choice="$(config:show_disk_dialog)"
  FS_DISK="$choice"
}

config:show_disk_dialog() {
  pairs=()
  IFS=$'\n'
  while read line; do
    eval "$line"
    pairs+=("/dev/$NAME" "$SIZE")
  done <<< $(util:list_drives)

  $DIALOG "${DIALOG_OPTS[@]}" \
    --title "Disks" \
    --no-cancel \
    --menu "Which disk do you want to install Arch Linux to?" \
    11 $WIDTH_SM 4 \
    ${pairs[*]} \
    3>&1 1>&2 2>&3
}

# Returns (echoes) a timezone. `$1` currently-selected one.
#     config:choose_timezone "Asia/Manila"
config:choose_timezone() {
  active="$1"
  choice="$(form:file_picker \
    "$ZONES_PATH" \
    "Time zone" \
    "Choose your region:"
  )"
  if [[ -z "$choice" ]]; then echo $active; return; fi
  echo $choice
}

# Returns (echoes) a keyboard layout.
config:choose_keyboard_layout() {
  active="$1"
  (
    echo us
    echo uk
    echo dvorak
    echo colemak
    util:list_keymaps
  ) | form:select \
    "Keyboard layout" \
    "$active"
}

# Returns (echoes) a locale.
config:choose_locale() {
  (
    echo "en_US.UTF-8 UTF-8"
    echo "en_GB.UTF-8 UTF-8"
    util:list_locales
  ) | form:multi_select \
    "Locales"
}

# Dropdown
form:select() {
  title="$1"
  active="$2"
  pairs=()
  IFS=$'\n'
  while read line; do
    pairs+=("$line" "$line")
  done

  $DIALOG "${DIALOG_OPTS[@]}" \
    --no-tags \
    --title "$title" \
    --default-item "$active" \
    --menu "" \
    23 $WIDTH_SM 16 \
    ${pairs[*]} \
    3>&1 1>&2 2>&3
}

# Multi-select dropdown
form:multi_select() {
  title="$1"
  active="$2"
  pairs=()
  IFS=$'\n'
  while read line; do
    status=off
    if [[ "${active[@]}" =~ "${line}" ]]; then status=on; fi
    pairs+=("$line" "$line" $status)
  done

  $DIALOG "${DIALOG_OPTS[@]}" \
    --no-tags \
    --separate-output \
    --title "$title" \
    --checklist "Press [SPACE] to select/deselect." \
    23 $WIDTH_SM 16 \
    ${pairs[*]} \
    3>&1 1>&2 2>&3
}

# A file picker dialog of sorts
#     form:file_picker /path/to "Title" "Pick a file:"
form:file_picker() {
  root="$1"
  title="$2"
  body="$3"
  depth="0"
  result=""

  while true; do
    choice="$(form:file_picker_dialog "$root" "$title" "$body" "$depth")"
    if [[ $? != 0 ]]; then
      return 1
    fi
    result="${result}${choice}"
    if [[ -f "$root/$choice" ]]; then
      break
    else
      root="$root/$choice"
    fi
    depth="$(( $depth + 1 ))"
  done
  echo "$result"
}

# Delegate function of form:file_picker
form:file_picker_dialog() {
  root="$1"
  title="$2"
  body="$3"
  depth="$4"

  pairs=()
  for entry in "$root"/*; do
    # For the first-level, ignore non-files.
    if [[ $depth == 0 ]] && [[ ! -d "$entry" ]]; then continue; fi
    if [[ -d "$entry" ]]; then entry="$entry/"; fi

    # Strip the root from it
    entry=${entry#$root/}

    # These directories should be ignored for timezones
    if [[ "$entry" == "right/" ]]; then continue; fi
    if [[ "$entry" == "posix/" ]]; then continue; fi

    pairs+=("$entry" "$entry")
  done

  $DIALOG "${DIALOG_OPTS[@]}" \
    --no-tags \
    --title "$title" \
    --menu "$body" \
    23 $WIDTH_SM 16 \
    ${pairs[*]} \
    3>&1 1>&2 2>&3
}

# List available keymaps
util:list_keymaps() {
  find /usr/share/kbd/keymaps -type f -exec basename '{}' '.map.gz' \; | sort
}

# List available locales
util:list_locales() {
  cat /etc/locale.gen | grep -e '^#[a-zA-Z]' | sed 's/^#//g' | sed 's/ *$//g'
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
    10 $WIDTH_SM \
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
    "Locales" "[$(echo "${PRIMARY_LOCALE}" | xargs echo)]" \
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
              "This is how your system will identify itself in networks. Think of this like the name of your computer.")
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
              "Password for your primary user. (You can always change this later!)"
            )
            ;;
        esac
        ;;
      3) break ;; # "Next"
      *) app:abort ;; # "Cancel"
    esac
  done; set -e
}

# Let the user pick recipes they want
config:recipes() {
  config:show_recipes_dialog
}

config:show_recipes_dialog() {
  $DIALOG "${DIALOG_OPTS[@]}" \
    --separate-output \
    --no-cancel \
    --ok-label "Next" \
    --title "Extras" \
    --checklist "Pick some other extras to install\nPress [SPACE] to select/deselect." \
    15 $WIDTH_MD 8 \
    "grub" "Install GRUB boot loader (recommended)" on \
    "sudo" "Install sudo (recommended)" on \
    "base-devel" "Install base-devel" off \
    "yay" "Install yay the AUR helper" off \
    3>&1 1>&2 2>&3
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
    --ok-label "Next" \
    --msgbox "$message" \
    "$(( $LINES - 8 ))" $WIDTH_MD
}

# Confirm
confirm:run() {
  choice="$(confirm:show_confirm_dialog)"
  echo $choice
  case "$choice" in
    I | Install\ now) app:run_script ;;
    R | Review) confirm:show_script_dialog; confirm:run ;;
    *) app:abort ;;
  esac
}

confirm:show_script_dialog() {
  $DIALOG "${DIALOG_OPTS[@]}" \
    --title "Install script" \
    --scrollbar \
    --backtitle "You are now ready to install! Review the install script below." \
    --textbox "$SCRIPT_FILE" \
    $(( $LINES - 6 )) $WIDTH_LG
}

confirm:show_confirm_dialog() {
  $DIALOG "${DIALOG_OPTS[@]}" \
    --title "We're ready!" \
    --no-cancel \
    --menu \
    "We're ready to install!\n[R]eview the install script first before you [I]nstall." \
    11 $WIDTH_SM 3 \
    "Review" "" \
    "Install now" "" \
    "Exit" "" \
    3>&1 1>&2 2>&3
}

# Run the script
app:run_script() {
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
    echo "# (Hint: edit /etc/pacman.d/mirrorlist first to speed this up)"
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
    (
      IFS=$'\n'
      for locale in ${PRIMARY_LOCALE[*]}; do
      echo "  echo '$locale' >> /etc/locale.gen"
      done
    )
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
    recipes:setup_grub
    recipes:create_user
    recipes:install_sudo
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

# Recipe for setting up grub
recipes:setup_grub() {
  echo ''
  echo "# GRUB boot loader"
  echo "arch-chroot /mnt sh <<END"
  echo "  pacman -Syu --noconfirm grub efibootmgr"
  echo "  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB"
  echo "  grub-mkconfig -o /boot/grub/grub.cfg"
  echo "END"
}

# Recipe for creating user
recipes:create_user() {
  echo ''
  echo "# Create your user"
  echo "arch-chroot /mnt sh <<END"
  echo "  useradd -Nm -g users -G wheel,sys $PRIMARY_USERNAME"
  echo "  echo -e '$PRIMARY_PASSWORD\\n$PRIMARY_PASSWORD' | passwd $PRIMARY_USERNAME"
  echo "END"
}

# Recipe for installing sudo
recipes:install_sudo() {
  echo ''
  echo "# Set up sudo"
  echo "arch-chroot /mnt sh <<END"
  echo "  pacman -Syu --noconfirm sudo"
  echo "  echo '%wheel ALL=(ALL:ALL) ALL' | sudo EDITOR='tee -a' visudo"
  echo "END"
}
# Parse options
app:parse_options() {
  while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
    --vip)
      # Use this only for tests!
      SKIP_WELCOME=1
      SKIP_CHECKS=1
      ;;
    --skip-welcome)
      SKIP_WELCOME=1
      ;;
    --dev)
      # Developer options
      ENABLE_RECIPES=1
      ;;
    # -V | --version )
    #   echo version
    #   exit
    #   ;;
    # -s | --string )
    #   shift; string=$1
    #   ;;
  esac; shift; done
  if [[ "$1" == '--' ]]; then shift; fi
}

# Start everything
app:start() {
  app:parse_options "$*"

  if [[ "$SKIP_CHECKS" != 1 ]]; then
    ensure_efi
    ensure_online
    ensure_arch
  fi

  if [[ "$SKIP_WELCOME" != 1 ]]; then
    welcome:show_dialog
  fi

  config:system
  config:disk
  config:user
  if [[ "$ENABLE_RECIPES" == 1 ]]; then
     config:recipes
  fi
  script:write
  confirm:run
}

app:abort() {
  clear
  echo ""
  if [[ -f "$SCRIPT_FILE" ]]; then
    cd "$(dirname "$SCRIPT_FILE")"
    echo "You finally proceed with the installation via:"
    echo ""
    echo "  ./$(basename "$SCRIPT_FILE")"
    echo ""
    echo "Feel free to edit it and see if everything is in order!"
    echo ""
  fi
  exit 1
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

# Lets go!
app:set_defaults
app:start "$*"
