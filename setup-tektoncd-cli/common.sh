#
# Helper Functions
#

# print error message and exit on error.
function fail() {
    echo "ERROR: ${*}" >&2
    exit 1
}

# print out a strutured message.
function phase() {
    echo "---> Phase: ${*}..."
}

# inspect the path after the informed executable name.
function probe_bin_on_path() {
    local name="${1}"

    if ! type -a ${name} >/dev/null 2>&1; then
        fail "Can't find '${name}' on 'PATH=${PATH}'"
    fi
}

# helper to build curl auth headers when GITHUB_TOKEN is available.
function _gh_curl() {
    local _curl_args=(-s -f)
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        _curl_args+=(-H "Authorization: token ${GITHUB_TOKEN}")
    fi
    local _response
    if ! _response=$(curl "${_curl_args[@]}" "$@" 2>&1); then
        fail "GitHub API request failed for '$*'. Response: ${_response}. If this is a rate-limit error, set the 'github_token' input."
    fi
    echo "${_response}"
}

# get the artifact url for the specific version (release) or latest.
function get_release_artifact_url() {
    local _org_repo="${1}"
    local _version="${2}"

    local _url="https://api.github.com/repos/${_org_repo}/releases"
    local _response
    if [[ "${_version}" == "latest" ]]; then
        _response=$(_gh_curl "${_url}/latest")
    else
        _response=$(_gh_curl "${_url}")
    fi

    # check for API error messages
    if echo "${_response}" | jq -e '.message' &>/dev/null; then
        local _msg
        _msg=$(echo "${_response}" | jq -r '.message')
        fail "GitHub API error: ${_msg}. If this is a rate-limit error, set the 'github_token' input."
    fi

    local _artifact_url
    if [[ "${_version}" == "latest" ]]; then
        _artifact_url=$(
            echo "${_response}" |
                jq -r '.assets[].browser_download_url' |
                egrep -i 'linux_(x86_64|amd64)' |
                head -n 1
        )
    else
        _artifact_url=$(
            echo "${_response}" |
                jq -r ".[] | select(.tag_name == \"${_version}\") | .assets[].browser_download_url" |
                egrep -i 'linux_(x86_64|amd64)' |
                head -n 1
        )
    fi

    if [[ -z "${_artifact_url}" ]]; then
        fail "Could not find release artifact for ${_org_repo} version '${_version}'"
    fi

    echo "${_artifact_url}"
}

# given the download url and excutable name, download and extract the executable from the artifact
# tarball on the `/usr/local/bin` (prefix).
function download_and_install() {
    local _url="${1}"
    local _bin_name="${2}"

    local _tarball="$(basename ${_url})"
    local _tmp_tarball="/tmp/${_tarball}"
    local _prefix="/usr/local/bin"

    [[ -f "${_tmp_tarball}" ]] && rm -f "${_tmp_tarball}"

    phase "Downloading '${_url}' to '${_tmp_tarball}'"
    curl -sL ${_url} >${_tmp_tarball}

    phase "Installing '${_bin_name}' on prefix '${_prefix}'"
    tar -C ${_prefix} -zxvpf ${_tmp_tarball} ${_bin_name}
    rm -fv "${_tmp_tarball}"
}
