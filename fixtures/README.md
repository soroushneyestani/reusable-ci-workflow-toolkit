# Independent workflow consumers

Each directory is a standalone application. Copy `go-caller/` and `java-caller/` into separate test repositories, including the hidden `.github` directory. In each `.github/workflows/consumer.yml`, replace `FULL_TOOLKIT_SHA` with the full, reviewed toolkit commit SHA. Use a commit from the public toolkit repository for exact-source preflight. To verify the release reference itself, use `v0.1.0` after the tag is available.

The Go caller invokes the toolkit separately on Linux and Windows. The Java caller uses a Maven build and passes Java 21. Both check the reusable workflow's four outputs, download the same-run artifact and execute it against the fixture's expected greeting.

## Run locally

- Go 1.27.4. From `go-caller/`, run `go vet ./...`, `go test -count=1 ./...` and `go run .`.
- Java 21 and Maven. From `java-caller/`, run `mvn --batch-mode --no-transfer-progress clean verify` and `java -jar target/app.jar`. Maven runs JUnit and Checkstyle during verification.

## Reproduce hosted evidence

1. Push each passing fixture to its own default branch and record the run URL, caller SHA and toolkit SHA. The cache-status marker is emitted by the artifact smoke job only after download and execution pass.
2. Rerun the original default-branch push to exercise a warm cache on the same ref after a cold run has saved the cache. Run a pull request to verify the cache-disabled path. If needed, use a fresh fixture repository to remove unrelated prior cache state.
3. On a separate synthetic branch, change the expected return value in `go-caller/main_test.go` or `java-caller/src/test/java/example/ci/MainTest.java`, leaving the app unchanged. Confirm the failing test prevents an artifact upload.
4. In another branch, omit the root `go.mod` or `pom.xml`. Verify the reusable job rejects the missing configuration before lint, build and upload.
5. To verify invalidation, make a normal fixture dependency change on its default branch. Refresh Go's `go.sum` alongside `go.mod`, or update a pinned Maven dependency in `pom.xml`. Confirm the run uses a different cache key and still passes.

## Fixture dependencies

- Go downloads [Google UUID v1.6.0](https://github.com/google/uuid/tree/v1.6.0) under [BSD-3-Clause](https://github.com/google/uuid/blob/v1.6.0/LICENSE). The fixture tracks its module checksums. When redistributing the Go build, accompany it with the applicable Go runtime and Google UUID BSD notices.
- Java downloads [JUnit Jupiter 5.13.4](https://github.com/junit-team/junit-framework/tree/r5.13.4) under [EPL-2.0](https://github.com/junit-team/junit-framework/blob/r5.13.4/LICENSE.md) as a test-only dependency. The Maven Resources, Compiler, Surefire, JAR and Checkstyle plugins run at build time under Apache-2.0. The fixture pins Checkstyle 14.4.0 for Java 21 and uses Commons Lang 3.20.0 in its Resources, JAR and Checkstyle plugin classpaths. The fixture JAR packages the application classes. [Maven plugins](https://maven.apache.org/plugins/) · [Checkstyle plugin configuration](https://maven.apache.org/plugins/maven-checkstyle-plugin/examples/upgrading-checkstyle.html) · [Third-party notices](../THIRD_PARTY_NOTICES.md)
