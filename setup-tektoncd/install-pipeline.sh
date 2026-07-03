#!/usr/bin/env bash
#
# Installs Tekton Pipelines using the first argument as target version.
#

shopt -s inherit_errexit
set -eu -o pipefail

source "$(dirname ${BASH_SOURCE[0]})/common.sh"
source "$(dirname ${BASH_SOURCE[0]})/inputs.sh"

function _kubectl() {
	set -x
	eval "kubectl ${*}"
	set +x
}

readonly url=$(get_release_artifact_url "pipeline" "${INPUT_PIPELINE_VERSION}")

phase "Deploying Tekton Pipelines '${INPUT_PIPELINE_VERSION}'"

# Download release.yaml, verify checksum against GitHub's digest, then apply
tmp_release="$(mktemp)"
trap 'rm -f "${tmp_release}"' EXIT
if ! curl -fsSL "${url}" > "${tmp_release}"; then
    fail "Failed to download release manifest from '${url}'"
fi
verify_checksum "${tmp_release}" "tektoncd/pipeline" "${INPUT_PIPELINE_VERSION}" "release.yaml"
_kubectl apply -f "${tmp_release}"

phase "Waiting for Tekton components"

rollout_status "${TEKTON_NAMESPACE}" "tekton-pipelines-controller"
rollout_status "${TEKTON_NAMESPACE}" "tekton-pipelines-webhook"

# graceful wait to give some more time for the tekton componets stabilize
sleep 30

phase "Setting up the feature-flag(s): '${INPUT_FEATURE_FLAGS}"
if [[ -n "${INPUT_FEATURE_FLAGS}" && "${INPUT_FEATURE_FLAGS}" != "{}" ]]; then
	_kubectl patch configmap/feature-flags \
		--namespace="${TEKTON_NAMESPACE}" \
		--type=merge \
		--patch="'{ \"data\": ${INPUT_FEATURE_FLAGS} }'"

	# after patching the feature flags, making sure the rollout is not progressing again
	rollout_status "${TEKTON_NAMESPACE}" "tekton-pipelines-controller"
	rollout_status "${TEKTON_NAMESPACE}" "tekton-pipelines-webhook"
	rollout_status "${TEKTON_NAMESPACE}" "tekton-events-controller"
fi
