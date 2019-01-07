#!/usr/bin/env bash
BASH_ENV="test"
DIR="${0%/*}"

# shellcheck source=../install.sh
source "$DIR/../install.sh"

# shellcheck source=../test/test_utils.sh
source "$DIR/../test/test_utils.sh"

test:skip_mocks

app:infer_defaults() {
  echo "(mock)"
  exit 1
}

main
