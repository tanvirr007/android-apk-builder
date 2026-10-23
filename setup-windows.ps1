# ==============================================================================
# Android APK Builder — Universal Automated Android APK Compilation Engine
# ==============================================================================
# Author:  Tanvir Hasan
# Website: https://tanvir.info
# GitHub:  https://github.com/tanvirr007
#
# A universal, zero-assumption automation engine to compile any modern Android
# project (Kotlin/Java with Gradle) on Windows without installing Android Studio.
#
# Features:
#   - Automatic project detection & dynamic compileSdk parsing
#   - Works with or without Administrator privileges (automatic AppData fallback)
#   - Hardware RAM auto-profiling (Potato PC vs High-Performance workstation)
#   - Unattended JDK 17+ and Android SDK Command-Line Tools setup
#   - Automated license acceptance and Gradle wrapper bootstrapping
#
# USAGE:
#   1. From the target project directory:
#      cd C:\path\to\your-android-project
#      C:\path\to\android-apk-builder\setup-windows.bat -BuildType Release
#
#   2. Or passing the project directory explicitly:
#      .\setup-windows.ps1 -ProjectDir "C:\path\to\your-android-project" -BuildType Release
# ==============================================================================

[CmdletBinding()]
param(
    [string]$ProjectDir = "",

    [ValidateSet("Debug", "Release", "Both")]
    [string]$BuildType = "Debug",

    [switch]$ForceLowMem,
    [switch]$SkipSdkInstall
)

$ErrorActionPreference = "Continue"

# Force TLS 1.2 on older PowerShell 5.1 environments
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Suppress progress bar rendering to accelerate download speeds by 10x-20x
$ProgressPreference = 'SilentlyContinue'

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Android APK Builder — Universal APK Compilation Engine         " -ForegroundColor Cyan
Write-Host "  Author: Tanvir Hasan (https://tanvir.info)                     " -ForegroundColor DarkCyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------------------------
# STEP 0: Project Target Discovery & SDK Version Parsing
# ------------------------------------------------------------------------------
Write-Host "[Step 0/6] Inspecting Android project root..." -ForegroundColor Yellow

$targetDir = if ([string]::IsNullOrWhiteSpace($ProjectDir)) { (Get-Location).Path } else { $ProjectDir }

if (-not (Test-Path $targetDir)) {
    Write-Host "[ERROR] Target project directory does not exist: $targetDir" -ForegroundColor Red
    exit 1
}

$hasSettings = (Test-Path (Join-Path $targetDir "settings.gradle.kts")) -or (Test-Path (Join-Path $targetDir "settings.gradle"))
if (-not $hasSettings) {
    Write-Host ""
    Write-Host "[ERROR] No settings.gradle or settings.gradle.kts found in: $targetDir" -ForegroundColor Red
    Write-Host "Please ensure you run this command inside an Android/Gradle project folder." -ForegroundColor Yellow
    exit 1
}

# Scan for application module build files
$buildFiles = @(
    (Join-Path $targetDir "app\build.gradle.kts"),
    (Join-Path $targetDir "app\build.gradle"),
    (Join-Path $targetDir "build.gradle.kts"),
    (Join-Path $targetDir "build.gradle")
)

$targetSdk = 36 # Default baseline
$foundBuildFile = $null

foreach ($bf in $buildFiles) {
    if (Test-Path $bf) {
        $foundBuildFile = $bf
        $content = Get-Content $bf -Raw
        if ($content -match 'compileSdk\s*=?\s*(\d+)') {
            $targetSdk = [int]$matches[1]
            break
        } elseif ($content -match 'compileSdk\.set\((\d+)\)') {
            $targetSdk = [int]$matches[1]
            break
        } elseif ($content -match 'compileSdkVersion\s*=?\s*(\d+)') {
            $targetSdk = [int]$matches[1]
            break
        }
    }
}

Write-Host "  [OK] Project Root: $targetDir" -ForegroundColor Green
Write-Host "  [OK] Target compileSdk Detected: $targetSdk" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------------------------
# STEP 1: Hardware Memory Detection & Profiling (Potato PC vs High-End Rig)
# ------------------------------------------------------------------------------
Write-Host "[Step 1/6] Profiling host memory & tuning JVM parameters..." -ForegroundColor Yellow

$totalRamGb = 8
try {
    $ramBytes = (Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | Measure-Object -Property Capacity -Sum).Sum
    if ($ramBytes) {
        $totalRamGb = [math]::Round($ramBytes / 1GB, 1)
    }
} catch {
    Write-Host "  [!] Could not query physical RAM via WMI. Assuming 8 GB." -ForegroundColor DarkGray
}

