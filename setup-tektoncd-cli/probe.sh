#!/usr/bin/env bash
#
# Inspect the instance to make sure the dependencies needed are in place.
#

shopt -s inherit_errexit
set -eu -o pipefail

source "$(dirname ${BASH_SOURCE[0]})/common.sh"

probe_bin_on_path "curl"
probe_bin_on_path "jq"
probe_bin_on_path "tar"
