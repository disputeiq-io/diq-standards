<#
.SYNOPSIS
    Ensures Eclipse Temurin JDK 21 LTS and Gradle 8.10.2 are available for DisputeIQ builds.
#>
$ErrorActionPreference = "Stop"

$JdkBaseDir = "C:\Users\Lenovo\.jdks"
$JdkTargetDir = Join-Path $JdkBaseDir "temurin-21"
$JavaExe = Join-Path $JdkTargetDir "bin\java.exe"

$GradleUserHome = "C:\Users\Lenovo\.gradle"
$GradleTargetDir = Join-Path $GradleUserHome "gradle-8.10.2"
$GradleBat = Join-Path $GradleTargetDir "bin\gradle.bat"
$SeedGradleDir = "D:\Projects\diple-engine\backend\tools\gradle-8.10.2"

if (-not (Test-Path $JavaExe)) {
    Write-Host "Eclipse Temurin JDK 21 not found at $JdkTargetDir. Downloading from Adoptium API..."
    New-Item -ItemType Directory -Force -Path $JdkBaseDir | Out-Null

    $zipPath = Join-Path $env:TEMP "temurin21-win-x64.zip"
    $extractDir = Join-Path $env:TEMP "temurin21-extract"

    if (Test-Path $extractDir) { Remove-Item -Recurse -Force $extractDir }
    if (Test-Path $zipPath) { Remove-Item -Force $zipPath }

    $ProgressPreference = 'SilentlyContinue'
    $downloadUrl = "https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jdk/hotspot/normal/eclipse"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing

    Write-Host "Extracting Temurin JDK 21..."
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
    $innerDir = Get-ChildItem -Path $extractDir -Directory | Select-Object -First 1
    if (-not $innerDir) { throw "Failed to locate extracted JDK directory inside $extractDir" }

    if (Test-Path $JdkTargetDir) { Remove-Item -Recurse -Force $JdkTargetDir }
    Move-Item -Path $innerDir.FullName -Destination $JdkTargetDir
    Remove-Item -Force $zipPath -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $extractDir -ErrorAction SilentlyContinue
} else {
    Write-Host "Eclipse Temurin JDK 21 already installed at $JdkTargetDir"
}

if (-not (Test-Path $GradleBat)) {
    if (Test-Path $SeedGradleDir) {
        Write-Host "Installing Gradle 8.10.2 into $GradleTargetDir..."
        New-Item -ItemType Directory -Force -Path $GradleUserHome | Out-Null
        Copy-Item -Path $SeedGradleDir -Destination $GradleTargetDir -Recurse -Force
    } else {
        throw "Gradle 8.10.2 not found at $GradleBat or $SeedGradleDir"
    }
} else {
    Write-Host "Gradle 8.10.2 already installed at $GradleTargetDir"
}

Write-Host "Verifying JDK 21:"
& $JavaExe -version

Write-Host "Verifying Gradle 8.10.2 with JAVA_HOME=$JdkTargetDir :"
$env:JAVA_HOME = $JdkTargetDir
& $GradleBat -version
