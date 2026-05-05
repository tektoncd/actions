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

readonly url=$(get_release_artifact_url "tektoncd/pipeline" "${INPUT_PIPELINE_VERSION}")

phase "Deploying Tekton Pipelines '${INPUT_PIPELINE_VERSION}'"

# Pipeline releases don't publish a checksums file, so we download first,
# log the SHA256 for audit trail, then apply.
readonly tmp_release="/tmp/tekton-pipeline-release.yaml"
curl -sL "${url}" > "${tmp_release}"
phase "SHA256 of release.yaml: $(sha256sum "${tmp_release}" | awk '{print $1}')"
_kubectl apply -f "${tmp_release}"
rm -f "${tmp_release}"

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
