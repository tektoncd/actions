#
# GitHub Action Inputs
#

# action inputs represented as environment variables
readonly export INPUT_PIPELINE_VERSION="${INPUT_PIPELINE_VERSION:-}"
readonly export INPUT_CLI_VERSION="${INPUT_CLI_VERSION:-}"
readonly export INPUT_FEATURE_FLAGS="${INPUT_FEATURE_FLAGS:-}"

for v in INPUT_PIPELINE_VERSION INPUT_FEATURE_FLAGS INPUT_CLI_VERSION; do
	[[ -z "${!v}" ]] &&
		fail "'${v}' environment variable is not set!"
done

# path to the current workspace
readonly export GITHUB_WORKSPACE="${GITHUB_WORKSPACE:-.}"
# name of the organization and repository, joined by slash
readonly export GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}"
