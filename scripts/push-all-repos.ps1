<#
.SYNOPSIS
    Configures 'origin' remotes and pushes all 20 DisputeIQ repositories under one GitHub org or GitLab group.
.PARAMETER HostProvider
    Target Git host: 'github' or 'gitlab' (default: github).
.PARAMETER Org
    Target GitHub organization or GitLab group path (default: disputeiq-platform).
.PARAMETER Visibility
    Repository visibility when creating missing repositories: 'public' or 'private' (default: private).
.PARAMETER CreateMissing
    Create missing repositories on the remote org/group using gh/glab CLI or GITHUB_TOKEN / GITLAB_TOKEN.
.PARAMETER DryRun
    Preview remote URLs and push commands without modifying remotes or pushing.
#>
param(
    [ValidateSet("github", "gitlab")]
    [string]$HostProvider = "github",
    [string]$Org = "disputeiq-platform",
    [ValidateSet("public", "private")]
    [string]$Visibility = "private",
    [string]$Root = "D:\Projects\disputeiq",
    [switch]$CreateMissing,
    [switch]$DryRun
)
$ErrorActionPreference = "Stop"

$hostDomain = if ($HostProvider -eq "github") { "github.com" } else { "gitlab.com" }
$repos = Get-ChildItem -Directory $Root | Sort-Object Name

function Ensure-RemoteRepository {
    param([string]$RepoName)

    if (-not $CreateMissing) {
        return
    }
    if ($HostProvider -eq "github") {
        if (Get-Command gh -ErrorAction SilentlyContinue) {
            gh repo view "$Org/$RepoName" 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) {
                $flag = if ($Visibility -eq "public") { "--public" } else { "--private" }
                gh repo create "$Org/$RepoName" $flag --confirm | Out-Null
            }
            return
        }
        $token = $env:GITHUB_TOKEN
        if (-not $token) { $token = $env:GH_TOKEN }
        if ($token) {
            $headers = @{
                Authorization = "Bearer $token"
                Accept        = "application/vnd.github+json"
            }
            $body = @{ name = $RepoName; private = ($Visibility -eq "private") } | ConvertTo-Json
            try {
                Invoke-RestMethod -Method Post -Uri "https://api.github.com/orgs/$Org/repos" -Headers $headers -ContentType "application/json" -Body $body | Out-Null
            } catch {
                if ($_.Exception.Response.StatusCode.value__ -ne 422) { throw }
            }
            return
        }
        throw "CreateMissing requested for GitHub, but neither 'gh' CLI nor GITHUB_TOKEN is available."
    }

    if (Get-Command glab -ErrorAction SilentlyContinue) {
        $flag = if ($Visibility -eq "public") { "--public" } else { "--private" }
        glab repo create "$Org/$RepoName" $flag 2>$null | Out-Null
        return
    }
    throw "CreateMissing requested for GitLab, but 'glab' CLI is not installed."
}

$pushed = 0
foreach ($repo in $repos) {
    $repoName = $repo.Name
    $remoteUrl = "https://$hostDomain/$Org/$repoName.git"
    $branch = git -C $repo.FullName rev-parse --abbrev-ref HEAD

    if ($DryRun) {
        Write-Host "[DRY-RUN] $repoName ($branch) -> $remoteUrl"
        $pushed++
        continue
    }

    Ensure-RemoteRepository -RepoName $repoName

    $existingOrigin = git -C $repo.FullName remote 2>$null | Where-Object { $_ -eq "origin" }
    if ($existingOrigin) {
        git -C $repo.FullName remote set-url origin $remoteUrl | Out-Null
    } else {
        git -C $repo.FullName remote add origin $remoteUrl | Out-Null
    }

    Write-Host "Pushing $repoName ($branch) -> $remoteUrl ..."
    git -C $repo.FullName push -u origin $branch
    $pushed++
}

Write-Host ""
Write-Host "Completed remote sync for $pushed / $($repos.Count) repositories under https://$hostDomain/$Org"