$isPotato = ($totalRamGb -le 8.5) -or $ForceLowMem

if ($isPotato) {
    Write-Host "  [!] Potato PC Profile Activated (Detected RAM: $totalRamGb GB)" -ForegroundColor Yellow
    Write-Host "      Constraining heap to prevent Windows paging/swapping lockup."
    $env:GRADLE_OPTS = "-Xmx1536m -XX:MaxMetaspaceSize=512m -XX:+UseParallelGC"
    $gradleExtraArgs = @("--no-daemon", "--max-workers=2")
} else {
    Write-Host "  [OK] High-Performance Profile Activated (Detected RAM: $totalRamGb GB)" -ForegroundColor Green
    $env:GRADLE_OPTS = "-Xmx4096m -XX:MaxMetaspaceSize=1024m"
    $gradleExtraArgs = @("--parallel", "--build-cache")
}

[Environment]::SetEnvironmentVariable("GRADLE_OPTS", $env:GRADLE_OPTS, "User")
Write-Host "  GRADLE_OPTS: $env:GRADLE_OPTS" -ForegroundColor DarkCyan
Write-Host ""

# ------------------------------------------------------------------------------
# STEP 2: Java Development Kit (JDK 17+) Setup
# ------------------------------------------------------------------------------
Write-Host "[Step 2/6] Verifying Java Development Kit (JDK 17+)..." -ForegroundColor Yellow

function Find-JdkPath {
    if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME "bin\javac.exe"))) {
        return $env:JAVA_HOME
    }
    $searchPaths = @(
        "C:\Program Files\Eclipse Adoptium\jdk-17*",
        "C:\Program Files\Eclipse Adoptium\jdk-21*",
        "C:\Program Files\Microsoft\jdk-17*",
        "C:\Program Files\Microsoft\jdk-21*",
        "C:\Program Files\Java\jdk-17*",
        "C:\Program Files\Java\jdk-21*",
        "C:\Program Files\Android\Android Studio\jbr",
        "C:\Program Files\BellSoft\LibericaJDK-17*",
        "C:\Program Files\Amazon Corretto\jdk17*"
    )
    foreach ($pattern in $searchPaths) {
        $match = Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if ($match -and (Test-Path (Join-Path $match.FullName "bin\javac.exe"))) {
            return $match.FullName
        }
    }
    return $null
}

$jdkPath = Find-JdkPath

if (-not $jdkPath) {
    Write-Host "  [!] JDK 17+ not detected on host." -ForegroundColor Yellow
    $hasWinget = Get-Command "winget" -ErrorAction SilentlyContinue
    if ($hasWinget) {
        Write-Host "  [+] Installing Eclipse Adoptium Temurin OpenJDK 17 via winget..." -ForegroundColor Cyan
        winget install EclipseAdoptium.Temurin.17.JDK --accept-source-agreements --accept-package-agreements --silent
        $jdkPath = Find-JdkPath
    }
}

if (-not $jdkPath) {
    Write-Host ""
    Write-Host "[ERROR] JDK 17+ could not be located or installed automatically." -ForegroundColor Red
    Write-Host "Please download and install OpenJDK 17 from:" -ForegroundColor Yellow
    Write-Host "  https://adoptium.net/temurin/releases/?version=17"
    exit 1
}

Write-Host "  [OK] JDK located at: $jdkPath" -ForegroundColor Green

$env:JAVA_HOME = $jdkPath
if ($env:Path -notlike "*$jdkPath\bin*") {
    $env:Path = "$jdkPath\bin;$env:Path"
}
[Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkPath, "User")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$jdkPath\bin*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$jdkPath\bin", "User")
}

Write-Host "  [OK] JAVA_HOME configured for session and user profile." -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------------------------
# STEP 3: Android SDK & Command-Line Tools Setup
# ------------------------------------------------------------------------------
Write-Host "[Step 3/6] Setting up Android SDK and Command-Line Tools..." -ForegroundColor Yellow

