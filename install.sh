#!/usr/bin/env bash
# vim:foldmethod=marker:foldmarker={,}
set -eo pipefail

# Default config / global state
set_defaults() {
  # Defaults
  KEYBOARD_LAYOUT=${KEYBOARD_LAYOUT:-us}
  PRIMARY_LOCALE="en_US.UTF-8 UTF-8"
  TIMEZONE=${TIMEZONE:-Etc/GMT}

  SYSTEM_HOSTNAME="my-arch"
  PRIMARY_USERNAME="anon"
  PRIMARY_PASSWORD="password1"

  FS_DISK="/dev/sda"
  FS_ROOT="$FS_DISK""2"
  FS_EFI="$FS_DISK""1"

  # If this is 1, don't mount stuff, just use /mnt as is.
  FS_USE_MNT=0

  # Wipe the disk?
  FS_DO_FDISK=0

  INSTALLER_TITLE="Arch Linux Installer"
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

  # Skip flags
  SKIP_WELCOME=0
  SKIP_EXT4_CHECK=0
  SKIP_VFAT_CHECK=0
  SKIP_MNT_CHECK=0
  SKIP_ARCHISO_CHECK=0
  SKIP_SANITY_CHECKS=0
  ENABLE_RECIPES=0

  # Where to write the script
  SCRIPT_FILE="$HOME/arch_installer.sh"
}

set_constants() {
  # Where timezones are stored
  ZONES_PATH="/usr/share/zoneinfo"

  # If keyboard layout matches this, supress setting it
  DEFAULT_KEYBOARD_LAYOUT="us"

  # Label for skipping a boot loader
  NO_BOOTLOADER="Skip"

  # Installer URL
  INSTALLER_URL="https://github.com/rstacruz/arch-installer"

  # Where the ESP partition is to be mounted
  ESP_PATH="/boot"

  EDITOR=${EDITOR:-nano}
}

# Start everything
main() {
  app:parse_options "$*"

  if [[ "$SKIP_SANITY_CHECKS" != 1 ]]; then
    check:ensure_pacman
    check:ensure_available_utils
    check:ensure_efi
    check:ensure_online
  fi

  if [[ "$SKIP_ARCHISO_CHECK" != 1 ]]; then
    check:ensure_hostname
  fi

  if [[ "$SKIP_WELCOME" != 1 ]]; then
    welcome:show_dialog
  fi

  # Configure the disk first
  config:disk

  # (FS_ROOT will be blank if /mnt is to be used.)
  if [[ "$FS_USE_MNT" == "0" ]] && [[ "$FS_ROOT" == "$FS_EFI" ]]; then
    quit:invalid_partition_selection
  fi

  # Configure locales and such
  config:system

  # Configure your user
  config:user

  # Write the script, then show debriefing dialogs
  script:write
  confirm:run
}

# -------------------------------------------------------------------------------

# Ensures that the system is booted in UEFI mode, and not
# Legacy mode. Exits the installer if it fails.
check:ensure_efi() {
  if [[ ! -d /sys/firmware/efi/efivars ]]; then
    quit:not_efi
  fi
}

# Exits the installer if were offline.
check:ensure_online() {
  if ! ping -c 1 -W 1 8.8.8.8 &>/dev/null; then
    echo "You don't seem to be online."
    exit 1
  fi
}

check:ensure_hostname() {
  if [[ "$(hostname)" != "archiso" ]]; then
    quit:wrong_hostname
  fi
}

check:ensure_available_utils() {
  check:ensure_util util-linux mount
  check:ensure_util util-linux lsblk
  check:ensure_util dialog dialog
  check:ensure_util arch-install-scripts arch-chroot
  check:ensure_util arch-install-scripts pacstrap
}

check:ensure_util() {
  local pkg="$1"
  local exec="$2"
  if ! which "$exec" &>/dev/null; then
    quit:missing_util "$exec" "$pkg"
  fi
}

