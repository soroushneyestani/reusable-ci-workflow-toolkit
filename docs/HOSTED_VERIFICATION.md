# Hosted verification and branch protection

## Set up independent consumers

Use the [Go](../fixtures/go-caller) and [Java](../fixtures/java-caller) synthetic applications in separate consumer repositories, or copy both applications into one independent synthetic repository and give their caller workflows distinct filenames. For exact-source preflight, replace each `FULL_TOOLKIT_SHA` with the full reviewed commit in the public toolkit repository. For release verification, use `v0.1.0` and confirm the resolved commit using the run's referenced workflow metadata. The consumer's Actions policy must allow the toolkit and its pinned actions. The consumer provides the hosted runner and billing context. [Fixture instructions](../fixtures/README.md) · [GitHub workflow access](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations) · [Run metadata](https://docs.github.com/en/rest/actions/workflow-runs#get-a-workflow-run)

| Fixture | Calls | Expected packaged payload |
| --- | --- | --- |
| Go | Linux on `ubuntu-24.04` and Windows on `windows-2025`, both with Go `1.27.4` | `go-linux-amd64` with `app`, and `go-windows-amd64` with `app.exe` |
| Maven | `ubuntu-24.04` with Temurin `21` | `java-jar` with `app.jar` |

The downstream fixture jobs validate the artifact name, ID, SHA-256 archive digest and cache status outputs. They download the artifact by the returned name within the same run and execute the contained program. The runner logs emit `evidence:go-linux:cache-status=…`, `evidence:go-windows:cache-status=…` or `evidence:java:cache-status=…` after the expected greeting passes. The Linux smoke test restores the executable bit because zipped Actions artifacts lose Unix file permissions. [Artifact upload outputs](https://github.com/actions/upload-artifact#outputs) · [Permission loss](https://github.com/actions/upload-artifact#permission-loss)

## Capture each success and failure case

1. **Cold cache and successful build.** Push each passing fixture to its default branch in a fresh test repository. Expect `miss` for Go on each runner and for Maven on Ubuntu. Check that the run succeeds and creates each artifact with a numeric ID and SHA-256 digest. Check the cache inventory for that ref before rerunning. Record the run URL, attempt number, fixture commit and toolkit commit.
2. **Warm cache and successful build.** Rerun all jobs in the original default-branch push after it finishes. Expect `hit` on each lane with the same dependency inputs. Verify the download and smoke steps still pass. Retried uploads append `-attempt-N` to avoid reusing artifact names. Record artifact IDs during each attempt because the download inventory can change after a rerun. A manual call with the default input or a pull request exercises cache-disabled behavior. If testing invalidation, make a reviewed dependency update and capture a changed cache key, a miss and a successful build.
3. **Deliberately failing test.** In a separate synthetic branch, change the expected greeting in the Go `main_test.go` or Java `src/test/java/example/ci/MainTest.java`, keeping the application unchanged. Verify that the Go lane reports `go test failed.` or that Maven logs the JUnit assertion failure and reports `Maven clean verify failed.` In both cases, confirm that the failed language job uploads no artifact and creates no branch cache.
4. **Absent root configuration.** In another synthetic branch, omit `go.mod` or `pom.xml` from the respective fixture. Expect the Go diagnostic `Required caller root go.mod is missing.` or the Java diagnostic `A regular caller root pom.xml is required.` Verify that the workflow stops before building or uploading.
5. **Token permissions.** Inspect `GITHUB_TOKEN Permissions` in the hosted job setup log. Confirm that contents access is read-only and no write scope is granted. The fixture workflows use their same-run artifact access and pass no caller secrets. Check that the source and logs are suitable for the intended visibility before including evidence in release materials.

For an independent manual cache check, use a personally owned fixture repository with fresh default-branch cache keys. Pass `cache-on-owner-dispatch: true` to the reusable jobs and dispatch the same default-branch checkout twice as the repository owner. Check the miss and saved key in the first run and restoration of that exact key in the second. Start two fresh runs because retries of manual runs are uncached. Verify the artifacts in both runs. This checks the dependency cache path through `workflow_dispatch`. Record automatic push scheduling separately.

Record runner labels, run and job URLs, cache status, artifact IDs, archive digests, and diagnostics. Publish links from the public test repository after reviewing the logs. Summarize the outcome in [Release evidence](RELEASE_EVIDENCE.md). Artifact downloads are subject to repository access and retention. The workflow's default-branch policy and GitHub's repository/ref cache scope keep the independent fixtures' cache tests isolated. [GitHub Actions artifacts](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts) · [Dependency cache scope](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching)

## Identify the required checks

The toolkit expects `verify / Run caller verifier on Windows` and `Java workflow contract`. Confirm both names and successful results in this repository before making them required checks.

Inspect a representative pull-request run for the exact commit proposed for the default branch. The Jobs list displays actual check names, including the caller job and called job for reusable workflows. Record the names and conclusions from GitHub, then require the checks that represent the toolkit's own CI suite. A fixture repository has separate check names and its own settings. Use unique job names within each repository so a required check resolves to its intended workflow. [GitHub required status checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches#require-status-checks-before-merging)

```console
gh api "repos/OWNER/REPO/actions/runs/RUN_ID/jobs?per_page=100" --jq '.jobs[] | [.name, .conclusion] | @tsv'
```

## Protect the toolkit's default branch

When eligible, target `main` and apply these settings.

- Require a pull request before merging. The solo-maintainer policy specifies zero separate required approvals.
- Require the exact successful CI checks observed on the toolkit pull request. Select GitHub Actions as the source where supported. Require branches to be up to date before merging.
- Require conversation resolution and enforce the rule for administrators without a bypass.
- Disable force pushes and branch deletion.
- Allow merge commits to preserve both original parents and existing commit hashes. After approval, verify the merge commit and its post-merge main CI.

Re-read the resulting protection rule and confirm the required check names match GitHub. Verify that pending or failed required checks prevent merging in repository settings where the feature is available. [GitHub protected branch settings](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
