#!/usr/bin/env bash
# Utilities for tests.

# Prevent script from executing,
# making install.sh inert.
export BASH_ENV="test"

test:skip_mocks() {
  export SKIP_ARCHISO_CHECK=1
  export SKIP_EXT4_CHECK=1
  export SKIP_MNT_CHECK=1
  export SKIP_MOUNTED_CHECK=1
  export SKIP_SANITY_CHECK=1
  export SKIP_PARTITION_MOUNT_CHECK=1
  export SKIP_VFAT_CHECK=1
}

FAIL() {
  msg="$1"
  echo "Test failure: $msg" 1>&2
  exit 1
}

LOG() {
  echo "$*" 1>&2
}

# shellcheck source=../install.sh
source "${0%/*}/../install.sh"