# Ensure that Pacman is installed.
check:ensure_pacman() {
  if [[ ! -e /etc/pacman.d/mirrorlist ]]; then
    quit:not_arch
  fi
}

# Ensure there are available partitions.
check:ensure_valid_partitions() {
  disk="$1"
  if [[ "$SKIP_EXT4_CHECK" == 0 ]]; then
    if ! util:disk_has_partition "$disk" "ext4"; then
      quit:no_ext4
    fi
  fi

  if [[ "$SKIP_VFAT_CHECK" == 0 ]]; then
    if ! util:disk_has_partition "$disk" "vfat"; then
      quit:no_vfat
    fi
  fi
}

# -------------------------------------------------------------------------------

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
      *) quit:exit ;; # "Cancel"
    esac
  done; set -e
}

config:disk() {
  strategy="$(config:show_partition_strategy_dialog)"
  case "$strategy" in
    Partition*)
      quit:cfdisk
      ;;
    Wipe*)
      choice="$(config:show_disk_dialog)"
      FS_DISK="$choice"
      FS_DO_FDISK=1
      ;;
    Use\ /mnt*)
      if ! util:is_mnt_mounted; then quit:mnt_not_mounted; fi
      config:warn_dialog
      $DIALOG "${DIALOG_OPTS[@]}" \
        --msgbox "/mnt will be used as is. You'll also need to set up a boot loader yourself." 10 40
      FS_USE_MNT=1
      FS_ROOT=""
      FS_EFI=""
      ;;
    Format*)
      choice="$(config:show_disk_dialog)"
      FS_DISK="$choice"

      # Are they the same?
      check:ensure_valid_partitions "$FS_DISK"

      # Pick EFI partition
      choice="$(config:show_partition_dialog \
        "$FS_DISK" \
        "Linux partition" \
        "Choose partition to install Linux into:\n(This is usually an 'ext4' partition.)")"
      FS_ROOT="$choice"

      # Pick Linux partition
      choice="$(config:show_partition_dialog \
        --null "$NO_BOOTLOADER" "Don't install a boot loader" \
        "$FS_DISK" \
        "EFI Partition" \
        "Choose partition to install the EFI boot loader into:")"
      FS_EFI="$choice"
      ;;
  esac
}

config:show_partition_strategy_dialog() {
  local title="How do you want to install Arch Linux on your drive?"

  $DIALOG "${DIALOG_OPTS[@]}" \
    --title "Choose disk strategy" \
    --no-cancel \
    --menu "\n$title\n " \
    14 $WIDTH_MD 4 \
    "Wipe drive" "Wipe my drive completely." \
    "Format partitions" "I've already partitioned my disks." \
    "Partition manually" "Let me partition my disk now." \
    "Use /mnt" "(Advanced) Use whatever is mounted on /mnt." \
    3>&1 1>&2 2>&3
}

config:show_disk_dialog() {
  pairs=()
  IFS=$'\n'
  while read line; do
    eval "$line"
    pairs+=("/dev/$NAME" "$SIZE")
  done <<< $(util:list_drives)

  message="\n"
  message+="Let's get started!\n"
  message+="Which disk do you want to install Arch Linux to?"
  message+=" "

  $DIALOG "${DIALOG_OPTS[@]}" \
    --title "Disks" \
    --no-cancel \
    --menu "$message" \
    14 $WIDTH_SM 4 \
    ${pairs[*]} \
    3>&1 1>&2 2>&3
}

