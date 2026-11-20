# Changelog

## 0.1.0 release candidate

- Reusable Go workflow for Ubuntu and Windows amd64. It runs dependency and redacted history scans, vet, tests, and a root executable build.
- Reusable Java workflow for JDK 21 and Maven. It runs the caller's verify lifecycle and stages a single JAR.
- Generic Windows PowerShell verifier with optional Go setup and first-match executable resolution.
- Artifact name, ID, SHA-256 and cache status outputs for the language workflows.
- Independent synthetic Go and Java caller examples and a public workflow contract.
- Reviewed Java fixture build dependencies, including the Checkstyle engine and Commons Lang used by Maven build plugins.
- Pinned the hosted Java lane and fixture smoke test to Temurin `21.0.13.1+2` to select the vendor security update.

See [release notes](docs/releases/v0.1.0.md) and [verification evidence](docs/RELEASE_EVIDENCE.md).
