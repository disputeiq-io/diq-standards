<#
.SYNOPSIS
    Ensures Eclipse Temurin JDK 21 LTS and Apache Maven 3.9.5 are available for DisputeIQ builds.
#>
$ErrorActionPreference = "Stop"

$JdkBaseDir = "C:\Users\Lenovo\.jdks"
$JdkTargetDir = Join-Path $JdkBaseDir "temurin-21"
$JavaExe = Join-Path $JdkTargetDir "bin\java.exe"
$CachedMavenCmd = "C:\Users\Lenovo\.m2\wrapper\dists\apache-maven-3.9.5-bin\2adeog8mj13csp1uusqnc1f2mo\apache-maven-3.9.5\bin\mvn.cmd"

if (-not (Test-Path $JavaExe)) {
    Write-Host "Eclipse Temurin JDK 21 not found at $JdkTargetDir. Downloading from Adoptium API..."
    New-Item -ItemType Directory -Force -Path $JdkBaseDir | Out-Null

    $zipPath = Join-Path $env:TEMP "temurin21-win-x64.zip"
    $extractDir = Join-Path $env:TEMP "temurin21-extract"

    if (Test-Path $extractDir) {
        Remove-Item -Recurse -Force $extractDir
    }
    if (Test-Path $zipPath) {
        Remove-Item -Force $zipPath
    }

    $downloadUrl = "https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jdk/hotspot/normal/eclipse"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing

    Write-Host "Extracting Temurin JDK 21..."
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    $innerDir = Get-ChildItem -Path $extractDir -Directory | Select-Object -First 1
    if (-not $innerDir) {
        throw "Failed to locate extracted JDK directory inside $extractDir"
    }

    if (Test-Path $JdkTargetDir) {
        Remove-Item -Recurse -Force $JdkTargetDir
    }
    Move-Item -Path $innerDir.FullName -Destination $JdkTargetDir

    Remove-Item -Force $zipPath -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $extractDir -ErrorAction SilentlyContinue
} else {
    Write-Host "Eclipse Temurin JDK 21 already installed at $JdkTargetDir"
}

Write-Host "Verifying JDK 21:"
& $JavaExe -version

if (-not (Test-Path $CachedMavenCmd)) {
    throw "Cached Maven 3.9.5 not found at $CachedMavenCmd. Please install Maven or update mvnw.cmd."
}

Write-Host "Verifying Maven 3.9.5 with JAVA_HOME=$JdkTargetDir :"
$env:JAVA_HOME = $JdkTargetDir
& $CachedMavenCmd -version