# Lets the user select a partition
config:show_partition_dialog() {
  local null_tag=
  local null_label=

  if [[ "$1" == "--null" ]]; then
    shift; null_tag="$1"; shift; null_label="$1"; shift
  fi

  local disk="$1"
  local title="$2"
  local body="$3"
  local pairs=()

  # Add partition to `$pairs`
  IFS=$'\n'
  while read line; do
    eval "$line"
    label="$(printf "[%8s]  %s - %s" "$SIZE" "$FSTYPE" "${LABEL:-No label}")"
    pairs+=("/dev/$NAME" "$label")
  done <<< $(util:list_partitions "$disk")

  # If `--null` is passed, add that option at the end
  if [[ -n "$null_tag" ]]; then
    pairs+=("$null_tag" "$null_label")
  fi

  $DIALOG "${DIALOG_OPTS[@]}" \
    --title "$title" \
    --no-cancel \
    --ok-label "Use" \
    --menu "\n$body\n " \
    17 $WIDTH_SM 8 \
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

# -------------------------------------------------------------------------------

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

# -------------------------------------------------------------------------------

# List available keymaps
util:list_keymaps() {
  find /usr/share/kbd/keymaps -type f -exec basename '{}' '.map.gz' \; | sort
}

# List available locales
util:list_locales() {
  cat /etc/locale.gen | grep -e '^#[a-zA-Z]' | sed 's/^#//g' | sed 's/ *$//g'
}

# Check if a disk has a given partition of given type
#     if util:disk_has_partition /dev/sda1 ext4; then ...
util:disk_has_partition() {
  disk="$1"
  fstype="$2"
  lsblk -I 8 -o "NAME,SIZE,TYPE,FSTYPE,LABEL" -P \
    | grep 'TYPE="part"' \
    | grep "$(basename $disk)" \
    | grep "FSTYPE=\"$fstype\"" \
    &>/dev/null
}

# -------------------------------------------------------------------------------

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
  message="\nYou can <Change> any of these settings. Move to the <Next> screen when you're done.\n "
  $DIALOG "${DIALOG_OPTS[@]}" \
    --title "Locales" \
    --no-cancel \
    --ok-label "Change" \
    --extra-button \
    --extra-label "Next" \
    --menu "$message" \
    14 $WIDTH_SM 3 \
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
          System\ hostname)
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
      *) quit:exit ;; # "Cancel"
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
    --checklist "Pick some other extras to install\nPress (Space) to select/deselect." \
    15 $WIDTH_LG 8 \
    "base-devel" "Install base-devel" off \
    "yay" "Install yay, the AUR helper" off \
    "networkmanager" "Install NetworkManager" off \
    3>&1 1>&2 2>&3
}

# Config: Show user dialog
config:show_user_dialog() {
  message="\nTell me about the user you're going to use day-to-day.\n "
  $DIALOG "${DIALOG_OPTS[@]}" \
    --title "Configure your user" \
    --no-cancel \
    --no-shadow \
    --ok-label "Change" \
    --extra-button \
    --extra-label "Next" \
    --menu "$message"\
    13 $WIDTH_SM 3 \
    "System hostname" "[$SYSTEM_HOSTNAME]" \
    "Your username" "[$PRIMARY_USERNAME]" \
    "Your password" "[$PRIMARY_PASSWORD]" \
    3>&1 1>&2 2>&3
}

# -------------------------------------------------------------------------------

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

- Press [Esc] twice at any time to exit this installer.

- Be sure to read the Arch Linux wiki. There's no substitute to
  understanding everything that's happening :)

  $INSTALLER_URL
  "
  $DIALOG "${DIALOG_OPTS[@]}" \
    --ok-label "Next" \
    --msgbox "$message" \
    "$(( $LINES - 8 ))" $WIDTH_MD
}

# -------------------------------------------------------------------------------

# Confirmation step
confirm:run() {
  choice="$(confirm:show_confirm_dialog)"
  case "$choice" in
    Install*) app:run_script ;;
    Review*) confirm:show_script_dialog; confirm:run ;;
    Additional*) config:recipes; script:write; confirm:run ;;
    *) quit:exit ;;
  esac
}

confirm:show_script_dialog() {
  "$EDITOR" "$SCRIPT_FILE"
}

