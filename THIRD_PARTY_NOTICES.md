# Third-party notices

The repository contains original workflow source, tests and examples. The workflow references external actions by commit and installs tools from their upstream distributions. Downloaded tools and dependency implementations are outside the toolkit source archive.

| Component | Use | Upstream license |
| --- | --- | --- |
| GitHub Actions checkout, setup-go, setup-java, upload-artifact, download-artifact | Checkout, toolchains, and CI artifact exchange | MIT. [checkout](https://github.com/actions/checkout/blob/3d3c42e5aac5ba805825da76410c181273ba90b1/LICENSE) · [setup-go](https://github.com/actions/setup-go/blob/d8cbb8045d7f43706b9177cceb36c1f91a6644d5/LICENSE) · [setup-java](https://github.com/actions/setup-java/blob/d1374f8ac74474200d16ef8ecee22c7ae7a51880/LICENSE) · [upload-artifact](https://github.com/actions/upload-artifact/blob/cf430e030ddbb5b0abf93d22962f4752f3646cd9/LICENSE) · [download-artifact](https://github.com/actions/download-artifact/blob/9000827ccba6bdab643e8b6fd33ac0654aef8333/LICENSE) |
| actionlint v1.7.12 | Validation tool | [MIT](https://github.com/rhysd/actionlint/blob/v1.7.12/LICENSE.txt) |
| Go and govulncheck v1.10.0 | Toolchain and Go dependency scan | BSD-3-Clause. [Go 1.27.4](https://github.com/golang/go/blob/go1.27.4/LICENSE) · [golang.org/x/vuln](https://go.googlesource.com/vuln/+/refs/tags/v1.10.0/LICENSE) |
| Gitleaks v8.30.1 | Secret scan | [MIT](https://github.com/gitleaks/gitleaks/blob/v8.30.1/LICENSE) |
| PowerShell | Verifier language and runtime | [MIT](https://github.com/PowerShell/PowerShell/blob/v7.6.7/LICENSE.txt) |
| Temurin JDK 21 | Hosted Java runtime | [GPLv2 with Classpath and Assembly exceptions as applicable](https://adoptium.net/about/) |
| Apache Maven and its fixture plugins | Java build, tests and lint | [Apache-2.0](https://github.com/apache/maven/blob/maven-3.9.16/LICENSE) |
| JUnit Jupiter 5.13.4 | Java test dependency | [EPL-2.0](https://github.com/junit-team/junit-framework/blob/r5.13.4/LICENSE.md) |
| Checkstyle 14.4.0 | Engine pinned by the Maven fixture's Checkstyle plugin | [LGPL-2.1-or-later](https://github.com/checkstyle/checkstyle/blob/checkstyle-14.4.0/LICENSE) |
| Commons BeanUtils 1.11.0 and Guava 33.7.2-jre | Dependencies of the fixture's Checkstyle engine | Apache-2.0. [Commons BeanUtils](https://commons.apache.org/proper/commons-beanutils/) · [Guava](https://github.com/google/guava/blob/v33.7.2/LICENSE) |
| Commons Lang 3.20.0 | Build-time dependency of the Java fixture's Resources, JAR and Checkstyle plugins | [Apache-2.0](https://commons.apache.org/proper/commons-lang/) |
| Google UUID v1.6.0 | Dependency linked by the Go fixture | [BSD-3-Clause, copyright 2009 and 2014 Google Inc.](https://github.com/google/uuid/blob/v1.6.0/LICENSE) |

The Java fixture JAR is a thin artifact containing its application classes. Java test dependencies and build plugins are used during verification. Redistributing the Go fixture executable requires preserving the applicable notices for its linked Go runtime and Google UUID code. The toolkit release packages fixture source and checksums for dependency resolution.
