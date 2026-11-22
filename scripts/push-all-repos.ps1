<#
.SYNOPSIS
    Configures 'origin' remotes and pushes all 20 DisputeIQ repositories under one GitHub org or GitLab group.
.PARAMETER HostProvider
    Target Git host: 'github' or 'gitlab' (default: github).
.PARAMETER Org
    Target GitHub organization or GitLab group path (default: disputeiq-io).
.PARAMETER Visibility
    Repository visibility when creating missing repositories: 'public' or 'private' (default: public).
.PARAMETER CreateMissing
    Create missing repositories on the remote org/group using gh/glab CLI or GITHUB_TOKEN / GH_TOKEN.
.PARAMETER DryRun
    Preview remote URLs and push commands without modifying remotes or pushing.
#>
param(
    [ValidateSet("github", "gitlab")]
    [string]$HostProvider = "github",
    [string]$Org = "disputeiq-io",
    [ValidateSet("public", "private")]
    [string]$Visibility = "public",
    [string]$Root = "D:\Projects\disputeiq",
    [switch]$CreateMissing,
    [switch]$DryRun
)
$ErrorActionPreference = "Stop"
$env:GIT_TERMINAL_PROMPT = "0"

$hostDomain = if ($HostProvider -eq "github") { "github.com" } else { "gitlab.com" }
$repos = Get-ChildItem -Directory $Root |
    Sort-Object @{ Expression = { if ($_.Name -eq "diq-org-github") { "000" } else { $_.Name } } }

function Resolve-GhExecutable {
    $cmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $defaultPath = "C:\Program Files\GitHub CLI\gh.exe"
    if (Test-Path $defaultPath) { return $defaultPath }
    return $null
}

function Get-GitHubToken {
    if ($env:GH_TOKEN) { return $env:GH_TOKEN }
    if ($env:GITHUB_TOKEN) { return $env:GITHUB_TOKEN }
    return $null
}

$ghExe = Resolve-GhExecutable
$ghToken = Get-GitHubToken

function Ensure-RemoteRepository {
    param([string]$RemoteRepoName)

    if (-not $CreateMissing) {
        return
    }
    if ($HostProvider -eq "github") {
        if ($ghExe) {
            $prevPref = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            & $ghExe repo view "$Org/$RemoteRepoName" *> $null
            $viewExit = $LASTEXITCODE
            $ErrorActionPreference = $prevPref
            if ($viewExit -ne 0) {
                $flag = if ($Visibility -eq "public") { "--public" } else { "--private" }
                $ErrorActionPreference = "Continue"
                & $ghExe repo create "$Org/$RemoteRepoName" $flag
                $createExit = $LASTEXITCODE
                $ErrorActionPreference = $prevPref
                if ($createExit -ne 0) {
                    throw "Failed to create GitHub repository $Org/$RemoteRepoName via gh CLI."
                }
            }
            return
        }
        if ($ghToken) {
            $headers = @{
                Authorization = "Bearer $ghToken"
                Accept        = "application/vnd.github+json"
            }
            $body = @{ name = $RemoteRepoName; private = ($Visibility -eq "private") } | ConvertTo-Json
            try {
                Invoke-RestMethod -Method Post -Uri "https://api.github.com/orgs/$Org/repos" -Headers $headers -ContentType "application/json" -Body $body | Out-Null
            } catch {
                if ($_.Exception.Response.StatusCode.value__ -ne 422) { throw }
            }
            return
        }
        throw "CreateMissing requested for GitHub, but neither 'gh' CLI nor GH_TOKEN/GITHUB_TOKEN is available."
    }

    if (Get-Command glab -ErrorAction SilentlyContinue) {
        $flag = if ($Visibility -eq "public") { "--public" } else { "--private" }
        glab repo create "$Org/$RemoteRepoName" $flag 2>$null | Out-Null
        return
    }
    throw "CreateMissing requested for GitLab, but 'glab' CLI is not installed."
}

$pushed = 0
foreach ($repo in $repos) {
    $localName = $repo.Name
    $remoteRepoName = if ($HostProvider -eq "github" -and $localName -eq "diq-org-github") { ".github" } else { $localName }
    $remoteUrl = "https://$hostDomain/$Org/$remoteRepoName.git"
    $branch = git -C $repo.FullName rev-parse --abbrev-ref HEAD

    if ($DryRun) {
        Write-Host "[DRY-RUN] $localName ($branch) -> $remoteUrl"
        $pushed++
        continue
    }

    Ensure-RemoteRepository -RemoteRepoName $remoteRepoName

    $existingOrigin = git -C $repo.FullName remote 2>$null | Where-Object { $_ -eq "origin" }
    if ($existingOrigin) {
        git -C $repo.FullName remote set-url origin $remoteUrl | Out-Null
    } else {
        git -C $repo.FullName remote add origin $remoteUrl | Out-Null
    }

    Write-Host "Pushing $localName ($branch) -> $remoteUrl ..."
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    if ($HostProvider -eq "github" -and $ghToken) {
        $rawAuth = [System.Text.Encoding]::UTF8.GetBytes("x-access-token:$ghToken")
        $b64Auth = [Convert]::ToBase64String($rawAuth)
        git -C $repo.FullName -c "http.https://github.com/.extraheader=AUTHORIZATION: basic $b64Auth" push -u origin $branch
    } else {
        git -C $repo.FullName push -u origin $branch
    }
    $pushExit = $LASTEXITCODE
    $ErrorActionPreference = $prevPref
    if ($pushExit -ne 0) {
        throw "Failed to push $localName ($branch) to $remoteUrl"
    }
    $pushed++
}

Write-Host ""
Write-Host "Completed remote sync for $pushed / $($repos.Count) repositories under https://$hostDomain/$Org"