confirm:show_confirm_dialog() {
  local message="\n"
  message+="We're ready to install!\n"
  message+="You can now (I)nstall a minimal Arch Linux system. "
  message+="We recommend (R)eviewing the install script before proceeding.\n"
  message+=" "

  local recipe_opts=("Additional options" "")
  if [[ "$ENABLE_RECIPES" != 1 ]]; then recipe_opts=(); fi
  
  $DIALOG "${DIALOG_OPTS[@]}" \
    --title "Install now" \
    --no-cancel \
    --menu "$message" \
    17 $WIDTH_SM 4 \
    "Install now" "" \
    "Review script" "" \
    "${recipe_opts[@]}" \
    "Exit installer" "" \
    3>&1 1>&2 2>&3
}

# -------------------------------------------------------------------------------

# Run the script
app:run_script() {
  # Only proceed if we're root.
  if [[ $(id -u) != "0" ]]; then quit:exit; return; fi

  # Clear the screen, and make sure any ANSI garbage is cleaned up
  clear
  reset
  clear

  bash "$SCRIPT_FILE"
}

# -------------------------------------------------------------------------------

# Write script
script:write() {
  script:write_start

  if [[ "$FS_DO_FDISK" == "1" ]]; then
    script:write_fdisk
  fi

  script:write_pacstrap
  script:write_recipes
  script:write_end
}

script:write_start() {
  (
    echo '#!/usr/bin/env bash'
    echo "#"
    echo "#  ------------------------------------------------------------------"
    echo "#  Please review the install script below. After you exit out of your"
    echo "#  editor, Arch Linux will begin to install."
    echo "#  ------------------------------------------------------------------"
    echo "#  This file was saved to $SCRIPT_FILE."
    echo "#  ------------------------------------------------------------------"
    echo "#"
    echo "set -euo pipefail"
    echo '::() { echo -e "\n\033[0;1m==>\033[1;32m" "$*""\033[0m"; }'
    echo 'if [[ "$(id -u)" != 0 ]]; then :: "No root priviledges."; exit 1; fi'
    echo ''
  ) > "$SCRIPT_FILE"
  chmod +x "$SCRIPT_FILE"
}

script:write_fdisk() {
  (
    echo ":: 'Wiping disk $FS_DISK'"
    echo "("
    echo "  echo g      # Clear everything and start as GPT"
    echo "  echo w      # Write and save"
    echo ") | fdisk $FS_DISK"
    echo ""
    echo ":: 'Creating partitions in $FS_DISK'"
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
    echo ":: 'Formating ESP partition $FS_EFI'"
    echo "mkfs.fat $FS_EFI"
    echo ''
  ) >> "$SCRIPT_FILE"
}

