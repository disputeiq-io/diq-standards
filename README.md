# diq-standards

Central engineering standards and developer-experience tooling for the **DisputeIQ** platform (`disputeiq-platform`).

## Contents

- **Agent Skill**: [SKILL.md](.agents/skills/disputeiq-engineering/SKILL.md)
- **Checkstyle**: [checkstyle.xml](config/checkstyle/checkstyle.xml)
- **Commitlint & Lefthook**: [commitlint.config.mjs](config/commitlint/commitlint.config.mjs), [lefthook-java.yml](config/lefthook/lefthook-java.yml), [lefthook-web.yml](config/lefthook/lefthook-web.yml)
- **Git & Editor Hygiene**: [.gitignore](config/git/.gitignore), [.gitattributes](config/git/.gitattributes), [.editorconfig](config/git/.editorconfig)
- **GitHub Governance**: [pull_request_template.md](config/github/pull_request_template.md), [CODEOWNERS](config/github/CODEOWNERS), [main-branch-ruleset.json](config/rulesets/main-branch-ruleset.json), [Renovate preset](config/renovate/default.json)
- **Toolchain & Bootstrap Scripts**: [ensure-toolchain.ps1](scripts/ensure-toolchain.ps1), [bootstrap-org.ps1](scripts/bootstrap-org.ps1)

## Quick Start

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\ensure-toolchain.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-org.ps1 -LocalOnly
```
