# ADR 0002 · Add a reusable Go application verifier

Status · Accepted

## Context

Go repositories share module resolution, vet, tests, and binary build requirements. The Windows verifier delegates each check to consumer scripts. A dedicated workflow centralizes these steps and produces a single binary with a clear download contract.

## Decision

Use `ubuntu-24.04` with an exact caller-selected Go release and a root `main` package. Require Go `1.26.0` or later for the pinned dependency scanner. Disable automatic toolchain switching and workspace mode. Use read-only module resolution and run tests without the Go test result cache. Build one `app` executable outside the caller checkout. Enable setup-go's dependency and build cache when `go.sum` exists and use its checksum as a cache key input.

Pin checkout, Go setup, and artifact actions by commit SHA and audit tools by version. Checkout with read-only token access and no persisted credentials, then run dependency and redacted Git history scans before uploading the executable. Accept a single version input and build a fixed package to keep the interface small.

## Alternatives considered

- Keep Go verification exclusively in each caller's `scripts/verify.ps1`. This offers caller-specific control but requires duplicating setup, cache, scan, and upload configuration.
- Accept arbitrary build package paths and expand to an OS and architecture matrix. This would cover more layouts and targets at the cost of a larger input contract and platform-specific packaging proof.

## Consequences

Standard root Go applications share a reproducible command sequence and artifact name. Library-only modules, nested modules, and additional architectures require another contract. Fresh runner cache behavior and artifact storage require hosted verification. GitHub's ZIP artifact format drops the executable bit, so consumers restore it after extraction.