script:write_pacstrap() {
  (
    echo ":: 'Enabling clock syncing via ntp'"
    echo "timedatectl set-ntp true"
    echo ''
    if [[ "$FS_USE_MNT" == "1" ]]; then
      echo ":: 'Using /mnt'"
      echo '# Not mounting any drives, assuming /mnt is already available.'
      echo ''
    else
      echo ":: 'Formating primary partition $FS_ROOT'"
      echo "mkfs.ext4 $(esc "$FS_ROOT")"
      echo ''
      echo ":: 'Mounting partitions'"
      echo "mount $FS_ROOT /mnt"
      if [[ "$FS_EFI" != "$NO_BOOTLOADER" ]]; then
        echo "mkdir -p /mnt$ESP_PATH"
        echo "mount $FS_EFI /mnt$ESP_PATH"
      fi
      echo ''
    fi
    echo ":: 'Starting pacstrap installer'"
    echo "# (Hint: edit /etc/pacman.d/mirrorlist first to speed this up)"
    echo "pacstrap /mnt base"
    echo ''
    echo ":: 'Generating fstab'"
    echo "genfstab -U /mnt >> /mnt/etc/fstab"
    echo ''
    echo ":: 'Setting timezone'"
    echo "arch-chroot /mnt sh <<END"
    echo "  ln -sf /usr/share/zoneinfo/$(esc "$TIMEZONE") /etc/localtime"
    echo "  hwclock --systohc"
    echo "END"
    echo ''
    echo ":: 'Setting locales'"
    echo "arch-chroot /mnt sh <<END"
    (
      IFS=$'\n'
      for locale in ${PRIMARY_LOCALE[*]}; do
        echo "  echo $(esc "$locale") >> /etc/locale.gen"
      done
      echo "  echo LANG=$(esc $(util:get_primary_locale)) > /etc/locale.conf"
    )
    echo "  locale-gen"
    echo "END"
    echo ''
    if [[ "$KEYBOARD_LAYOUT" != "$DEFAULT_KEYBOARD_LAYOUT" ]]; then
      echo ":: 'Making keyboard layout persist on boot'"
      echo "arch-chroot /mnt sh <<END"
      echo "  echo KEYMAP=$(esc "$KEYBOARD_LAYOUT") > /etc/vconsole.conf"
      echo "END"
      echo ''
    fi
    echo ":: 'Setting hostname'"
    echo "arch-chroot /mnt sh <<END"
    echo "  echo $(esc "$SYSTEM_HOSTNAME") > /etc/hostname"
    echo "  echo '127.0.0.1 localhost' >> /etc/hosts"
    echo "  echo '::1 localhost' >> /etc/hosts"
    echo "  echo '127.0.1.1 $SYSTEM_HOSTNAME.localdomain $SYSTEM_HOSTNAME' >> /etc/hosts"
    echo "END"
  ) >> "$SCRIPT_FILE"
}

script:write_recipes() {
  (
    if [[ "$FS_EFI" != "$NO_BOOTLOADER" ]]; then
      recipes:setup_grub
    fi
    recipes:create_user
    recipes:install_sudo
  ) >> "$SCRIPT_FILE"
}

script:write_end() {
  (
    echo ""
    echo "echo \"  ┌──────────────────────────────────────────┐\""
    echo "echo \"  │ You're done!                             │\""
    echo "echo \"  │ Type 'reboot' and remove your USB drive. |\""
    echo "echo \"  └──────────────────────────────────────────┘\""
    echo ""
    echo "# Generated by $INSTALLER_TITLE ($INSTALLER_URL)"
  ) >> "$SCRIPT_FILE"
}

# -------------------------------------------------------------------------------

# Recipe for setting up grub
recipes:setup_grub() {
  echo ''
  echo ":: 'Installing GRUB boot loader'"
  echo "arch-chroot /mnt sh <<END"
  echo "  pacman -Syu --noconfirm grub efibootmgr"
  echo "  grub-install --target=x86_64-efi --efi-directory=$ESP_PATH --bootloader-id=GRUB"
  echo "  grub-mkconfig -o $ESP_PATH/grub/grub.cfg"
  echo "END"
}

# Recipe for creating user
recipes:create_user() {
  echo ''
  echo ":: 'Creating user $(esc "$PRIMARY_USERNAME")'"
  echo "arch-chroot /mnt sh <<END"
  echo "  useradd -Nm -g users -G wheel,sys $(esc "$PRIMARY_USERNAME")"
  echo "  echo -e $(esc "$PRIMARY_PASSWORD")\"\\n\"$(esc "$PRIMARY_PASSWORD") | passwd $(esc "$PRIMARY_USERNAME")"
  echo "END"
}

# Recipe for installing sudo
recipes:install_sudo() {
  echo ''
  echo ":: 'Setting up sudo'"
  echo "arch-chroot /mnt sh <<END"
  echo "  pacman -Syu --noconfirm sudo"
  echo "  echo '%wheel ALL=(ALL) ALL' | sudo EDITOR='tee -a' visudo"
  echo "END"
}

