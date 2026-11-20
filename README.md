# Reusable CI Workflow Toolkit

Run Go and Maven verification from GitHub Actions without maintaining a copy of the workflow in every repository. The toolkit provides reusable job entry points, explicit input and artifact contracts, read-only checkout, and dependency caching for default-branch pushes.

| Entry point | Build and verification | Hosted runner |
| --- | --- | --- |
| `reusable-go.yml` | Go vet, uncached tests, dependency and secret scans, and one executable artifact | Ubuntu 24.04 or Windows 2025, amd64 |
| `reusable-java.yml` | Temurin 21, Maven clean verify, caller-configured lint and tests, and one JAR artifact | Ubuntu 24.04 |
| `reusable-verify.yml` | Caller-owned `scripts/verify.ps1`, optional exact Go setup, and exit-code propagation | Windows 2025 |

## Call a reusable workflow

Use a job-level `uses`. Replace `FULL_TOOLKIT_SHA` with the full commit SHA of the reviewed release in this repository. After the release tag is available, `v0.1.0` is also a supported reference. [Versioned examples](docs/releases/v0.1.0.md#invoke-the-accepted-release) · [Workflow access requirements](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations#access-to-reusable-workflows)

```yaml
name: Go CI
on: [push, pull_request]
permissions:
  contents: read
jobs:
  go:
    uses: soroushneyestani/reusable-ci-workflow-toolkit/.github/workflows/reusable-go.yml@FULL_TOOLKIT_SHA
    with:
      go-version: '1.27.4'
      runner: ubuntu-24.04
```

The Go lane expects a root `go.mod` and a root `main` package. Commit `go.sum` for dependencies requiring checksums. To run on Windows, set `runner: windows-2025` in a separate caller job. The first attempt uploads `go-linux-amd64` containing `app`, or `go-windows-amd64` containing `app.exe`.

```yaml
name: Java CI
on: [push, pull_request]
permissions:
  contents: read
jobs:
  java:
    uses: soroushneyestani/reusable-ci-workflow-toolkit/.github/workflows/reusable-java.yml@FULL_TOOLKIT_SHA
    with:
      java-version: '21'
```

The Java lane expects a root `pom.xml`, calls `mvn --batch-mode --no-transfer-progress --strict-checksums clean verify`, and uploads `target/app.jar` as `java-jar`. Configure your project to produce that file and bind lint to a lifecycle phase that runs by `verify`. The Java fixture binds Checkstyle to the build and uses JUnit. [Java fixture](fixtures/java-caller/pom.xml)

The generic Windows entry point runs the root `scripts/verify.ps1` in a noninteractive PowerShell child. Callers supply the verifier and its build tools. To install Go, provide `go-version` and use a full release number for reproducibility. [Windows caller contract](docs/SPEC.md#windows-repository-verifier)

## Use artifacts and caches

For Go and Java, a downstream job with `needs` can consume `artifact-name`, `artifact-id`, `artifact-digest` and `cache-status`. The digest identifies the uploaded archive. Retries add an attempt suffix. Download the artifact in the same run and restore the execute bit before running the extracted Linux executable. [Runnable Go example](fixtures/go-caller/.github/workflows/consumer.yml) · [Runnable Java example](fixtures/java-caller/.github/workflows/consumer.yml)

Caches belong to the caller repository. The language lanes enable caching on default-branch pushes under GitHub's ref rules. Go uses `go.sum` and skips caching if it is absent. The Maven key includes matching POMs and supported Maven configuration files. JDK caching is disabled. Pull requests and manual dispatches run without the dependency cache. [Cache behavior](docs/SPEC.md#shared-boundaries)

## Verify and contribute

Run `pwsh -NoProfile -File scripts/verify.ps1` with Go 1.27.4 on `PATH`. Run `pwsh -NoProfile -File tests/java-contract.ps1` with JDK 21 and Maven to exercise the actual Java workflow steps. The fixture sources and their rendered caller workflows can be reused in synthetic consumer repositories. [Verification guide](docs/HOSTED_VERIFICATION.md) · [Documentation index](docs/README.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md)

Original source is covered by the [MIT license](LICENSE). External actions, tools and fixture dependencies retain their upstream licenses. [Third-party notices](THIRD_PARTY_NOTICES.md)
