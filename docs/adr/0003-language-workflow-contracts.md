# ADR 0003 · Give consuming repositories explicit build and artifact contracts

Status · Accepted

## Context

Go and Maven callers need workflow outputs for downstream verification and a predictable installation, cache and build contract. Go applications also benefit from Windows verification. The generic Windows verifier and the Ubuntu default for Go remain useful to existing callers.

## Decision

Use separate `workflow_call` entry points backed by GitHub-hosted jobs. Go keeps its Linux amd64 default and accepts the fixed Windows amd64 runner. Validate the version and runner strings on a fixed runner before selecting the build job. One caller job produces one platform's artifact and outputs. A caller can use distinct jobs to verify both platforms. Java uses Temurin 21 and the hosted Maven distribution on Ubuntu. Java callers bind their chosen lint gate to Maven's `verify` lifecycle and configure a plain `target/app.jar`.

Return artifact name, ID, digest and cache status from each language workflow. Keep platform names on the first attempt. Append the run attempt on retries to avoid artifact name collisions. Build and test before uploading the explicit payload. The integration callers download by workflow output and execute the result within the same run.

Enable package-manager caching on default-branch pushes only. Go uses the pinned setup action and `go.sum`. Java uses the pinned setup action, matching POMs and applicable Maven configuration files. Each cache belongs to the caller repository and runs under GitHub's ref rules. Pull request jobs start cold. Cache status is observable without granting API write permissions.

Require standard push, pull-request or manually dispatched caller events, read-only checkout and no caller secret inputs. A consumer controls the code, build definitions and permissions of its own workflow. The toolkit assumes those definitions belong to the consuming repository and performs no privileged deployment. [GitHub reusable workflow access](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations) · [GitHub cache access](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching)

## Alternatives considered

- A composite action could share steps but would inherit the calling job's runner and permissions. Each language benefits from a complete job contract.
- A callee OS matrix would report the last successful branch that produced a workflow output. Independent caller jobs give consumers a stable output per platform. [Matrix output behavior](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows#using-outputs-from-a-reusable-workflow)
- Accepting arbitrary runner labels, command lines, package paths or artifact globs would increase validation and review costs. The initial release uses a fixed layout and a small set of inputs.

## Consequences

Consumers can pin the source SHA and review the expected type, paths and job permissions. Windows and Ubuntu Go packages can be checked independently. Java extensions, additional runtimes, Maven multi-module builds and deployment belong to separate contracts. Hosted CI must establish the cache and artifact behavior that local tests cannot reach.
