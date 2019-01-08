#!/usr/bin/env bash
# shellcheck source=../test/test_utils.sh
source "${0%/*}/../test/test_utils.sh"

# Mock 'lsblk' to show gpt
lsblk() {
  case "$*" in
    "-P -o PATH,PTTYPE")
      echo 'PATH="/dev/sda" PTTYPE="gpt"'
      echo 'PATH="/dev/sda1" PTTYPE="gpt"'
      ;;
    *) FAIL "Unknown args: $*" ;;
  esac
}

if ! sys:is_disk_gpt /dev/sda; then
  FAIL "Expected \$(sys:is_disk_gpt) to return true"
fi

# Mock 'lsblk' to show dos
lsblk() {
  case "$*" in
    "-P -o PATH,PTTYPE")
      echo 'PATH="/dev/sda" PTTYPE="dos"'
      echo 'PATH="/dev/sda1" PTTYPE="dos"'
      ;;
    *) FAIL "Unknown args: $*" ;;
  esac
}

if sys:is_disk_gpt /dev/sda; then
  FAIL "Expected \$(sys:is_disk_gpt) to return false"
fi