# Install yay, the aur helper
# this doesn't work right now lol
recipes:install_yay() {
  echo ''
  echo ":: 'Setting up yay'"
  echo "# https://github.com/Jguer/yay"
  echo "arch-chroot /mnt sh <<END"
  echo "  pacman -Syu --noconfirm --needed git base-devel"
  echo "  rm -rf yay-bin"
  echo "  git clone https://aur.archlinux.org/yay-bin.git"
  echo "  chown -R $(esc "$PRIMARY_USERNAME") yay-bin"
  echo "  cd yay-bin"
  echo "  su $(esc "$PRIMARY_USERNAME") makepkg"
  echo "  pacman -U yay-bin*"
  echo "END"
}

# -------------------------------------------------------------------------------

# Parse options
app:parse_options() {
  while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
    --vip)
      # Go through the VIP entrance and skip some checkpoints.
      # Use this only for testing purposes!
      SKIP_VFAT_CHECK=1
      SKIP_EXT4_CHECK=1
      SKIP_ARCHISO_CHECK=1
      SKIP_MNT_CHECK=1
      SKIP_SANITY_CHECKS=1
      ;;
    --skip-mnt-check) SKIP_MNT_CHECK=1 ;;
    --skip-sanity-check) SKIP_SANITY_CHECKS=1 ;;
    --skip-archiso-check) SKIP_ARCHISO_CHECK=1 ;;
    --skip-welcome) SKIP_WELCOME=1 ;;
    --skip-vfat-check) SKIP_VFAT_CHECK=1 ;;
    --skip-ext4-check) SKIP_EXT4_CHECK=1 ;;
    # Developer options
    --dev) ENABLE_RECIPES=1 ;;
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

# -------------------------------------------------------------------------------

# Quit and exit
quit:exit() {
  local cmd="./$(basename "$SCRIPT_FILE")"
  if [[ "$(pwd)" != "$(dirname "$SCRIPT_FILE")" ]]; then cmd="cd ; $cmd"; fi
  quit:exit_msg <<END
  You can proceed with the installation via:

      $cmd

  Feel free to edit it and see if everything is in order!
END
}

quit:exit_msg() {
  clear
  echo -e "\033[0;33m$INSTALLER_TITLE\033[0;m"
  echo -e "\033[0;33m$(printf "%${COLUMNS}s" | tr ' ' '-')\033[0;m"
  echo ""
  cat -
  echo ""
  exit 1
}

quit:mnt_not_mounted() {
  quit:exit_msg <<END
  Please mount partitions manually into /mnt.

  This option is available if you would like full control over your
  filesystems. This is great for special setups like btrfs, encryption,
  and other needs.

  It doesn't seem like anything is mounted into /mnt yet. You may
  need to partition your drive, format the partitions, and mount
  them manually. An example would be:

      # (Just an example, don't follow this exactly!)
      mkfs.vfat -F32 /dev/sda1
      mkfs.ext4 /dev/sda2
      mount /dev/sda1 /mnt/boot
      mount /dev/sda2 /mnt

  The Arch wiki has a guide:

      https://wiki.archlinux.org/index.php/installation_guide#Partition_the_disks

  Run the installer again after mounting into /mnt.

  (You can skip this check with '--skip-mnt-check'.)
END
}

quit:not_arch() {
  quit:exit_msg <<END
  Arch Linux is required.

  The Arch installer is meant to be run from the Arch Linux
  Live environment. You can download Arch Linux from the Arch
  Linux website.

      https://archlinux.org/downloads/

  Also check the Arch Installer website for more details.

      $INSTALLER_URL

  Also check the Arch Installer website for more details.
END
}

quit:wrong_hostname() {
  quit:exit_msg <<END
  You seem to be running the installer on something that
  isn't the Arch Linux live enviroment.
  
  The Arch installer is meant to be run from the Arch Linux
  Live environment. You can download Arch Linux from the Arch
  Linux website.

      https://archlinux.org/downloads/

  Also check the Arch Installer website for more details.

      $INSTALLER_URL

  (You can skip this check with '--skip-archiso-check'.)
END
}

