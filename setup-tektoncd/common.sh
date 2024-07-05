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

# get the artifact url for the specific version (release) or latest.
function get_release_artifact_url() {
    local _org_repo="${1}"
    local _version="${2}"

    local _url="https://api.github.com/repos/${_org_repo}/releases"
    if [[ "${_version}" == "latest" ]]; then
        echo $(
            curl -s ${_url}/latest |
                jq -r '.assets[].browser_download_url' |
                egrep -i 'release.yaml' |
                head -n 1
        )
    else
        echo $(
            curl -s ${_url} |
                jq -r ".[] | select(.tag_name == \"${_version}\") | .assets[].browser_download_url" |
                egrep -i 'release.yaml' |
                head -n 1
        )
    fi
}
