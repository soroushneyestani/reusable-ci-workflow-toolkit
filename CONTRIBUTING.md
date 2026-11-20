# Contributing

Use a focused branch and pull request. Explain the workflow contract affected, why the change is needed, and what local and hosted tests cover it. Keep fixture data synthetic and preserve caller compatibility or document the version boundary.

1. Install PowerShell 7, Go 1.27.4, JDK 21 and Maven.
2. Run `pwsh -NoProfile -File scripts/verify.ps1` and `pwsh -NoProfile -File tests/java-contract.ps1` from the checkout root.
3. If a workflow or caller fixture changes, render the full checked-out SHA and run the independent caller checks. Verify both success and applicable failure paths. [Hosted verification](docs/HOSTED_VERIFICATION.md)
4. Update the spec and ADR when a reusable input, output, or trust boundary changes. Pin Actions by reviewed commit SHA and describe upstream changes in the PR.

Keep build products, cache directories, logs with personal paths, and credentials out of commits.
