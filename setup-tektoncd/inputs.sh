#
# GitHub Action Inputs
#

# action inputs represented as environment variables
readonly INPUT_PIPELINE_VERSION="${INPUT_PIPELINE_VERSION:-}"
export INPUT_PIPELINE_VERSION
readonly INPUT_CLI_VERSION="${INPUT_CLI_VERSION:-}"
export INPUT_CLI_VERSION
readonly INPUT_FEATURE_FLAGS="${INPUT_FEATURE_FLAGS:-}"
export INPUT_FEATURE_FLAGS

for v in INPUT_PIPELINE_VERSION INPUT_FEATURE_FLAGS INPUT_CLI_VERSION; do
	[[ -z "${!v}" ]] &&
		fail "'${v}' environment variable is not set!"
done

# path to the current workspace
readonly GITHUB_WORKSPACE="${GITHUB_WORKSPACE:-.}"
export GITHUB_WORKSPACE
# name of the organization and repository, joined by slash
readonly GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}"
export GITHUB_REPOSITORY