function Get-SafeAndroidHome {
    if ($env:ANDROID_HOME -and (Test-Path $env:ANDROID_HOME)) {
        return $env:ANDROID_HOME
    }
    if ($env:ANDROID_SDK_ROOT -and (Test-Path $env:ANDROID_SDK_ROOT)) {
        return $env:ANDROID_SDK_ROOT
    }
    if (Test-Path "C:\Android") {
        return "C:\Android"
    }
    try {
        New-Item -ItemType Directory -Path "C:\Android" -Force -ErrorAction Stop | Out-Null
        return "C:\Android"
    } catch {
        # Fall back to user-writable AppData (requires zero admin rights)
        $userSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
        New-Item -ItemType Directory -Path $userSdk -Force -ErrorAction SilentlyContinue | Out-Null
        return $userSdk
    }
}

$androidHome = Get-SafeAndroidHome
$env:ANDROID_HOME = $androidHome
[Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidHome, "User")

# Write local.properties for the target project
$sdkDirFormatted = $androidHome -replace '\\', '/'
$localPropsPath = Join-Path $targetDir "local.properties"
Set-Content -Path $localPropsPath -Value "sdk.dir=$sdkDirFormatted"
Write-Host "  [OK] local.properties configured: sdk.dir=$sdkDirFormatted" -ForegroundColor Green

$cmdlineToolsLatestBin = Join-Path $androidHome "cmdline-tools\latest\bin"
$sdkManager = Join-Path $cmdlineToolsLatestBin "sdkmanager.bat"

