# Reusable CI Workflow Toolkit

Teams often carry the same build, test and artifact rules in several repositories. Each copied workflow needs separate maintenance, and differences in toolchain versions or token permissions can be difficult to spot in review. I built the Reusable CI Workflow Toolkit so a consuming repository can pin a reviewed CI contract while keeping ownership of its code and build configuration. [Project repository](https://github.com/soroushneyestani/reusable-ci-workflow-toolkit)

## A workflow API for build verification

A consuming repository calls the toolkit at the job level with GitHub Actions' `workflow_call` interface. The workflow runs against the caller's checkout and returns values that a downstream job can read through `needs`. The entry points own runner selection, setup, build failure handling and artifact creation. That full job contract is why I chose reusable workflows. Composite actions are better suited to sharing steps within a job whose runner and permissions the caller already controls. [GitHub's reusable workflow guide](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)

| Workflow | Expected project | What it verifies |
| --- | --- | --- |
| Go | Root `go.mod` and a root `main` package | Runs dependency and redacted Git-history scans, then `go vet`, uncached tests and a native build on Ubuntu or Windows. |
| Java | Root Maven project on Ubuntu, Temurin 21, a regular `target/app.jar` | Runs Maven `clean verify` with strict checksums and stages the JAR. The shipped example binds Checkstyle to `verify` and uses JUnit Jupiter for unit tests. |
| Windows verifier | Root `scripts/verify.ps1` | Runs the caller's verifier in a noninteractive PowerShell child process and forwards its exit code. It can set up a caller-selected Go version first. |

The Go runner defaults to Ubuntu. The caller can instead select the supported Windows runner. A fixed validation job checks that input before it reaches runner selection. Each Go call returns one platform's outputs. A consumer that needs both builds can give each call its own job and read each result by job name. This avoids depending on whichever matrix member finishes last to produce a reusable workflow output. [Input and output contracts](https://github.com/soroushneyestani/reusable-ci-workflow-toolkit/blob/main/docs/SPEC.md) · [Architecture decision](https://github.com/soroushneyestani/reusable-ci-workflow-toolkit/blob/main/docs/adr/0003-language-workflow-contracts.md)

## Invoking the toolkit

The example below gives a caller independent Go and Java jobs. Use the job that matches your application. Replace `FULL_TOOLKIT_SHA` with the full reviewed commit recorded in the public release. The checked-in fixture workflows also demonstrate download and smoke tests using the workflow outputs. [Go and Java callers](https://github.com/soroushneyestani/reusable-ci-workflow-toolkit/tree/main/fixtures) · [Release evidence](https://github.com/soroushneyestani/reusable-ci-workflow-toolkit/blob/main/docs/RELEASE_EVIDENCE.md)

```yaml
name: Verify
on: [push, pull_request]

permissions:
  contents: read

jobs:
  go:
    uses: soroushneyestani/reusable-ci-workflow-toolkit/.github/workflows/reusable-go.yml@FULL_TOOLKIT_SHA
    with:
      go-version: '1.27.4'
      runner: windows-2025
  java:
    uses: soroushneyestani/reusable-ci-workflow-toolkit/.github/workflows/reusable-java.yml@FULL_TOOLKIT_SHA
    with:
      java-version: '21'
```

The language workflows return `artifact-name`, `artifact-id`, `artifact-digest` and `cache-status`. A downstream consumer can download by the returned name and choose how to use the result. A retry uses a different artifact name from the first attempt. The reported digest describes the uploaded artifact archive. It is separate from a checksum calculated on an extracted executable or JAR. GitHub's ZIP upload discards the Unix executable bit, so the Linux fixture restores that bit before running its downloaded Go binary. [GitHub artifact outputs](https://github.com/actions/upload-artifact#outputs) · [Artifact file permissions](https://github.com/actions/upload-artifact#permission-loss)

## Cache isolation and permissions

Dependency caching is eligible on pushes to the caller's default branch. Go uses the checked-in `go.sum` when present, and Maven includes `pom.xml` in its dependency cache key. Each cache stays within the consuming repository's GitHub cache scope, including GitHub's ref and runner-specific matching rules. A cache miss is a normal build path. The caller can observe eligibility and restoration through the workflow's `hit`, `miss` and `disabled` output. [GitHub dependency cache reference](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching)

The reusable jobs grant `contents: read`, disable persisted checkout credentials and declare no caller secret inputs. Setup and artifact actions use full commit pins. Version and runner inputs have explicit contracts, and validation uses environment variables rather than interpolating caller text into a shell program. The build still runs code and build configuration supplied by the consuming repository. These workflows are for standard push, pull request and manual runs on GitHub-hosted runners. Keep credentialed deployment in a separately reviewed workflow. [GitHub secure-use guidance](https://docs.github.com/en/actions/reference/security/secure-use)

## How I verified the design

The repository verifier lints the workflow definitions with a pinned version of `actionlint` and executes workflow command blocks against synthetic repositories. The independent Go and Maven fixtures create runnable artifacts and provide an expected output string for smoke tests. I built and tested both fixtures locally. The Maven fixture ran its JUnit test and Checkstyle, then its JAR executed successfully. The Go fixture passed its vet and test commands and produced its expected greeting. [Verification evidence](https://github.com/soroushneyestani/reusable-ci-workflow-toolkit/blob/main/docs/RELEASE_EVIDENCE.md)

Local checks establish command and configuration behavior. Before distribution, two independent synthetic GitHub repositories verified Go on Ubuntu and Windows and Maven on Ubuntu. All three lanes missed the cache on the first attempt and hit it on the second. Each downstream job downloaded and executed the artifact from its run. Four synthetic failure cases covered failed tests and missing project configuration and uploaded zero artifacts. The release evidence describes the results and how to reproduce them. [Independent fixture instructions](https://github.com/soroushneyestani/reusable-ci-workflow-toolkit/tree/main/fixtures) · [Release evidence](https://github.com/soroushneyestani/reusable-ci-workflow-toolkit/blob/main/docs/RELEASE_EVIDENCE.md)

## Release and scope

The release candidate pairs the workflow source with callable examples and verification records. Use the documented full source commit for callers that require an immutable reference. GitHub-hosted images, network access and package registries remain operational dependencies. A private consumer also needs a compatible Actions access policy. [Hosted verification](https://github.com/soroushneyestani/reusable-ci-workflow-toolkit/blob/main/docs/HOSTED_VERIFICATION.md)

The initial Go contract covers an executable at the module root. The initial Java contract covers a single root Maven project on Ubuntu and leaves lint rules to the caller's Maven configuration. Runner coverage, toolchain and artifacts have explicit boundaries so a consuming repository can decide whether the toolkit fits before adopting it. [Workflow specification](https://github.com/soroushneyestani/reusable-ci-workflow-toolkit/blob/main/docs/SPEC.md)
