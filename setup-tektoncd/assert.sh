#!/usr/bin/env bash
#
# Assert the changes made by this action.
#

shopt -s inherit_errexit
set -eu -o pipefail

source common.sh

phase "Asserting the Container Registry rollout status"
rollout_status "${REGISTRY_NAMESPACE}" "registry"

phase "Asserting the /etc/hosts have been patched"
if ! grep -E -q '127.0.0.1.*registry' /etc/hosts; then
	fail "/etc/hosts does not include the registry hostname"
fi

phase "Asserting the Tekton Pipeline Controller"
rollout_status "${TEKTON_NAMESPACE}" "tekton-pipelines-controller"

phase "Asserting the Tekton Pipeline WebHook"
rollout_status "${TEKTON_NAMESPACE}" "tekton-pipelines-webhook"

phase "Asserting the feature-flag 'enable-custom-tasks' is 'true'"
if ! (
	kubectl get configmap feature-flags \
		--namespace=${TEKTON_NAMESPACE} \
		--output=json \
		|grep -E 'enable-custom-tasks.*"true",'
); then
	fail "Feature-flag 'enable-custom-tasks' is not enabled ('true')!"
fi

phase "Asserting the CLI (tkn) is installed"
probe_bin_on_path "tkn"
