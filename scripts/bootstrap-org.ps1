<#
.SYNOPSIS
    Bootstraps and synchronizes all 20 repositories of the DisputeIQ polyrepo workspace (Gradle + Node).
#>
param(
    [string]$Org = "disputeiq-platform",
    [string]$Root = "D:\Projects\disputeiq",
    [switch]$LocalOnly,
    [switch]$SkipCommit
)
$ErrorActionPreference = "Stop"

$StandardsDir = Join-Path $Root "diq-standards"
$TemplateJavaDir = Join-Path $Root "diq-template-java"
$TemplateWebDir = Join-Path $Root "diq-template-web"
$SkillSrc = Join-Path $StandardsDir ".agents\skills\disputeiq-engineering\SKILL.md"
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

if (-not (Test-Path $SkillSrc)) {
    throw "Cannot find canonical SKILL.md at $SkillSrc"
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $normalized = $Content -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($Path, $normalized, $Utf8NoBom)
}

$javaServices = @(
    @{ Name = "diq-gateway";              Pkg = "gateway";      Class = "GatewayApplication";      Port = 8080; Db = "Redis / Valkey";                Domain = "Edge gateway, JWT tenant resolution, per-tenant rate limits, and idempotency"; Publishes = "None"; Consumes = "None" }
    @{ Name = "diq-tenant-service";       Pkg = "tenant";       Class = "TenantApplication";       Port = 8081; Db = "PostgreSQL (tenant_db)";        Domain = "Tenants, plans, user-tenant mappings, quotas, and LLM budgets";              Publishes = "tenant.lifecycle.v1"; Consumes = "None" }
    @{ Name = "diq-dispute-service";      Pkg = "dispute";      Class = "DisputeApplication";      Port = 8082; Db = "PostgreSQL (dispute_db, RLS)";  Domain = "Case aggregate, lifecycle state machine, SLA deadlines, and outbox";          Publishes = "dispute.case.filed.v1, dispute.case.state-changed.v1, dispute.case.decided.v1, dispute.sla.breach-warning.v1"; Consumes = "ai.recommendation.generated.v1, document.evidence.extracted.v1" }
    @{ Name = "diq-document-service";     Pkg = "document";     Class = "DocumentApplication";     Port = 8083; Db = "MinIO + PostgreSQL (doc_db)";   Domain = "Presigned S3 evidence uploads, Tika parsing, IDP extraction, PII redaction";  Publishes = "document.evidence.uploaded.v1, document.evidence.extracted.v1"; Consumes = "dispute.case.filed.v1" }
    @{ Name = "diq-knowledge-service";    Pkg = "knowledge";    Class = "KnowledgeApplication";    Port = 8084; Db = "PostgreSQL + pgvector (RLS)";   Domain = "Rulebook, policy, and precedent ingestion plus hybrid RAG retrieval API";      Publishes = "knowledge.source.ingested.v1"; Consumes = "knowledge.source.uploaded.v1, dispute.case.decided.v1" }
    @{ Name = "diq-agent-service";        Pkg = "agent";        Class = "AgentApplication";        Port = 8085; Db = "PostgreSQL (agent_db)";         Domain = "LangGraph4j triage and drafting graphs, tools, Case Copilot, and CI evals";     Publishes = "ai.case.triaged.v1, ai.recommendation.generated.v1"; Consumes = "dispute.case.filed.v1, document.evidence.extracted.v1" }
    @{ Name = "diq-notification-service"; Pkg = "notification"; Class = "NotificationApplication"; Port = 8086; Db = "Redis fan-out";                 Domain = "Live SSE push updates to diq-web, email notifications, and SLA alerts";        Publishes = "None"; Consumes = "dispute.*, ai.*, knowledge.source.ingested.v1" }
    @{ Name = "diq-network-simulator";    Pkg = "simulator";    Class = "SimulatorApplication";    Port = 8087; Db = "In-memory";                     Domain = "Simulated card-network feed intentionally emitting retries and duplicates";    Publishes = "None (calls diq-gateway)"; Consumes = "dispute.case.decided.v1" }
)

