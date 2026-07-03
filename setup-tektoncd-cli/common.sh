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

# compute the sha256 checksum of a file, using sha256sum or shasum -a 256.
# returns non-zero if no SHA256 tool is available.
function _sha256() {
    local _file="${1}"
    if command -v sha256sum &>/dev/null; then
        sha256sum "${_file}" | awk '{print $1}'
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "${_file}" | awk '{print $1}'
    else
        return 1
    fi
}

# helper to perform an authenticated GitHub API request when GITHUB_TOKEN is
# available. Captures the response body and HTTP status so API error messages
# (e.g. rate-limit details) can be surfaced to the caller.
function _gh_curl() {
    local _curl_args=(-sSL -w '\n%{http_code}')
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        _curl_args+=(-H "Authorization: token ${GITHUB_TOKEN}")
    fi
    local _stderr
    _stderr="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '${_stderr}'" RETURN
    local _response
    if ! _response=$(curl "${_curl_args[@]}" "$@" 2>"${_stderr}"); then
        fail "GitHub API request failed for '$*'. Response: $(cat "${_stderr}"). If this is a rate-limit error, set the 'github_token' input."
    fi
    local _http_code="${_response##*$'\n'}"
    local _body="${_response%$'\n'*}"
    if [[ "${_http_code}" -lt 200 || "${_http_code}" -ge 300 ]]; then
        local _msg
        _msg=$(echo "${_body}" | jq -r '.message // empty' 2>/dev/null)
        [[ -z "${_msg}" ]] && _msg="HTTP ${_http_code}"
        fail "GitHub API error (${_http_code}): ${_msg}. If this is a rate-limit error, set the 'github_token' input."
    fi
    echo "${_body}"
}

# get the checksums.txt url for the specific version (release) or latest.
function get_checksums_url() {
    local _org_repo="${1}"
    local _version="${2}"

    local _url="https://api.github.com/repos/${_org_repo}/releases"
    local _response
    if [[ "${_version}" == "latest" ]]; then
        _response=$(_gh_curl "${_url}/latest")
    else
        _response=$(_gh_curl "${_url}")
    fi

    local _checksums_url
    if [[ "${_version}" == "latest" ]]; then
        _checksums_url=$(
            echo "${_response}" |
                jq -r '.assets[].browser_download_url' |
                grep -i 'checksums.txt' |
                head -n 1
        )
    else
        _checksums_url=$(
            echo "${_response}" |
                jq -r ".[] | select(.tag_name == \"${_version}\") | .assets[].browser_download_url" |
                grep -i 'checksums.txt' |
                head -n 1
        )
    fi

    if [[ -z "${_checksums_url}" ]]; then
        fail "Could not find checksums.txt for ${_org_repo} version '${_version}'"
    fi

    echo "${_checksums_url}"
}

# verify the sha256 checksum of a downloaded file against checksums.txt from the release.
function verify_checksum() {
    local _file="${1}"
    local _checksums_url="${2}"

    if [[ -z "${_checksums_url}" ]]; then
        fail "No checksums URL available for verification"
    fi

    local _actual
    if ! _actual=$(_sha256 "${_file}"); then
        phase "WARNING: no SHA256 tool (sha256sum/shasum) available, skipping checksum verification"
        return 0
    fi

    local _filename
    _filename="$(basename "${_file}")"
    local _tmp_checksums
    _tmp_checksums="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '${_tmp_checksums}'" RETURN

    phase "Downloading checksums from '${_checksums_url}'"
    if ! curl -fsSL "${_checksums_url}" > "${_tmp_checksums}"; then
        fail "Failed to download checksums from '${_checksums_url}'"
    fi

    # match the filename field exactly (second column) to avoid substring
    # matches; checksums.txt entries look like '<hash>  <file>' or '<hash> *<file>'.
    local _expected
    _expected=$(awk -v f="${_filename}" '$2 == f || $2 == "*"f {print $1}' "${_tmp_checksums}")

    local _count
    _count=$(printf '%s\n' "${_expected}" | grep -c . || true)
    if [[ "${_count}" -eq 0 ]]; then
        fail "No checksum found for '${_filename}' in checksums.txt"
    elif [[ "${_count}" -gt 1 ]]; then
        fail "Multiple checksum entries found for '${_filename}' in checksums.txt"
    fi

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
    local _response
    if [[ "${_version}" == "latest" ]]; then
        _response=$(_gh_curl "${_url}/latest")
    else
        _response=$(_gh_curl "${_url}")
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
    local _checksums_url="${3:-}"

    local _prefix="/usr/local/bin"
    local _tarball
    _tarball="$(basename "${_url}")"
    local _tmp_dir
    _tmp_dir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '${_tmp_dir}'" RETURN
    local _tmp_tarball="${_tmp_dir}/${_tarball}"

    phase "Downloading '${_url}' to '${_tmp_tarball}'"
    if ! curl -fsSL "${_url}" > "${_tmp_tarball}"; then
        fail "Failed to download '${_url}'"
    fi

    # verify checksum if a checksums URL is provided
    if [[ -n "${_checksums_url}" ]]; then
        verify_checksum "${_tmp_tarball}" "${_checksums_url}"
    fi

    phase "Installing '${_bin_name}' on prefix '${_prefix}'"
    tar -C "${_prefix}" -zxvpf "${_tmp_tarball}" "${_bin_name}"
}
