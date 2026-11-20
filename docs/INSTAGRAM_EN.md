I built the Reusable CI Workflow Toolkit to make one reviewed GitHub Actions workflow usable from multiple repositories.

The Go workflow runs vet, tests and a native build on Linux or Windows. The Java workflow verifies a Maven project on Linux with Java 21 and stages its JAR. Both return artifact metadata and cache status. The independent example callers download the artifact in the same run and execute it to check the result.

Two choices mattered in the design. Callers can pin the exact workflow commit, and dependency caching is limited to default-branch pushes. That gives teams a repeatable adoption path while keeping build configuration in the repository that owns it.

Project notes and examples are in the repository.
https://github.com/soroushneyestani/reusable-ci-workflow-toolkit

#GitHubActions #ContinuousIntegration #DevOps #GoLang #Java #SoftwareEngineering