$scaffoldRepos = @(
    @{ Name = "diq-event-schemas"; Description = "Avro event schemas, CloudEvents contracts, and Apicurio compatibility checks"; Dirs = @("schemas/dispute", "schemas/document", "schemas/ai", "schemas/knowledge", "schemas/tenant") }
    @{ Name = "diq-helm-library";  Description = "Shared Helm library chart templates (Deployment, Rollout, HPA, PDB, AuthorizationPolicy)"; Dirs = @("templates") }
    @{ Name = "diq-gitops";        Description = "Argo CD bootstrap, ApplicationSets, env release manifests, Kargo stages, and Kyverno policies"; Dirs = @("bootstrap", "platform/wave-0-crds", "platform/wave-1-operators", "platform/wave-2-shared", "appsets", "envs/dev/apps", "envs/dev/values", "envs/staging/apps", "envs/staging/values", "envs/prod/apps", "envs/prod/values", "kargo", "policies", "charts/diq-stack") }
    @{ Name = "diq-e2e";           Description = "End-to-end Playwright journeys, k6 virtual-thread benchmarks, and chaos drills"; Dirs = @("playwright", "k6", "chaos") }
)

function Sync-CommonGovernance {
    param([string]$RepoPath, [string]$RepoName)

    Copy-Item (Join-Path $StandardsDir "config\git\.gitignore") (Join-Path $RepoPath ".gitignore") -Force
    Copy-Item (Join-Path $StandardsDir "config\git\.gitattributes") (Join-Path $RepoPath ".gitattributes") -Force
    Copy-Item (Join-Path $StandardsDir "config\git\.editorconfig") (Join-Path $RepoPath ".editorconfig") -Force
    Copy-Item (Join-Path $StandardsDir "config\commitlint\commitlint.config.mjs") (Join-Path $RepoPath "commitlint.config.mjs") -Force

    $renovateContent = @"
{
  "`$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>$Org/diq-standards:config/renovate/default.json"]
}
"@
    Write-Utf8NoBom -Path (Join-Path $RepoPath "renovate.json") -Content $renovateContent

    $ghDir = Join-Path $RepoPath ".github"
    New-Item -ItemType Directory -Force -Path $ghDir | Out-Null
    Copy-Item (Join-Path $StandardsDir "config\github\pull_request_template.md") (Join-Path $ghDir "pull_request_template.md") -Force
    Copy-Item (Join-Path $StandardsDir "config\github\CODEOWNERS") (Join-Path $ghDir "CODEOWNERS") -Force

    if ($RepoName -ne "diq-standards") {
        $skillDstDir = Join-Path $RepoPath ".agents\skills\disputeiq-engineering"
        New-Item -ItemType Directory -Force -Path $skillDstDir | Out-Null
        Copy-Item $SkillSrc (Join-Path $skillDstDir "SKILL.md") -Force
    }
}

