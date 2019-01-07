#!/usr/bin/env bash
# Utilities for tests.

test:skip_mocks() {
  export SKIP_ARCHISO_CHECK=1
  export SKIP_EXT4_CHECK=1
  export SKIP_MNT_CHECK=1
  export SKIP_MOUNTED_CHECK=1
  export SKIP_SANITY_CHECK=1
  export SKIP_PARTITION_MOUNT_CHECK=1
  export SKIP_VFAT_CHECK=1
}
