[![use-action][useActionWorkflowBadge]][useActionWorkflow]

`setup-tektoncd-cli`
------------------

GitHub Action to install [Tekton CLI (`tkn`)][githubTektonCLI].

# Usage

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

[githubTektonCLI]: https://github.com/tektoncd/cli
[useActionWorkflowBadge]: https://github.com/tektoncd/actions/setup-tektoncd-cli/actions/workflows/use-action.yaml/badge.svg
[useActionWorkflow]: https://github.com/tektoncd/actions/setup-tektoncd-cli/actions/workflows/use-action.yaml
