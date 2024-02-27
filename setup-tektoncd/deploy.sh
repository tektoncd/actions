#!/usr/bin/env bash
#
# Setting up a new KinD instance, and right after, rolling out the Container Registry and Tekton
# Pipelines. The instnace will be available as the current kubeconfig context.
#

shopt -s inherit_errexit
set -xeu -o pipefail

kind delete cluster
kind create cluster
kind export kubeconfig

source .env

./install-registry.sh
./install-tekton.sh