function Sync-JavaTooling {
    param([string]$RepoPath)
    Copy-Item (Join-Path $StandardsDir "config\lefthook\lefthook-java.yml") (Join-Path $RepoPath "lefthook.yml") -Force
    Copy-Item (Join-Path $StandardsDir "templates\gradle\gradlew.bat") (Join-Path $RepoPath "gradlew.bat") -Force
    Copy-Item (Join-Path $StandardsDir "templates\gradle\gradlew") (Join-Path $RepoPath "gradlew") -Force

    $wrapperDir = Join-Path $RepoPath "gradle\wrapper"
    New-Item -ItemType Directory -Force -Path $wrapperDir | Out-Null
    Copy-Item (Join-Path $StandardsDir "templates\gradle\gradle\wrapper\gradle-wrapper.properties") (Join-Path $wrapperDir "gradle-wrapper.properties") -Force
    Copy-Item (Join-Path $StandardsDir "config\gradle\java-conventions.gradle") (Join-Path $RepoPath "gradle\java-conventions.gradle") -Force

    $checkstyleDir = Join-Path $RepoPath "config\checkstyle"
    New-Item -ItemType Directory -Force -Path $checkstyleDir | Out-Null
    Copy-Item (Join-Path $StandardsDir "config\checkstyle\checkstyle.xml") (Join-Path $checkstyleDir "checkstyle.xml") -Force

    # Remove legacy Maven build files if migrating an existing repo
    Remove-Item -Recurse -Force (Join-Path $RepoPath "pom.xml"), (Join-Path $RepoPath "mvnw"), (Join-Path $RepoPath "mvnw.cmd"), (Join-Path $RepoPath ".mvn"), (Join-Path $RepoPath "target") -ErrorAction SilentlyContinue
}

function Sync-WebTooling {
    param([string]$RepoPath)
    Copy-Item (Join-Path $StandardsDir "config\lefthook\lefthook-web.yml") (Join-Path $RepoPath "lefthook.yml") -Force
}

function Write-CatalogInfo {
    param([string]$RepoPath, [string]$Name, [string]$Description, [string]$Type)
    $catalog = @"
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: $Name
  description: $Description
spec:
  type: $Type
  lifecycle: experimental
  owner: platform-team
  system: disputeiq
"@
    Write-Utf8NoBom -Path (Join-Path $RepoPath "catalog-info.yaml") -Content $catalog
}

