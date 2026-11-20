Wie lassen sich CI-Regeln für mehrere Repositories pflegen, ohne jede Workflow-Datei einzeln zu aktualisieren?

Dafür habe ich das Reusable CI Workflow Toolkit für GitHub Actions entwickelt. Ein Repository ruft einen Workflow über workflow_call auf und kann dessen Commit-SHA festschreiben. So entscheidet jedes Team selbst, wann es eine neue Fassung übernimmt.

Der Go-Workflow führt go vet, Tests und einen nativen Build auf Linux oder Windows aus. Der Java-Workflow prüft ein Maven-Projekt mit Java 21 auf Linux und stellt eine JAR bereit. Der Maven-Beispielcode bindet Checkstyle und JUnit in den Build ein.

Beide Workflows liefern Artefaktname, ID, SHA-256-Digest und Cache-Status. Zwei unabhängige Beispielprojekte laden das jeweilige Artefakt im selben Lauf herunter und prüfen seine Ausgabe. Der Abhängigkeitscache ist für Pushes auf den Standardbranch vorgesehen. Das CI-Token hat nur Leserechte für Repository-Inhalte.

Quellcode und Beispiele im Projekt-Repository
https://github.com/soroushneyestani/reusable-ci-workflow-toolkit

#GitHubActions #ContinuousIntegration #DevOps #Java #GoLang
