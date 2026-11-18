# diq-standards

Source of truth for engineering standards, lint rules, commit conventions, GitHub rulesets,
and the shared `disputeiq-engineering` AI agent skill across `disputeiq-platform`.

## Key paths
- `.agents/skills/disputeiq-engineering/SKILL.md`: Organization-wide engineering skill synced to all repos.
- `config/checkstyle/checkstyle.xml`: Shared Checkstyle ruleset (packaged by `diq-build-config`).
- `config/commitlint/commitlint.config.mjs`: Conventional Commits enforcement rules.
- `config/lefthook/`: Pre-commit, commit-msg, and pre-push hook templates for Java and TypeScript repos.
- `templates/maven/`: Self-contained `mvnw.cmd`, `mvnw`, and `.mvn/jvm.config` pinned to JDK 21 + Maven 3.9.5.
- `scripts/ensure-toolchain.ps1`: Installs/verifies portable Eclipse Temurin JDK 21 LTS and Maven 3.9.5.
- `scripts/bootstrap-org.ps1`: Initializes and verifies all polyrepo directories with consistent Git hygiene.