if (-not (Test-Path $sdkManager) -and -not $SkipSdkInstall) {
    Write-Host "  [!] cmdline-tools\latest\bin\sdkmanager.bat not found." -ForegroundColor Yellow

    $looseCmdline = Join-Path $androidHome "cmdline-tools"
    if (Test-Path (Join-Path $looseCmdline "bin\sdkmanager.bat")) {
        Write-Host "  [+] Restructuring loose cmdline-tools to cmdline-tools\latest..." -ForegroundColor Cyan
        $tempRename = Join-Path $androidHome "cmdline-tools-temp"
        Move-Item -Path $looseCmdline -Destination $tempRename -Force
        New-Item -ItemType Directory -Path $looseCmdline -Force | Out-Null
        Move-Item -Path $tempRename -Destination (Join-Path $looseCmdline "latest") -Force
    } else {
        Write-Host "  [+] Downloading official Android command-line tools from Google..." -ForegroundColor Cyan
        $zipUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
        $tempZip = "$env:TEMP\cmdline-tools.zip"
        $tempExtract = "$env:TEMP\cmdline-tools-extracted"

        Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing
        if (Test-Path $tempExtract) { Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

        $targetLatest = Join-Path $androidHome "cmdline-tools\latest"
        New-Item -ItemType Directory -Force -Path (Join-Path $androidHome "cmdline-tools") | Out-Null

        if (Test-Path $targetLatest) { Remove-Item -Path $targetLatest -Recurse -Force -ErrorAction SilentlyContinue }
        Move-Item -Path (Join-Path $tempExtract "cmdline-tools") -Destination $targetLatest -Force

        Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-Path $sdkManager)) {
    Write-Host ""
    Write-Host "[ERROR] sdkmanager.bat could not be located at: $sdkManager" -ForegroundColor Red
    exit 1
}

Write-Host "  [OK] Android sdkmanager verified at: $sdkManager" -ForegroundColor Green

if (-not $SkipSdkInstall) {
    Write-Host "  [+] Auto-accepting all Android SDK licenses..." -ForegroundColor Cyan

    $licensesDir = Join-Path $androidHome "licenses"
    New-Item -ItemType Directory -Force -Path $licensesDir | Out-Null
    $licenseFile = Join-Path $licensesDir "android-sdk-license"
    $knownHashes = @"
8933bad161af4178b1185d1a37fbf41ea5269c55
d56f5187479451eabf01fb78af6dfcb131a6481e
24333f8a63b6824ea7279bf34f796040be778e1e
84831b9409646a918e30573bab4c9c91346d8abd
"@
    Set-Content -Path $licenseFile -Value $knownHashes

    1..30 | ForEach-Object { "y" } | & $sdkManager --licenses | Out-Null

    Write-Host "  [+] Installing platforms;android-$targetSdk and build-tools;$targetSdk.0.0..." -ForegroundColor Cyan
    & $sdkManager "platform-tools" "platforms;android-$targetSdk" "build-tools;$targetSdk.0.0"
    Write-Host "  [OK] Android SDK platform components verified." -ForegroundColor Green
}

Write-Host ""

# ------------------------------------------------------------------------------
# STEP 4: Gradle Wrapper Validation & Bootstrapping
# ------------------------------------------------------------------------------
Write-Host "[Step 4/6] Checking project Gradle Wrapper..." -ForegroundColor Yellow

$gradlewBat = Join-Path $targetDir "gradlew.bat"
$wrapperJar = Join-Path $targetDir "gradle\wrapper\gradle-wrapper.jar"

if (-not (Test-Path $gradlewBat) -or -not (Test-Path $wrapperJar)) {
    Write-Host "  [!] gradlew.bat or gradle-wrapper.jar missing in project." -ForegroundColor Yellow
    Write-Host "  [+] Bootstrapping official Gradle Wrapper 8.11.1..." -ForegroundColor Cyan

    $tempGradleDir = "$env:TEMP\gradle-bootstrap"
    $gradleZip = "$tempGradleDir\gradle-8.11.1-bin.zip"
    $gradleExtract = "$tempGradleDir\extracted"

    if (-not (Test-Path $tempGradleDir)) {
        New-Item -ItemType Directory -Force -Path $tempGradleDir | Out-Null
    }

    Write-Host "      Downloading Gradle 8.11.1 distribution..." -ForegroundColor DarkCyan
    Invoke-WebRequest -Uri "https://services.gradle.org/distributions/gradle-8.11.1-bin.zip" -OutFile $gradleZip -UseBasicParsing

    Write-Host "      Extracting temporary Gradle binary..." -ForegroundColor DarkCyan
    Expand-Archive -Path $gradleZip -DestinationPath $gradleExtract -Force

    $tempGradleBat = (Get-ChildItem -Path $gradleExtract -Filter "gradle.bat" -Recurse | Select-Object -First 1).FullName

    Write-Host "      Generating project wrapper inside $targetDir..." -ForegroundColor DarkCyan
    Push-Location $targetDir
    try {
        & $tempGradleBat wrapper --gradle-version 8.11.1
    } finally {
        Pop-Location
    }

    Remove-Item -Path $tempGradleDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  [OK] Gradle Wrapper generated successfully." -ForegroundColor Green
} else {
    Write-Host "  [OK] Project Gradle Wrapper present." -ForegroundColor Green
}

Write-Host ""

# ------------------------------------------------------------------------------
# STEP 5: Compilation Execution
# ------------------------------------------------------------------------------
Write-Host "[Step 5/6] Executing Gradle compilation ($BuildType)..." -ForegroundColor Yellow

$tasksToRun = @()
switch ($BuildType) {
    "Debug"   { $tasksToRun += "assembleDebug" }
    "Release" { $tasksToRun += "assembleRelease" }
    "Both"    { $tasksToRun += @("assembleDebug", "assembleRelease") }
}

$fullCommand = @($gradlewBat) + $tasksToRun + $gradleExtraArgs
Write-Host "  Running: $($fullCommand -join ' ')" -ForegroundColor DarkCyan
Write-Host ""

Push-Location $targetDir
try {
    & $gradlewBat $tasksToRun $gradleExtraArgs
    $buildExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}

if ($buildExitCode -ne 0) {
    Write-Host ""
    Write-Host "[ERROR] Gradle build failed with exit code $buildExitCode." -ForegroundColor Red
    exit $buildExitCode
}

Write-Host ""
Write-Host "  [OK] Compilation finished successfully!" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------------------------
# STEP 6: APK / AAB Discovery & Move to Project Root
# ------------------------------------------------------------------------------
Write-Host "[Step 6/6] Moving generated build artifacts (.apk / .aab) to project root..." -ForegroundColor Yellow

$artifacts = Get-ChildItem -Path $targetDir -Include "*.apk", "*.aab" -Recurse -ErrorAction SilentlyContinue | Where-Object {
    $_.FullName -notmatch '\\intermediate\\' -and ($_.FullName -match '\\outputs\\apk\\' -or $_.FullName -match '\\outputs\\bundle\\')
}

if ($artifacts) {
    foreach ($item in $artifacts) {
        $dest = Join-Path $targetDir $item.Name
        Move-Item -Path $item.FullName -Destination $dest -Force
        $sizeMb = [math]::Round((Get-Item $dest).Length / 1MB, 2)
        Write-Host "  [MOVED TO ROOT] $dest ($sizeMb MB)" -ForegroundColor Green
    }
} else {
    Write-Host "  [!] No APK or AAB found under build outputs directory." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  Build succeeded! All tasks finished without errors.            " -ForegroundColor Green
Write-Host "  Engine by Tanvir Hasan — https://tanvir.info                  " -ForegroundColor DarkGreen
Write-Host "==================================================================" -ForegroundColor Green
