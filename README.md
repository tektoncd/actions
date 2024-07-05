# *Official* Tekton GitHub actions

This repository holds *official* GitHub actions to be used in your GitHub Workflows.

## `setup-tektoncd`

Action to rollout [Tekton Pipeline][githubTektonPipeline], [CLI (`tkn`)][githubTektonCLI] and a [Container-Registry][containerRegistry] instance, setting up the environment for testing using these components.

Example usage below with inputs using default values:

```yaml
---
jobs:
  setup-tektoncd:
    steps:
      # using KinD to provide the Kubernetes instance and kubectl
      - uses: helm/kind-action@v1.5.0
        with:
          cluster_name: kind

      # setting up Tekton Pipelines, CLI and additional components...
      - uses: tektoncd/actions/setup-tektoncd@main
        with:
          pipeline_version: latest
          setup_registry: "true"
          patch_etc_hosts: "true"
```

See more on [`setup-tektoncd/README.md`](./setup-tektoncd).

## `setup-tektoncd-cli`

Action to install the [Tekton CLI (`tkn`)][githubTektonCLI].

Example usage below with inputs using some default values:

```yaml
---
jobs:
  setup-tektoncd-cli:
    steps:
      - uses: tektoncd/actions/setup-tektoncd-cli@main
        with:
          version: latest
```

By default the action is set to install `latest` release, use the `version` input for a specific target.

[containerRegistry]: https://docs.docker.com/registry/spec/api/
[githubTektonPipeline]: https://github.com/tektoncd/pipeline
[githubTektonCLI]: https://github.com/tektoncd/cli
