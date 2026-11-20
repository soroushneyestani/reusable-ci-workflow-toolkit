# Release evidence

## Candidate scope

Proposed initial version `v0.1.0`. The release contains workflow source, tests, independent Go and Java fixture definitions, documentation and license material. Workflow-produced binaries and JARs are consumer artifacts.

## Local checks

| Check | Verified outcome |
| --- | --- |
| Action definitions | Pinned actionlint v1.7.12 accepted all four toolkit workflows and rejected a deliberately invalid workflow. |
| Windows wrapper | Five cases passed, including child-process execution from the caller root, nonzero exit, thrown error, absent script, and directory at the expected path. Two distinct Go executables on PATH reproduced the selection regression and the corrected verifier passed. |
| Go | Six run-block fixtures passed, including build and execution, missing module, library root, vet failure, test failure, and linker failure. Eight metadata cases passed, covering version, runner, restricted event, and artifact naming. |
| Windows PowerShell | Full toolkit verifier passed on Windows PowerShell 5.1 and PowerShell 7.6.7 with Go 1.27.4. |
| Java | Maven 3.9.16, JDK 21 and PowerShell 7.6.7 passed invocation and POM checks, staged an executable JAR with matching SHA-256, and rejected real JUnit and Checkstyle failures and a renamed JAR. |
| Independent caller fixtures | Go vet, uncached tests and executable output passed locally. Maven clean verify passed one JUnit test and Checkstyle, and the JAR printed the expected output. Rendered caller YAML passed actionlint. |

## Dependency verification

The hosted Java build, toolkit Java contract job, and fixture JAR smoke test request Temurin `21.0.13.1+2` from the pinned setup action. This selects the Adoptium security update. The reusable workflow still accepts major version `21` as its public input. [Adoptium security advisory](https://adoptium.net/news/2026/11/temurin-november-2026-cspu-java4shell/) · [Setup action version syntax](https://github.com/actions/setup-java/blob/d1374f8ac74474200d16ef8ecee22c7ae7a51880/README.md#supported-version-syntax)

A clean Maven 3.9.16 build with JDK 21 resolved Checkstyle 14.4.0, Commons BeanUtils 1.11.0 and Guava 33.7.2-jre in the Checkstyle plugin classpath. The Resources, JAR, and Checkstyle plugin classpaths loaded Commons Lang 3.20.0. The older versions subject to the reviewed advisories were absent from those classpaths. The full local Java contract suite passed with the updated fixture, including failure for a bad JUnit assertion, a lint violation, and a missing JAR. The source package excludes downloaded dependencies and fixture binaries. [Upstream notices](../THIRD_PARTY_NOTICES.md) · [Checkstyle dependency override](https://maven.apache.org/plugins/maven-checkstyle-plugin/examples/upgrading-checkstyle.html) · [Commons Lang security notices](https://commons.apache.org/proper/commons-lang/security.html)

## Hosted evidence

Before public distribution, two independent synthetic consumer repositories exercised the reviewed workflows through `workflow_call`. The toolkit's Windows verifier and Java workflow contract also passed on both a push and a pull request.

| Consumer platform | First attempt | Repeat attempt | Artifact smoke |
| --- | --- | --- | --- |
| Go on Ubuntu 24.04 | Cache miss | Cache hit | Downloaded and executed the Linux application in both attempts. |
| Go on Windows 2025 | Cache miss | Cache hit | Downloaded and executed the Windows application in both attempts. |
| Java 21 and Maven on Ubuntu 24.04 | Cache miss | Cache hit | Downloaded and executed the JAR in both attempts. |

Each downstream smoke job consumed the reusable workflow's artifact name, ID, digest, and cache status. Every executed consumer job logged only `Contents: read` and `Metadata: read`. The completed positive Go runs passed dependency and redacted Git history checks on both platforms. The three retained warm-attempt archives passed an independent archive SHA-256, CRC, and payload type check.

The Java consumer was also rerun with the reviewed Maven plugin dependencies. The changed POM created a new cache entry after a miss. The same commit then hit the cache. Both attempts downloaded and ran the JAR. The bad JUnit assertion and missing POM scenarios still failed without an artifact. The Go workflow and Go fixture were unchanged.

| Deliberate negative scenario | Observed diagnostic |
| --- | --- |
| Go test assertion on both supported runners | `go test failed.` |
| Missing root Go module | `Required caller root go.mod is missing.` |
| Java JUnit assertion | `Maven clean verify failed.` |
| Missing root Maven configuration | `A regular caller root pom.xml is required.` |

All four negative runs produced zero artifacts and zero branch cache entries. These are pre-distribution results for the reviewed source. Fresh CI and independent public consumer runs are part of the release procedure. The fixture source, reproduction procedure, and observed results are documented here. [Consumer fixtures](../fixtures/README.md) · [Hosted procedure](HOSTED_VERIFICATION.md)

The same-ref reruns establish cache restoration. The recorded matrix includes Maven cache invalidation after a dependency change. It does not include a Go dependency-key change or a passing pull request with cache disabled.

## Release constraints

The workflow contracts target hosted Ubuntu and Windows for Go and hosted Ubuntu with Temurin 21 for Java. GitHub manages runner and cache availability. A passing Maven pipeline runs the caller-selected quality gates. The source license and dependency notices accompany the final source archive. [Contracts](SPEC.md) · [Candidate release notes](releases/v0.1.0.md)

Build the candidate archive from the full reviewed documentation and source commit with `python scripts/package-source.py FULL_CANDIDATE_SHA`. The script checks each archived file against the corresponding Git blob, verifies ZIP integrity, and writes `SHA256SUMS.txt`. Consumer work products are tracked through their separate Actions evidence. [Packaging script](../scripts/package-source.py)
