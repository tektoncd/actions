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

# Download release.yaml and verify its SHA256 against GitHub's release digest
readonly tmp_release="/tmp/tekton-pipeline-release.yaml"
curl -sL "${url}" > "${tmp_release}"

readonly actual_sha256=$(sha256sum "${tmp_release}" | awk '{print $1}')
phase "SHA256 of release.yaml: ${actual_sha256}"

# Fetch expected digest from GitHub release API
readonly release_tag=$(
    if [[ "${INPUT_PIPELINE_VERSION}" == "latest" ]]; then
        curl -s "https://api.github.com/repos/tektoncd/pipeline/releases/latest" | jq -r '.tag_name'
    else
        echo "${INPUT_PIPELINE_VERSION}"
    fi
)
if command -v gh &>/dev/null; then
    expected_digest=$(gh release view "${release_tag}" --repo tektoncd/pipeline \
        --json assets --jq '.assets[] | select(.name == "release.yaml") | .digest' 2>/dev/null || true)
    if [[ -n "${expected_digest}" ]]; then
        expected_sha256="${expected_digest#sha256:}"
        if [[ "${actual_sha256}" == "${expected_sha256}" ]]; then
            phase "Checksum verification passed"
        else
            fail "Checksum mismatch! Expected ${expected_sha256}, got ${actual_sha256}"
        fi
    else
        phase "WARNING: Could not fetch expected digest, skipping verification"
    fi
else
    phase "WARNING: gh CLI not available, skipping checksum verification"
fi

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
