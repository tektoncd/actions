#!/usr/bin/env bash
#
# Download and install the informed tkn version, using "/usr/local/bin" as PREFIX.
#

shopt -s inherit_errexit
set -eu -o pipefail

source "$(dirname ${BASH_SOURCE[0]})/common.sh"

phase "Inspecting enviroment variables"

readonly INPUT_VERSION="${INPUT_VERSION:-}"

[[ -z "${INPUT_VERSION}" ]] &&
    fail "INPUT_VERSION environment variable is not set!"

phase "Searching for '${INPUT_VERSION}' release artifact"

readonly url=$(get_release_artifact_url "tektoncd/cli" ${INPUT_VERSION})

[[ -z "${url}" ]] &&
    fail "Unable to acrquire the release artifact download URL"

phase "Download URL '${url}'"
download_and_install ${url} "tkn"