function Ensure-JavaServiceGradle {
    param($svc)
    $repoPath = Join-Path $Root $svc.Name
    $isNew = -not (Test-Path (Join-Path $repoPath "src"))
    New-Item -ItemType Directory -Force -Path $repoPath | Out-Null

    if (-not (Test-Path (Join-Path $repoPath "settings.gradle"))) {
        Write-Utf8NoBom -Path (Join-Path $repoPath "settings.gradle") -Content "rootProject.name = '$($svc.Name)'`n"
    }
    if (-not (Test-Path (Join-Path $repoPath "build.gradle"))) {
        Copy-Item (Join-Path $TemplateJavaDir "build.gradle") (Join-Path $repoPath "build.gradle") -Force
    }

    if ($isNew) {
        $resDir = Join-Path $repoPath "src\main\resources"
        New-Item -ItemType Directory -Force -Path $resDir | Out-Null
        $appYml = (Get-Content (Join-Path $TemplateJavaDir "src\main\resources\application.yml") -Raw) `
            -replace 'name: diq-template-java', "name: $($svc.Name)" `
            -replace 'port: 8080', "port: $($svc.Port)"
        Write-Utf8NoBom -Path (Join-Path $resDir "application.yml") -Content $appYml

        $srcBase = Join-Path $TemplateJavaDir "src\main\java\io\disputeiq\template"
        $dstBase = Join-Path $repoPath "src\main\java\io\disputeiq\$($svc.Pkg)"
        foreach ($sub in @("", "api", "application", "domain", "infrastructure")) {
            $srcDir = if ($sub) { Join-Path $srcBase $sub } else { $srcBase }
            $dstDir = if ($sub) { Join-Path $dstBase $sub } else { $dstBase }
            New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
            Get-ChildItem $srcDir -Filter "*.java" | ForEach-Object {
                $targetName = if ($_.Name -eq "TemplateApplication.java") { "$($svc.Class).java" } else { $_.Name }
                $content = (Get-Content $_.FullName -Raw) `
                    -replace 'io\.disputeiq\.template', "io.disputeiq.$($svc.Pkg)" `
                    -replace 'TemplateApplication', $svc.Class
                Write-Utf8NoBom -Path (Join-Path $dstDir $targetName) -Content $content
            }
        }

        $testSrcDir = Join-Path $TemplateJavaDir "src\test\java\io\disputeiq\template"
        $testDstDir = Join-Path $repoPath "src\test\java\io\disputeiq\$($svc.Pkg)"
        New-Item -ItemType Directory -Force -Path $testDstDir | Out-Null
        Get-ChildItem $testSrcDir -Filter "*.java" | ForEach-Object {
            $content = (Get-Content $_.FullName -Raw) `
                -replace 'io\.disputeiq\.template', "io.disputeiq.$($svc.Pkg)" `
                -replace 'TemplateApplication', $svc.Class `
                -replace '"diq-template-java"', "`"$($svc.Name)`""
            Write-Utf8NoBom -Path (Join-Path $testDstDir $_.Name) -Content $content
        }
    }

    $wfDir = Join-Path $repoPath ".github\workflows"
    New-Item -ItemType Directory -Force -Path $wfDir | Out-Null
    $ciYml = @"
name: ci
on:
  pull_request:
  push:
    branches: [main]

jobs:
  pipeline:
    uses: $Org/.github/.github/workflows/java-service.yml@main
    with:
      service_name: $($svc.Name)
      publish: `${{ github.ref == 'refs/heads/main' }}
"@
    Write-Utf8NoBom -Path (Join-Path $wfDir "ci.yml") -Content $ciYml

    $agentsMd = @"
# $($svc.Name)

- **Role**: $($svc.Domain)
- **Port**: $($svc.Port)
- **Backing Store**: $($svc.Db)
- **Publishes**: $($svc.Publishes)
- **Consumes**: $($svc.Consumes)
- **Verification**: ``.\gradlew.bat check``

Follow ``.agents/skills/disputeiq-engineering/SKILL.md``.
"@
    Write-Utf8NoBom -Path (Join-Path $repoPath "AGENTS.md") -Content $agentsMd

    $readmeMd = @"
# $($svc.Name)

$($svc.Domain)

- **Port**: $($svc.Port)
- **Backing Store**: $($svc.Db)

## Verify

``````powershell
.\gradlew.bat check
``````
"@
    Write-Utf8NoBom -Path (Join-Path $repoPath "README.md") -Content $readmeMd
    Write-CatalogInfo -RepoPath $repoPath -Name $svc.Name -Description $svc.Domain -Type "service"
}

function New-WebAppFromTemplate {
    $repoPath = Join-Path $Root "diq-web"
    if (-not (Test-Path (Join-Path $repoPath "package.json"))) {
        New-Item -ItemType Directory -Force -Path $repoPath | Out-Null
        Get-ChildItem $TemplateWebDir -Force | Where-Object { $_.Name -notin @("node_modules", "dist", ".git", "coverage") } | ForEach-Object {
            Copy-Item $_.FullName (Join-Path $repoPath $_.Name) -Recurse -Force
        }
        $pkgJson = (Get-Content (Join-Path $repoPath "package.json") -Raw) -replace '"@disputeiq/template-web"', '"@disputeiq/web"'
        Write-Utf8NoBom -Path (Join-Path $repoPath "package.json") -Content $pkgJson
    }
}

function Initialize-ScaffoldRepo {
    param($spec)
    $repoPath = Join-Path $Root $spec.Name
    New-Item -ItemType Directory -Force -Path $repoPath | Out-Null
    foreach ($dir in $spec.Dirs) {
        $d = Join-Path $repoPath $dir
        New-Item -ItemType Directory -Force -Path $d | Out-Null
        $gitkeep = Join-Path $d ".gitkeep"
        if (-not (Test-Path $gitkeep)) {
            Write-Utf8NoBom -Path $gitkeep -Content ""
        }
    }
    if (-not (Test-Path (Join-Path $repoPath "AGENTS.md"))) {
        Write-Utf8NoBom -Path (Join-Path $repoPath "AGENTS.md") -Content "# $($spec.Name)`n`n$($spec.Description)`n`nFollow ``.agents/skills/disputeiq-engineering/SKILL.md``."
    }
    if (-not (Test-Path (Join-Path $repoPath "README.md"))) {
        Write-Utf8NoBom -Path (Join-Path $repoPath "README.md") -Content "# $($spec.Name)`n`n$($spec.Description)"
    }
    Write-CatalogInfo -RepoPath $repoPath -Name $spec.Name -Description $spec.Description -Type "library"
}

function Initialize-GitRepo {
    param([string]$RepoPath, [string]$CommitMsg)

    if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
        git -C $RepoPath init -b main | Out-Null
    }
    git -C $RepoPath config core.autocrlf false
    git -C $RepoPath config core.eol lf
    git -C $RepoPath config pull.rebase true
    git -C $RepoPath config rebase.autoStash true
    git -C $RepoPath config commit.gpgsign false

    if (-not $SkipCommit) {
        $status = git -C $RepoPath status --porcelain
        if ($status) {
            git -C $RepoPath add -A
            git -C $RepoPath commit -m $CommitMsg -m "Refs: DIQ-001" -m "Assisted-by: Antigravity" | Out-Null
        }
    }
}

foreach ($svc in $javaServices) {
    Ensure-JavaServiceGradle -svc $svc
}
New-WebAppFromTemplate
foreach ($spec in $scaffoldRepos) {
    Initialize-ScaffoldRepo -spec $spec
}

$allRepos = @(
    @{ Name = "diq-standards";            Kind = "docs"; Msg = "build(gradle): replace Maven tooling with Gradle 8.10.2 conventions and skill updates" }
    @{ Name = "diq-org-github";           Kind = "docs"; Msg = "ci(gradle): update reusable Java workflow to Gradle 8.10.2" }
    @{ Name = "diq-architecture";         Kind = "docs"; Msg = "docs(skills): sync Gradle-updated engineering skill" }
    @{ Name = "diq-platform-libs";        Kind = "java"; Msg = "build(gradle): migrate diq-platform-libs to Gradle with mavenLocal publishing" }
    @{ Name = "diq-template-java";        Kind = "java"; Msg = "build(gradle): migrate diq-template-java from Maven to Gradle 8.10.2" }
    @{ Name = "diq-template-web";         Kind = "web";  Msg = "docs(skills): sync Gradle-updated engineering skill" }
    @{ Name = "diq-infra";                Kind = "docs"; Msg = "chore(infra): sync updated engineering skill and Gradle toolchain check" }
    @{ Name = "diq-event-schemas";        Kind = "docs"; Msg = "docs(skills): sync Gradle-updated engineering skill" }
    @{ Name = "diq-helm-library";         Kind = "docs"; Msg = "docs(skills): sync Gradle-updated engineering skill" }
    @{ Name = "diq-gitops";               Kind = "docs"; Msg = "docs(skills): sync Gradle-updated engineering skill" }
    @{ Name = "diq-e2e";                  Kind = "docs"; Msg = "docs(skills): sync Gradle-updated engineering skill" }
    @{ Name = "diq-web";                  Kind = "web";  Msg = "docs(skills): sync Gradle-updated engineering skill" }
)
foreach ($svc in $javaServices) {
    $allRepos += @{ Name = $svc.Name; Kind = "java"; Msg = "build(gradle): migrate $($svc.Name) from Maven to Gradle 8.10.2" }
}

foreach ($repo in $allRepos) {
    $path = Join-Path $Root $repo.Name
    Sync-CommonGovernance -RepoPath $path -RepoName $repo.Name
    if ($repo.Kind -eq "java") {
        Sync-JavaTooling -RepoPath $path
    }
    elseif ($repo.Kind -eq "web") {
        Sync-WebTooling -RepoPath $path
    }
    Initialize-GitRepo -RepoPath $path -CommitMsg $repo.Msg
}

Write-Host "Synchronized $($allRepos.Count) DisputeIQ repositories to Gradle tooling."
