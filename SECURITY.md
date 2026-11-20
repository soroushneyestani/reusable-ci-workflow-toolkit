# Security policy

Report a suspected vulnerability privately through [GitHub private vulnerability reporting](https://github.com/soroushneyestani/reusable-ci-workflow-toolkit/security/advisories/new) when enabled. If the private form is unavailable, use the contact channel on the [maintainer's website](https://soroush.neyestani.com/). Provide the toolkit commit SHA, caller event, impact and a minimal synthetic reproduction. Keep real credentials, private payloads and vulnerability details out of public issues.

The toolkit uses read-only repository contents, non-persisted checkout credentials, no declared caller secrets, immutable action references, and default-branch-only dependency caching. Call these workflows from trusted workflow definitions using normal push, pull request, or manual events. Review build definitions in the consuming repository. Its Go tests, Maven plugins and PowerShell scripts run with the job's runner access. Keep deployment, publishing keys and access to sensitive services in separately managed jobs.

The latest published stable release will receive security fixes. Pin the reviewed release commit and follow its security and dependency notices. [Workflow security boundaries](docs/SPEC.md#shared-boundaries)
