# Allow owner-initiated dependency caching on manual runs

## Context

Default-branch push runs were the only cache-enabled entry point. An independent public consumer can execute both language workflows manually, while automatic push scheduling remains unresolved in that consumer.

## Decision

Add the boolean `cache-on-owner-dispatch` input with a false default. A workflow uses the input only on a fresh manual run against the caller's default branch. It compares GitHub's initiating account ID with the caller repository owner ID. The first-attempt condition keeps manual retries uncached even if the rerun was requested by someone else. Default-branch pushes retain their cache policy and Go still requires `go.sum`.

Keep `contents: read`, use GitHub's existing cache access for `workflow_dispatch`, and preserve caller/ref scoping. The pinned setup actions still compute keys from the real platform and dependency files. [GitHub cache access](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching#cache-access-for-low-trust-workflow-triggers) · [Caller cache inheritance](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows#controlling-cache-access-in-reusable-workflows)

## Verification

Exercise both policy steps with permitted and denied fixtures. Use two fresh owner dispatches on the same caller commit and verify the actual miss, save and same-key restore in Go and Maven. Report automatic consumer push scheduling separately.
