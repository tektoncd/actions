#!/usr/bin/env bash
#
# Patches /etc/hosts to include the registry FQDN resolving to localhost.
#

set -eu -o pipefail

source "$(dirname ${BASH_SOURCE[0]})/common.sh"
source "$(dirname ${BASH_SOURCE[0]})/inputs.sh"

readonly etc_hosts="/etc/hosts"
readonly hosts_entry="127.0.0.1 ${REGISTRY_HOSTNAME}"

phase "Patching '${etc_hosts}' with '${hosts_entry}' entry"
if ! grep -q "${hosts_entry}" ${etc_hosts} ; then
	echo "${hosts_entry}" >>${etc_hosts}
fi
