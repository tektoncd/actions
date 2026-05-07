#
# Environment Variables with Default Values
#

# namespace name for the container registry
readonly REGISTRY_NAMESPACE="${REGISTRY_NAMESPACE:-registry}"
export REGISTRY_NAMESPACE
# the container registry uses the internal k8s service hosntame
readonly REGISTRY_HOSTNAME="${REGISTRY_HOSTNAME:-registry.registry.svc.cluster.local}"
export REGISTRY_HOSTAME
# namespace name for Tekton Pipeline controller
readonly TEKTON_NAMESPACE="${TEKTON_NAMESPACE:-tekton-pipelines}"
export TEKTON_NAMESPACE
# timeout employed during rollout status and deployments in general
readonly DEPLOYMENT_TIMEOUT="${DEPLOYMENT_TIMEOUT:-5m}"
export DEPLOYMENT_TIMEOUT
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

# uses kubectl to check the deployment status on namespace and name informed.
function rollout_status() {
    local namespace="${1}"
    local deployment="${2}"

    if ! kubectl --namespace="${namespace}" --timeout=${DEPLOYMENT_TIMEOUT} \
        rollout status deployment "${deployment}"; then
        fail "'${namespace}/${deployment}' is not deployed as expected!"
    fi
}

# inspect the path after the informed executable name.
function probe_bin_on_path() {
    local name="${1}"

    if ! type -a ${name} &>/dev/null; then
        fail "Can't find '${name}' on 'PATH=${PATH}'"
    fi
}

# get the release artifact URL from infra.tekton.dev for the given component and version.
function get_release_artifact_url() {
    local _component="${1}"
    local _version="${2}"

    local _base="https://infra.tekton.dev/tekton-releases/${_component}"
    local _url
    if [[ "${_version}" == "latest" ]]; then
        _url="${_base}/latest/release.yaml"
    else
        _url="${_base}/previous/${_version}/release.yaml"
    fi

    # verify the URL is reachable
    if ! curl -sIL -o /dev/null -w '%{http_code}' "${_url}" | grep -q '^2'; then
        fail "Release artifact not found at ${_url}"
    fi

    echo "${_url}"
}

# verify the SHA256 checksum of a downloaded file against GitHub's release digest.
# requires gh CLI and GITHUB_TOKEN for authenticated requests.
function verify_checksum() {
    local _file="${1}"
    local _repo="${2}"
    local _version="${3}"
    local _asset_name="${4}"

    local _actual_sha256
    _actual_sha256=$(sha256sum "${_file}" | awk '{print $1}')
    phase "SHA256 of ${_asset_name}: ${_actual_sha256}"

    if ! command -v gh &>/dev/null; then
        phase "WARNING: gh CLI not available, skipping checksum verification"
        return 0
    fi

    # resolve "latest" to actual tag
    local _tag="${_version}"
    if [[ "${_version}" == "latest" ]]; then
        _tag=$(gh release view --repo "${_repo}" --json tagName --jq '.tagName' 2>/dev/null || true)
        if [[ -z "${_tag}" ]]; then
            phase "WARNING: Could not resolve latest version, skipping checksum verification"
            return 0
        fi
    fi

    local _expected_digest
    _expected_digest=$(gh release view "${_tag}" --repo "${_repo}" \
        --json assets --jq ".assets[] | select(.name == \"${_asset_name}\") | .digest" 2>/dev/null || true)

    if [[ -z "${_expected_digest}" ]]; then
        phase "WARNING: Could not fetch expected digest from GitHub, skipping verification"
        return 0
    fi

    local _expected_sha256="${_expected_digest#sha256:}"
    if [[ "${_actual_sha256}" == "${_expected_sha256}" ]]; then
        phase "Checksum verification passed (cross-verified against GitHub release digest)"
    else
        fail "Checksum mismatch! Expected ${_expected_sha256} (from GitHub), got ${_actual_sha256} (from infra.tekton.dev)"
    fi
}
