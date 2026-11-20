# Reusable CI workflow contracts

Call the entry points as jobs using `workflow_call`. The checkout, refs, runner entitlement, and artifacts belong to the caller. Pin the toolkit's full commit SHA for reproducibility. The callable workflows accept push, pull-request, and manually dispatched caller runs. A consumer's Actions policy must allow the public toolkit and its pinned actions. [GitHub reuse configuration](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations)

## Shared boundaries

- Caller and callee use `contents: read`. Checkout uses the caller's event ref, disables credential persistence, and accepts no arbitrary checkout ref. The workflows have no declared secrets and examples omit secret passing.
- A consumer owns its repository code and build configuration. PowerShell verifiers, Go tests, and Maven plugins execute on the caller's hosted runner. Use ordinary `pull_request` validation. Keep release credentials and deployment in separate owner-controlled workflows.
- Go and Java enable dependency caching on default-branch pushes. Both accept the optional boolean `cache-on-owner-dispatch`, which defaults to false. When true, a first-attempt `workflow_dispatch` also enables the dependency cache if the ref is the caller's default branch and GitHub's initiating actor ID equals the caller repository owner ID. This opt-in supports personally owned repositories. Other manual calls, retries, pull requests, tags, and non-default branches run uncached. Go also requires `go.sum`.
- GitHub isolates caches by caller repository and ref. The pinned setup actions use platform and dependency inputs and request no alternate restore keys. The workflows inherit cache access under GitHub's trigger and caller rules. Keep secrets and confidential data out of cache paths. [GitHub cache rules](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching) · [Reusable cache access](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows#controlling-cache-access-in-reusable-workflows)
- Each Go or Java call produces one package on success. `artifact-name`, `artifact-id`, and `artifact-digest` identify the archive uploaded into the caller run. `cache-status` is `disabled`, `miss`, or `hit`. The SHA-256 digest describes the uploaded archive. Download within a downstream job in the same run. Artifact retention is requested for seven days. Reruns add `-attempt-N` to the artifact name.
- Inputs are typed strings. Untrusted values are passed to validation through the environment. Runner names, package paths, and output names are internally constrained.

## Windows repository verifier

| Item | Contract |
| --- | --- |
| Entry point | `.github/workflows/reusable-verify.yml` |
| Input | Optional `go-version`. Omit for the runner's Go installation. A provided version goes to pinned setup-go with caching disabled. Use a full release number for reproducibility. |
| Runner | Windows Server 2025 with PowerShell 7 and 15-minute timeout. |
| Caller layout | Fixed `scripts/verify.ps1` file, executed from the checkout root in a child PowerShell process with profiles disabled. |
| Result | Zero passes. Nonzero, thrown errors, and missing verifiers fail the job. The caller script owns its build, tool versions, and output. |

## Go application verifier

| Item | Contract |
| --- | --- |
| Entry point | `.github/workflows/reusable-go.yml` |
| Inputs | Required `go-version`, exact `major.minor.patch`, at least 1.26.0. Optional `runner`, default `ubuntu-24.04`, or `windows-2025`. |
| Caller layout | Root `go.mod` and `main` package. Go workspace mode and implicit toolchain switching are disabled. |
| Checks | Pinned redacting Git history scan and dependency scan, then `go vet ./...`, uncached `go test -count=1 ./...`, and a trimmed root executable with read-only module resolution. |
| Cache | setup-go uses `go.sum` and its platform/toolchain-aware key. Dependency-free callers can omit `go.sum` and run uncached. Required missing checksums fail normally. |
| Packages | Ubuntu amd64 `go-linux-amd64` with `app`; Windows amd64 `go-windows-amd64` with `app.exe`. |

One call resolves one runner through a fixed allowlist and returns one set of outputs. Choose standalone caller jobs for both platforms. Linux artifact ZIP extraction requires restoring executable permissions before running `app`.

## Java application verifier

| Item | Contract |
| --- | --- |
| Entry point | `.github/workflows/reusable-java.yml` |
| Input | Optional `java-version`, default and supported value `21`. |
| Runner | Ubuntu 24.04, Temurin `21.0.13.1+2`, hosted Maven and 15-minute timeout. |
| Caller layout | Regular root `pom.xml` and regular `target/app.jar` after build. |
| Checks | Maven `--batch-mode --no-transfer-progress --strict-checksums clean verify` runs the caller's configured build, tests, and lint gates. The fixture binds Checkstyle and JUnit. |
| Cache | setup-java Maven cache uses matching POM and Maven configuration files. JDK caching is disabled. |
| Package | `java-jar` with the caller-built `app.jar`. A missing, renamed, or symlinked output fails the job. |

## Verification and scope

Local tests lint the real definitions and extract and execute the PowerShell run blocks. Hosted verification requires two independent callers, confirmed cache miss and hit, same-run download and execution, scoped permissions, and deliberate failures with no uploaded artifact. Keep dependency scans, external sharing, and hosted platform evidence traceable to the exact source SHA.

The initial scope excludes Go workspaces and library-only modules, general-purpose Maven multi-module builds, Gradle, self-hosted or arbitrary runner labels, cross-run artifact access, and deployment. GitHub controls runner images, availability, and cache eviction. [Hosted verification](HOSTED_VERIFICATION.md) · [Consumer fixtures](../fixtures/README.md)