quit:missing_util() {
  quit:exit_msg <<END
  '$1' is needed to install Arch Linux.

  The Arch installer is meant to be run from the Arch Linux
  Live environment. You can download Arch Linux from the Arch
  Linux website.

      https://archlinux.org/downloads/

  If you're trying to run this installer from within Arch Linux,
  you may need to install the '$2' package.

      sudo pacman -Syu $2
END
}

quit:not_efi() {
  quit:exit_msg <<END
  The Arch installer only supports EFI mode.
  
  There doesn't seem to be efivars present in your /sys.
  Your system is likely booted in legacy mode at the moment.
  Consider turning on UEFI mode in your BIOS settings.

  If you'd like to continue in Legacy mode, you may install
  Arch Linux manually:

      https://wiki.archlinux.org/Installation
END
}

# Show 'please run cfdisk' message and exit
quit:cfdisk() {
  quit:exit_msg <<END
  You can partition your disk by typing:

      cfdisk

  Run the installer again afterwards, and pick 'Use existing' when
  asked to partition your disk.
END
}

quit:invalid_partition_selection() {
  quit:exit_msg <<END
  The Linux partition can't be the same as the EFI partition.
END
}

# Show 'no ext4 partition' error message and exit
quit:no_ext4() {
  clear
  echo "You don't seem to have an 'ext4' partition in '$disk' yet."
  echo "You may need to partition your disk before continuing."
  echo ""
  lsblk -o "NAME,FSTYPE,LABEL,SIZE" "$disk" | sed 's/^/    /g'
  echo ""
  echo "Linux is usually installed into an ext4 partition. See the"
  echo "Arch wiki for details:"
  echo ""
  echo "    https://wiki.archlinux.org/index.php/Installation_guide#Partition_the_disks"
  echo ""
  echo "(You can skip this check with '--skip-ext4-check'.)"
  exit 1
}

# Show 'no vfat partition' error message and exit
quit:no_vfat() {
  clear
  echo "You don't seem to have an 'vfat' partition in '$disk' yet."
  echo "You may need to partition your disk before continuing."
  echo ""
  lsblk -o "NAME,FSTYPE,LABEL,SIZE" "$disk" | sed 's/^/    /g'
  echo ""
  echo "You will need an EFI partition. See the Arch wiki for details:"
  echo ""
  echo "    https://wiki.archlinux.org/index.php/EFI_system_partition"
  echo ""
  echo "Read the guide above, partition your disk with 'cfdisk' and run"
  echo "the installer again."
  echo ""
  echo "(You can skip this check with '--skip-vfat-check'.)"
  echo ""
  exit 1
}

# -------------------------------------------------------------------------------

# Dev helpers: List available drives
util:list_drives() {
  # NAME="sda" SIZE="883GB"
  lsblk -I 8 -o "NAME,SIZE" -P -d
}

# Dev helpers: List available partitions
util:list_partitions() {
  disk="$1"
  # NAME="sda1" SIZE="883GB"
  lsblk -I 8 -o "NAME,SIZE,TYPE,FSTYPE,LABEL" -P \
    | grep 'TYPE="part"' \
    | grep "$(basename $disk)"
}

# "en_US.UTF-8 UTF-8" -> "en_US.UTF-8"
util:get_primary_locale() {
  local str="${PRIMARY_LOCALE[0]}"
  echo "${str% *}"
}

util:is_mnt_mounted() {
  if [[ "$SKIP_MNT_CHECK" == 1 ]]; then return; fi

  # Grep returns non-zero if it's not found
  lsblk -o 'MOUNTPOINT' | grep '/mnt' &>/dev/null
}

# Random utils
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

esc() {
  printf "%q" "$1"
}

# -------------------------------------------------------------------------------

# Lets go!
set_defaults
set_constants
main "$*"
