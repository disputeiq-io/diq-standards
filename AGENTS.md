# diq-standards

Source of truth for engineering standards, lint rules, commit conventions, GitHub rulesets,
and the shared `disputeiq-engineering` AI agent skill across `disputeiq-io`.

## Key paths
- `.agents/skills/disputeiq-engineering/SKILL.md`: Organization-wide engineering skill synced to all repos.
- `config/checkstyle/checkstyle.xml`: Shared Checkstyle ruleset (packaged by `diq-build-config`).
- `config/commitlint/commitlint.config.mjs`: Conventional Commits enforcement rules.
- `config/lefthook/`: Pre-commit, commit-msg, and pre-push hook templates for Java and TypeScript repos.
- `templates/gradle/`: Self-contained `gradlew.bat`, `gradlew`, and wrapper properties pinned to JDK 21 + Gradle 8.10.2.
- `config/gradle/java-conventions.gradle`: Shared Gradle conventions (Java 21, Checkstyle, Spotless, JaCoCo).
- `scripts/ensure-toolchain.ps1`: Installs/verifies portable Eclipse Temurin JDK 21 LTS and Gradle 8.10.2.
- `scripts/bootstrap-org.ps1`: Initializes and verifies all polyrepo directories with consistent Git hygiene.
