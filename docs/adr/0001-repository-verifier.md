# ADR 0001 · Use a fixed PowerShell verifier in the caller repository

Status · Accepted

## Context

The toolkit needs a shared GitHub Actions entry point that preserves each consumer repository's build and test conventions. The first slice should have meaningful Windows fixture tests and a locally checkable workflow contract before collecting hosted-runner evidence.

## Decision

Expose a reusable workflow with a fixed `windows-2025` runner and `scripts/verify.ps1` as the caller-owned entry point. Run the verifier in a child PowerShell process from the checkout root so profiles are disabled and failure status reaches the CI job. Use a full-commit-pinned checkout action with credentials persistence disabled. Declare `contents: read` in the same-repository caller and reusable workflow. Keep the initial callable interface free of inputs and passed secrets.

## Alternatives considered

- Accept free-form commands as an input. This puts shell syntax and quoting in the interface and makes each caller's execution contract harder to verify.
- Start with language-specific jobs. These can install and cache dependencies centrally but require a separate toolchain contract for each language. A Go lane can extend the toolkit after the repository verifier contract is established.

## Consequences

Each consumer supplies a real verifier and owns its repository-specific checks. The toolkit controls checkout, permissions, working directory, PowerShell invocation, and job failure. Local syntax and fixture checks establish a baseline. Hosted behavior and cross-repository access require GitHub Actions runs in authorized repositories.
