#!/usr/bin/env bash
#
# Assert the changes made by this action.
#

shopt -s inherit_errexit
set -eu -o pipefail

source "$(dirname ${BASH_SOURCE[0]})/common.sh"

phase "Asserting the CLI (tkn) is installed"
probe_bin_on_path "tkn"
