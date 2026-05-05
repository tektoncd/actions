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

# get the checksums.txt url for the specific version (release) or latest.
function get_checksums_url() {
    local _org_repo="${1}"
    local _version="${2}"

    local _url="https://api.github.com/repos/${_org_repo}/releases"
    if [[ "${_version}" == "latest" ]]; then
        echo $(
            curl -s ${_url}/latest |
                jq -r '.assets[].browser_download_url' |
                grep -i 'checksums.txt' |
                head -n 1
        )
    else
        echo $(
            curl -s ${_url} |
                jq -r ".[] | select(.tag_name == \"${_version}\") | .assets[].browser_download_url" |
                grep -i 'checksums.txt' |
                head -n 1
        )
    fi
}

# verify the sha256 checksum of a downloaded file against checksums.txt from the release.
function verify_checksum() {
    local _file="${1}"
    local _checksums_url="${2}"

    if [[ -z "${_checksums_url}" ]]; then
        fail "No checksums URL available for verification"
    fi

    local _filename="$(basename ${_file})"
    local _tmp_checksums="/tmp/checksums.txt"

    phase "Downloading checksums from '${_checksums_url}'"
    curl -sL "${_checksums_url}" > "${_tmp_checksums}"

    local _expected
    _expected=$(grep "${_filename}" "${_tmp_checksums}" | awk '{print $1}')
    if [[ -z "${_expected}" ]]; then
        rm -f "${_tmp_checksums}"
        fail "No checksum found for '${_filename}' in checksums.txt"
    fi

    local _actual
    _actual=$(sha256sum "${_file}" | awk '{print $1}')

    rm -f "${_tmp_checksums}"

    if [[ "${_expected}" != "${_actual}" ]]; then
        fail "Checksum mismatch for '${_filename}': expected=${_expected} actual=${_actual}"
    fi

    phase "Checksum verified for '${_filename}': ${_actual}"
}

# get the artifact url for the specific version (release) or latest.
function get_release_artifact_url() {
    local _org_repo="${1}"
    local _version="${2}"

    local _url="https://api.github.com/repos/${_org_repo}/releases"
    if [[ "${_version}" == "latest" ]]; then
        echo $(
            curl -s ${_url}/latest |
                jq -r '.assets[].browser_download_url' |
                egrep -i 'linux_(x86_64|amd64)' |
                head -n 1
        )
    else
        echo $(
            curl -s ${_url} |
                jq -r ".[] | select(.tag_name == \"${_version}\") | .assets[].browser_download_url" |
                egrep -i 'linux_(x86_64|amd64)' |
                head -n 1
        )
    fi
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

    # verify checksum if a checksums URL is provided
    if [[ -n "${3:-}" ]]; then
        verify_checksum "${_tmp_tarball}" "${3}"
    fi

    phase "Installing '${_bin_name}' on prefix '${_prefix}'"
    tar -C ${_prefix} -zxvpf ${_tmp_tarball} ${_bin_name}
    rm -fv "${_tmp_tarball}"
}
