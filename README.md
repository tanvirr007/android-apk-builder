# Android APK Builder

### Universal Headless Android APK and AAB Compilation Engine for Windows

[![Platform: Windows](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6?style=flat-square&logo=windows&logoColor=white)](https://microsoft.com/windows)
![Visitors](https://visitor-badge.laobi.icu/badge?page_id=tanvirr007.android-apk-builder)

---

## Overview

Android APK Builder is a standalone, universal build automation engine and comprehensive technical guide designed to compile any modern Android application (Kotlin, Java, Jetpack Compose) directly on Microsoft Windows from the command line without requiring Android Studio.

Android Studio typically consumes between 4 GB and 8 GB of RAM merely sitting idle in the background. Android APK Builder bypasses the IDE entirely, providing an autonomous, self-adapting compilation pipeline that operates natively inside PowerShell and Command Prompt.

### The Self-Adapting Architecture

The engine automatically analyzes the host machine and the target project before executing any build tasks:

- Dynamic Project Inspection: Recursively parses Groovy (`build.gradle`), Kotlin DSL (`build.gradle.kts`), and modern Gradle Version Catalogs (`gradle/libs.versions.toml`) to extract target SDKs, build-tools, Android Gradle Plugin (AGP) versions, and module topologies.
- Compatibility Resolution: Evaluates project components against an integrated AGP, Gradle, and JDK compatibility matrix to guarantee that compiler versions and runtime environments align before building.
- Hardware-Aware Memory Tuning: Analyzes physical RAM and applies tailored Java Virtual Machine (JVM) heap ceilings, garbage collection algorithms, and worker concurrency limits. It keeps budget hardware (such as 4 GB RAM systems) responsive while unlocking parallel caching on high-spec workstations.
- Isolated Session Scoping: Configures all environment variables strictly within the lifetime of the running script session, leaving the Windows User Registry clean and free from permanent global overrides.
- Non-Destructive Operations: Safely updates project configuration files (such as `local.properties`) without stripping user comments or custom paths, and harvests artifacts by copying rather than moving them, protecting Gradle build caches.
- Multi-Tier Artifact Verification: Generates cryptographic SHA-256 hashes for all outputs and executes deep signature inspection across APK Signature Schemes v1, v2, v3, and v4 via the official `apksigner` tool.

---

## 1. Quick Start

Android APK Builder provides three primary interfaces:
1. `build.bat`: The primary 1-click interactive batch launcher. Double-click or run from terminal to launch the interactive build wizard, or drag-and-drop an Android project folder directly onto it.
2. `setup-windows.bat`: A Windows batch launcher that automatically handles execution policies and forwards arguments to PowerShell (or launches interactive mode when run without arguments).
3. `setup-windows.ps1`: The native PowerShell automation engine providing full control over all build parameters.

### 1-Click Interactive Build Wizard (`build.bat`)

For the fastest and simplest experience on Windows:
1. Double-click `build.bat` or run it from Command Prompt:
   ```cmd
   build.bat
   ```
2. If executed outside an Android project folder (such as directly inside this builder directory), the wizard prompts you to enter or drag-and-drop the target project directory.
3. Choose your build mode:
   - Press **Enter** to immediately build with recommended defaults (`Release` APK).
   - Type **C** and press **Enter** to customize build parameters (Debug/Release, APK/AAB, clean build, and low-memory mode).
4. The terminal window pauses upon completion (`Press Enter to exit...`) so you can review harvested artifact paths and signature verification without the window closing automatically.

You can also drag and drop your Android project folder directly onto `build.bat` in Windows Explorer to build it immediately.

### Basic Invocations

#### Run Inside Your Android Project Directory
Open Command Prompt or PowerShell, navigate to the target Android project root, and run:

```cmd
cd C:\path\to\your-android-project
C:\path\to\android-apk-builder\setup-windows.bat -BuildType Release
```

#### Specify the Project Directory Explicitly
You can invoke the builder from anywhere by passing `-ProjectDir`:

```cmd
C:\path\to\android-apk-builder\setup-windows.bat -ProjectDir "C:\path\to\your-android-project" -BuildType Release
```

#### Build Debug, Release, or Both
Select the exact variant to assemble:

```cmd
rem Build debug APK
setup-windows.bat -ProjectDir "C:\path\to\project" -BuildType Debug

rem Build release APK
setup-windows.bat -ProjectDir "C:\path\to\project" -BuildType Release

rem Build both debug and release variants in a single run
setup-windows.bat -ProjectDir "C:\path\to\project" -BuildType Both
```

#### Select Artifact Type (APK, AAB, or Both)
Choose whether to produce installable APK packages, Google Play App Bundles (AAB), or both:

```cmd
rem Build Google Play App Bundle (.aab)
setup-windows.bat -ProjectDir "C:\path\to\project" -ArtifactType AAB

rem Build both APK and AAB packages
setup-windows.bat -ProjectDir "C:\path\to\project" -ArtifactType Both
```

#### Target Specific Multi-Module Projects
If the repository contains multiple application modules or features, target the desired module:

```cmd
setup-windows.bat -ProjectDir "C:\path\to\project" -Module ":app" -BuildType Release
```

#### Memory Tuning Controls
Force specific hardware execution profiles:

```cmd
rem Force low-memory profile for budget systems (<= 4 GB / 8 GB RAM)
setup-windows.bat -ProjectDir "C:\path\to\project" -ForceLowMem

rem Force high-performance profile for powerful multi-core workstations
setup-windows.bat -ProjectDir "C:\path\to\project" -HighMem
```

#### Headless Automation and CI/CD Switches
Automate licensing, pre-clean workspaces, or run offline:

```cmd
setup-windows.bat -ProjectDir "C:\path\to\project" -AcceptLicenses -CleanFirst -OutputDir "C:\builds"
```

### Complete Parameter Reference

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `-ProjectDir` | String | Current Directory | Path to the target Android project root. |
| `-BuildType` | String | `Release` | Build variant to assemble: `Release`, `Debug`, or `Both`. |
| `-ArtifactType` | String | `APK` | Output package format: `APK`, `AAB`, or `Both`. |
| `-Module` | String | Auto-detected | Specific application module name (e.g., `:app` or `app`). |
| `-Variant` | String | Auto-detected | Specific build variant name (e.g., `release`, `freeRelease`). |
| `-OutputDir` | String | `dist` | Destination folder relative to the project root for harvested artifacts. |
| `-ForceLowMem` | Switch | Off | Forces the low-memory profile (<= 1.5 GB JVM heap, single worker, no-daemon). |
| `-HighMem` | Switch | Off | Forces high-performance profile (4 GB heap, parallel workers, build cache). |
| `-AcceptLicenses` | Switch | Off | Automatically accepts official Android SDK licenses non-interactively. |
| `-CleanFirst` | Switch | Off | Executes the Gradle `clean` task prior to assembling artifacts. |
| `-Offline` | Switch | Off | Runs Gradle compilation in offline mode (`--offline`). |
| `-DryRun` | Switch | Off | Inspects project, resolves dependencies, and plans build without compiling. |
| `-SkipSdkInstall` | Switch | Off | Skips downloading or updating missing Android SDK platforms and build-tools. |
| `-SkipJdkInstall` | Switch | Off | Skips automated winget installation of OpenJDK if host lacks compatible JDK. |
| `-SdkPath` | String | Auto-detected | Explicit custom file system path to the Android SDK. |
| `-JdkPath` | String | Auto-detected | Explicit custom file system path to the Java Development Kit. |
| `-CompileSdkOverride`| Integer | Auto-detected | Overrides detected `compileSdk` version (e.g., `35`). |
| `-BuildToolsOverride`| String | Auto-detected | Overrides detected `build-tools` version string (e.g., `35.0.0`). |
| `-VerboseLog` | Switch | Off | Enables verbose diagnostic output during execution. |
| `-Interactive` | Switch | Off | Launches the interactive step-by-step build wizard. |

---

## 2. Conceptual Foundation: How Code Becomes an APK

When building an Android application from the terminal, the build process transforms human-readable source code into a signed, aligned, and optimized binary package:

```
+--------------------------------------------------------------------------+
| 1. Source Code Files (.kt, .java, .xml)                                  |
|    Human-readable instructions defining your UI, data, and logic.        |
+--------------------------------------------------------------------------+
                                     |
                                     v
+--------------------------------------------------------------------------+
| 2. Kotlin & Java Compilers (kotlinc, javac via JDK 17+)                  |
|    Translates source code into standard Java Virtual Machine bytecode    |
|    (.class files).                                                       |
+--------------------------------------------------------------------------+
                                     |
                                     v
+--------------------------------------------------------------------------+
| 3. Android Dexer & Code Optimizer (D8 / R8)                              |
|    Converts JVM bytecode into Dalvik Executable (.dex) bytecode          |
|    optimized for Android ART (Android Runtime). In Release builds, R8    |
|    removes unused methods and shrinks classes (tree-shaking).            |
+--------------------------------------------------------------------------+
                                     |
                                     v
+--------------------------------------------------------------------------+
| 4. Android Asset Packaging Tool (AAPT2)                                  |
|    Compiles XML layouts, drawables, and strings into compact binary XML  |
|    and builds the compiled resources table (resources.arsc).             |
+--------------------------------------------------------------------------+
                                     |
                                     v
+--------------------------------------------------------------------------+
| 5. Package Assembly & Alignment (zipalign & apksigner)                   |
|    Packages all .dex files, assets, and metadata into a compressed .apk, |
|    aligns data boundaries to 4-byte offsets, and signs the archive.      |
+--------------------------------------------------------------------------+
```

To run this entire pipeline, you do not need the full Android Studio desktop application. You only need:
1. Java Development Kit (JDK 17 or 21): Runs the build system and compilers.
2. Gradle: The orchestration engine coordinating dependencies, tasks, and plugins.
3. Android SDK Command-Line Tools: Provides core toolchain binaries (`sdkmanager`, `aapt2`, `d8`, and `apksigner`).

---

## 3. The 6-Stage Compilation Pipeline

The automation engine executes a structured, six-stage pipeline to guarantee reliable compilation across different project configurations:

```
[Stage 1: Project Inspection]  -> Parses build files, catalogs, and module trees.
             |
[Stage 2: Memory Profiling]    -> Benchmarks system RAM and selects JVM profiles.
             |
[Stage 3: JDK Resolution]      -> Verifies host JDKs, matches matrix, or installs via winget.
             |
[Stage 4: SDK & Tools Setup]   -> Sets up SDK paths, nested tools, and licenses.
             |
[Stage 5: Gradle Bootstrapping]-> Validates wrapper or downloads official distribution.
             |
[Stage 6: Build & Harvesting]  -> Compiles, copies to output, calculates hashes, and verifies signatures.
```

### Stage 1: Project Inspection and Compatibility Discovery
- Scans `settings.gradle` and `settings.gradle.kts` to identify all project modules.
- Parses module build files and Gradle Version Catalogs (`gradle/libs.versions.toml`).
- Extracts key properties: `compileSdk`, `targetSdk`, `minSdk`, `buildToolsVersion`, AGP version, Kotlin version, Java toolchain targets, signing configurations, and namespaces.
- Evaluates the Android Gradle Plugin version against the built-in compatibility matrix to determine minimum and maximum supported JDK versions and target Gradle distributions.

### Stage 2: Hardware Profiling and Constrained-Memory Tuning
- Queries host memory capacity via Windows WMI (`Win32_OperatingSystem` and `Win32_PhysicalMemory`).
- Automatically categorizes the host machine into appropriate performance tiers:
  - Constrained Systems (<= 8.5 GB RAM): Applies conservative heap ceilings, lightweight garbage collection (`-XX:+UseParallelGC`), single or dual worker threads, and disables persistent background daemons (`--no-daemon`).
  - High-Spec Workstations (> 8.5 GB RAM): Allocates larger heaps (4 GB+), activates Gradle daemon caching, enables task parallelization, and activates `--build-cache`.
- Configures environment variables strictly for the active process session, avoiding persistent Windows User Registry modification.

### Stage 3: Java Development Kit (JDK) Resolution and Validation
- Searches for verified 64-bit JDK installations across standard system paths: Eclipse Adoptium, Microsoft OpenJDK, Oracle Java, BellSoft Liberica, Amazon Corretto, Azul Zulu, Android Studio embedded runtimes (JBR/JRE), and the user `.jdks` directory.
- Queries `java.exe -version` to verify exact major version numbers and 64-bit architecture support.
- Matches available runtimes against project compatibility requirements, prioritizing LTS releases (Java 17 and Java 21).
- If no compatible JDK is detected, it automatically attempts unattended installation of Eclipse Adoptium Temurin OpenJDK via Windows Package Manager (`winget`).

### Stage 4: Android SDK, Platform Tools, and Licenses Setup
- Discovers existing Android SDK roots from custom parameters, project `local.properties`, environment variables (`ANDROID_HOME`, `ANDROID_SDK_ROOT`), user AppData paths (`%LOCALAPPDATA%\Android\Sdk`), or standard installation directories.
- Non-destructively generates or updates `local.properties` with forward-slash formatted paths (`sdk.dir=C:/...`), preserving all other custom properties and generating a backup (`local.properties.bak`).
- Validates the `cmdline-tools` directory hierarchy. If tools are extracted loosely without the required `latest` directory, the engine restructures them automatically. If missing, it downloads and installs the official Google command-line tools package.
- Manages SDK license agreements by automatically feeding confirmations non-interactively when `-AcceptLicenses` is specified.
- Verifies and downloads required SDK platform packages (`platforms;android-<compileSdk>`) and build tools (`build-tools;<version>`).

### Stage 5: Gradle Wrapper Verification and Recovery
- Verifies the integrity of `gradlew.bat`, `gradle/wrapper/gradle-wrapper.jar`, and `gradle/wrapper/gradle-wrapper.properties`.
- Checks that `gradle-wrapper.jar` is valid and non-empty (protecting against incomplete Git checkouts).
- If the wrapper is missing or corrupted, the engine downloads the official Gradle binary distribution matched to the project's AGP requirements, runs `gradle wrapper`, and generates a clean wrapper environment.

### Stage 6: Compilation, Artifact Harvesting, and Signature Verification
- Constructs the target Gradle task list based on the requested `-BuildType` (`assembleDebug`, `assembleRelease`, or both) and `-ArtifactType` (APK, AAB, or both).
- Scopes tasks to the identified application module (for example, `:app:assembleRelease`).
- Invokes the Gradle wrapper using the calculated memory and worker flags.
- If an assembleRelease build fails, it inspects project signing configurations and provides targeted diagnostics if missing signing keys caused the failure.
- Harvests generated artifacts into the specified output directory (`dist/` by default). Outputs are safely copied rather than moved, keeping Gradle build outputs valid for subsequent incremental builds.
- Calculates SHA-256 cryptographic hashes for every harvested artifact.
- Invokes `apksigner` to verify APK signatures, identifying active signature schemes (v1, v2, v3, v4) and certificate details.

---

## 4. Key Architectural Improvements

Android APK Builder includes substantial architectural improvements over conventional terminal scripts:

### 1. Non-Destructive local.properties Management
- Previous Approach: Standard scripts overwrite `local.properties` completely with `Set-Content`, erasing developer-defined properties such as `ndk.dir`, `cmake.dir`, and custom build flags.
- Self-Adapting Engine: Reads the file line by line, updates or inserts only the `sdk.dir` key using normalized forward slashes, preserves all comments and unrelated properties, and writes a safety backup to `local.properties.bak`.

### 2. Session-Scoped Environment Variables
- Previous Approach: Global calls to `[Environment]::SetEnvironmentVariable(..., "User")` wrote values permanently to `HKEY_CURRENT_USER\Environment`. This altered system-wide behavior for all future terminals, other development tools, and user accounts.
- Self-Adapting Engine: Scopes `$env:JAVA_HOME`, `$env:ANDROID_HOME`, and `$env:GRADLE_OPTS` strictly to the executing PowerShell process. Once the script finishes, the host system environment remains entirely unmodified.

### 3. Comprehensive AGP, Gradle, and JDK Compatibility Matrix
- Previous Approach: Hardcoded JDK 17 and a single fixed Gradle version, causing build failures when processing legacy projects or modern AGP 8.8+ releases.
- Self-Adapting Engine: Evaluates the project AGP version and wrapper settings dynamically to enforce correct compatibility:

| AGP Version | Compatible Gradle Version | Supported JDK Range | Default Target Gradle |
| :--- | :--- | :--- | :--- |
| AGP 8.8+ | 8.10.2 to 8.13+ | JDK 17 to JDK 21 | Gradle 8.11.1 |
| AGP 8.4 to 8.7 | 8.6 to 8.11+ | JDK 17 to JDK 21 | Gradle 8.7 |
| AGP 8.0 to 8.3 | 8.0 to 8.4 | JDK 17+ | Gradle 8.2 |
| AGP 7.4 | 7.5 to 7.6 | JDK 11 to JDK 19 | Gradle 7.6 |
| AGP 7.0 to 7.3 | 7.0 to 7.4 | JDK 11 to JDK 17 | Gradle 7.4.2 |
| AGP 4.0 to 4.2 | 6.1.1 to 6.9 | JDK 8 to JDK 11 | Gradle 6.9 |

### 4. Version Catalog TOML Parsing (`libs.versions.toml`)
- Previous Approach: Regular expressions parsed only literal numbers within `build.gradle` (such as `compileSdk = 34`). Modern projects declaring `compileSdk = libs.versions.compileSdk` caused the parser to fall back to an arbitrary default.
- Self-Adapting Engine: Reads `gradle/libs.versions.toml`, parses `[versions]` and `[plugins]` sections, and resolves version aliases dynamically across all modules.

### 5. Multi-Module Project Support and Name Collision Prevention
- Previous Approach: Assumed all projects had a single `:app` module, breaking multi-module repositories and feature-split projects.
- Self-Adapting Engine: Discovers all modules declared in `settings.gradle` / `settings.gradle.kts`, identifies application modules versus library modules, and allows targeting via `-Module`. When harvesting outputs, it prefixes file names with the module name if duplicate artifact names are detected.

### 6. Non-Destructive Artifact Harvesting (Copy vs. Move)
- Previous Approach: Executed `Move-Item` on artifacts in `app/build/outputs/`. This cleared Gradle's task outputs, invalidating build caches and forcing complete rebuilds on subsequent invocations.
- Self-Adapting Engine: Uses `Copy-Item` to replicate artifacts into the `-OutputDir` (`dist/`), leaving internal build outputs intact for fast incremental rebuilding.

### 7. Automated Signature Verification and SHA-256 Hashes
- Previous Approach: Build scripts concluded after compiling, leaving users uncertain whether release packages were signed or unsigned.
- Self-Adapting Engine: Runs `apksigner verify --verbose` on all output APKs, explicitly detailing signature verification status across v1, v2, v3, and v4 schemes, distinguishing debug signatures from release certificates, and calculating SHA-256 hashes for release distribution.

### 8. Network Resilience and Download Retry Logic
- Previous Approach: Single download requests for tools often failed on unstable connections, resulting in corrupted zip files.
- Self-Adapting Engine: Wraps downloads in multi-attempt retry loops with timeout protection and minimum payload size validation, verifying archive integrity before extraction.

---

## 5. Memory Architecture: Potato PC vs. Workstation

Gradle and the Kotlin compiler execute inside Java Virtual Machines. Unconstrained builds allocate large heaps, which on memory-limited machines can trigger heavy Windows pagefile swapping (100% disk usage and unresponsive operating systems).

### Understanding the Memory Flags

- `-Xmx` (Maximum Heap Size): The ceiling of physical memory that Java objects can occupy. On an 8 GB system, setting `-Xmx1536m` leaves sufficient RAM for Windows background tasks. On a 32 GB workstation, setting `-Xmx4096m` enables deeper caching in memory.
- `-XX:MaxMetaspaceSize`: Controls memory for class definitions and reflection metadata. Kotlin and Jetpack Compose generate substantial synthetic classes; setting this between `512m` and `1024m` prevents native memory leaks.
- `-XX:+UseParallelGC`: Uses a lightweight parallel garbage collector with lower CPU and tracking overhead than G1GC, optimizing throughput on resource-constrained systems.
- `--no-daemon`: Instructs the Gradle worker process to terminate immediately after compilation completes, returning all allocated memory directly to the operating system.
- `--max-workers`: Restricts concurrent compilation threads, preventing thread starvation on dual-core and quad-core CPUs.

### Hardware Memory Tuning Matrix

| Hardware Profile | Physical RAM | `GRADLE_OPTS` Configuration | Daemon Mode | Worker Threads | Parallel Tasks | Build Cache |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Ultra-Low (Potato PC) | <= 4.5 GB | `-Xmx1024m -XX:MaxMetaspaceSize=384m -XX:+UseParallelGC` | `--no-daemon` | 1 worker | Disabled | Disabled |
| Budget PC | 4.5 GB to 8.5 GB | `-Xmx1536m -XX:MaxMetaspaceSize=512m -XX:+UseParallelGC` | `--no-daemon` | 2 workers | Disabled | Optional |
| Balanced PC | 8.5 GB to 16 GB | `-Xmx2048m -XX:MaxMetaspaceSize=512m` | `--daemon` | 4 workers | Enabled (`--parallel`) | Enabled (`--build-cache`) |
| High-End Workstation | > 16 GB | `-Xmx4096m -XX:MaxMetaspaceSize=1024m` | `--daemon` | All logical cores | Enabled (`--parallel`) | Enabled (`--build-cache`) |

---

## 6. Standalone Turnkey PowerShell Script

For environments where cloning the repository is inconvenient, you can copy and paste this self-contained script directly into a PowerShell terminal inside any Android project root directory:

```powershell
# ==============================================================================
# UNIVERSAL ANDROID APK COMPILATION SCRIPT
# Run directly inside any Android project root directory.
# ==============================================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

$projectRoot = (Get-Location).Path
Write-Host "Inspecting Android project at: $projectRoot" -ForegroundColor Cyan

# 1. Parse compileSdk from build files or version catalog
$targetSdk = 34
$buildFiles = @("app\build.gradle.kts", "app\build.gradle", "build.gradle.kts", "build.gradle")
foreach ($bf in $buildFiles) {
    if (Test-Path $bf) {
        $content = Get-Content $bf -Raw
        if ($content -match 'compileSdk\s*=?\s*(\d+)') { $targetSdk = [int]$matches[1]; break }
        if ($content -match 'compileSdkVersion\s*=?\s*(\d+)') { $targetSdk = [int]$matches[1]; break }
    }
}
$catalogPath = "gradle\libs.versions.toml"
if (Test-Path $catalogPath) {
    $catContent = Get-Content $catalogPath -Raw
    if ($catContent -match 'compileSdk\s*=\s*["'']?(\d+)["'']?') { $targetSdk = [int]$matches[1] }
}
Write-Host "Target compileSdk detected: $targetSdk" -ForegroundColor Green

# 2. Configure session-scoped memory profile
$env:GRADLE_OPTS = "-Xmx1536m -XX:MaxMetaspaceSize=512m -XX:+UseParallelGC"
Write-Host "Session memory profile applied: $env:GRADLE_OPTS" -ForegroundColor Cyan

# 3. Locate or install JDK 17
$jdkDirs = @(
    "C:\Program Files\Eclipse Adoptium\jdk-17*",
    "C:\Program Files\Java\jdk-17*",
    "C:\Program Files\Microsoft\jdk-17*",
    "C:\Program Files\Android\Android Studio\jbr"
)
$jdk = Get-ChildItem -Path $jdkDirs -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1

if (-not $jdk) {
    Write-Host "Installing OpenJDK 17 via winget..." -ForegroundColor Yellow
    winget install EclipseAdoptium.Temurin.17.JDK --accept-source-agreements --accept-package-agreements --silent
    $jdk = Get-ChildItem -Path "C:\Program Files\Eclipse Adoptium\jdk-17*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
}

if (-not $jdk) {
    Write-Host "Compatible JDK not found. Please install JDK 17 manually." -ForegroundColor Red
    exit 1
}

$env:JAVA_HOME = $jdk.FullName
$env:Path = "$($jdk.FullName)\bin;$env:Path"
Write-Host "Using JDK at: $($jdk.FullName)" -ForegroundColor Green

# 4. Set up Android SDK and local.properties
$androidHome = if (Test-Path "C:\Android") { "C:\Android" } else {
    try { New-Item -ItemType Directory -Path "C:\Android" -Force -ErrorAction Stop | Out-Null; "C:\Android" }
    catch { "$env:LOCALAPPDATA\Android\Sdk" }
}
$env:ANDROID_HOME = $androidHome
$env:ANDROID_SDK_ROOT = $androidHome

$localPropsPath = ".\local.properties"
$formattedSdk = $androidHome.Replace('\', '/')
if (Test-Path $localPropsPath) {
    $existing = Get-Content $localPropsPath
    $updated = $false
    $newLines = @()
    foreach ($line in $existing) {
        if ($line -match '^\s*sdk\.dir\s*=') {
            $newLines += "sdk.dir=$formattedSdk"
            $updated = $true
        } else {
            $newLines += $line
        }
    }
    if (-not $updated) { $newLines += "sdk.dir=$formattedSdk" }
    Set-Content -Path $localPropsPath -Value $newLines -Encoding UTF8
} else {
    Set-Content -Path $localPropsPath -Value "sdk.dir=$formattedSdk" -Encoding UTF8
}

# 5. Ensure cmdline-tools exist in nested 'latest' directory
$sdkManager = "$androidHome\cmdline-tools\latest\bin\sdkmanager.bat"
if (-not (Test-Path $sdkManager)) {
    Write-Host "Downloading Android SDK Command-Line Tools..." -ForegroundColor Yellow
    $zip = "$env:TEMP\cmdline-tools.zip"
    $ext = "$env:TEMP\cmdline-extracted"
    Invoke-WebRequest -Uri "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $ext -Force
    $targetLatest = "$androidHome\cmdline-tools\latest"
    New-Item -ItemType Directory -Path "$androidHome\cmdline-tools" -Force | Out-Null
    if (Test-Path $targetLatest) { Remove-Item $targetLatest -Recurse -Force -ErrorAction SilentlyContinue }
    Move-Item -Path "$ext\cmdline-tools" -Destination $targetLatest -Force
    Remove-Item $zip, $ext -Recurse -Force -ErrorAction SilentlyContinue
}

# 6. Accept licenses and install platform components
$licenseFile = "$androidHome\licenses\android-sdk-license"
if (-not (Test-Path $licenseFile)) {
    New-Item -ItemType Directory -Path "$androidHome\licenses" -Force | Out-Null
    Set-Content -Path $licenseFile -Value "8933bad161af4178b1185d1a37fbf41ea5269c55`nd56f5187479451eabf01fb78af6dfcb131a6481e`n24333f8a63b6824ea7279bf34f796040be778e1e`n84831b9409646a918e30573bab4c9c91346d8abd"
}
& $sdkManager "platform-tools" "platforms;android-$targetSdk" "build-tools;$targetSdk.0.0"

# 7. Ensure Gradle Wrapper exists
if (-not (Test-Path ".\gradlew.bat")) {
    Write-Host "Bootstrapping Gradle Wrapper 8.11.1..." -ForegroundColor Yellow
    $gZip = "$env:TEMP\gradle-dist.zip"
    $gExt = "$env:TEMP\gradle-dist-ext"
    Invoke-WebRequest -Uri "https://services.gradle.org/distributions/gradle-8.11.1-bin.zip" -OutFile $gZip -UseBasicParsing
    Expand-Archive -Path $gZip -DestinationPath $gExt -Force
    $gBat = (Get-ChildItem -Path $gExt -Filter "gradle.bat" -Recurse | Select-Object -First 1).FullName
    & $gBat wrapper --gradle-version 8.11.1
    Remove-Item $gZip, $gExt -Recurse -Force -ErrorAction SilentlyContinue
}

# 8. Compile and copy artifacts to dist directory
Write-Host "Executing build..." -ForegroundColor Cyan
.\gradlew.bat assembleRelease --no-daemon --max-workers=2

$distDir = ".\dist"
New-Item -ItemType Directory -Path $distDir -Force | Out-Null
Get-ChildItem -Path ".\app\build\outputs" -Include "*.apk","*.aab" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    $targetFile = Join-Path $distDir $_.Name
    Copy-Item -Path $_.FullName -Destination $targetFile -Force
    $sizeMb = [math]::Round((Get-Item $targetFile).Length / 1MB, 2)
    Write-Host "Artifact copied to: $targetFile ($sizeMb MB)" -ForegroundColor Green
}
```

---

## 7. Troubleshooting and Diagnostic Dictionary

### 1. "Running scripts is disabled on this system"
- Cause: PowerShell execution policy is set to `Restricted` by default on Windows clients.
- Remedy: Use `setup-windows.bat`, which invokes PowerShell with `-ExecutionPolicy Bypass` automatically, or adjust the execution policy for your active session:
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
  ```

### 2. `java.lang.OutOfMemoryError: Java heap space` or System Freezing
- Cause: Unconstrained JVM processes exceed available physical memory, forcing Windows into aggressive disk paging.
- Remedy: Apply the low-memory profile to cap heap usage and disable background daemons:
  ```cmd
  setup-windows.bat -BuildType Release -ForceLowMem
  ```

### 3. `SDK location not found` or Invalid SDK Directory
- Cause: Gradle cannot locate the Android SDK, or `local.properties` contains unescaped Windows backslashes.
- Remedy: The engine automatically creates or updates `local.properties` using forward slashes (`sdk.dir=C:/Android`). If setting paths manually, always use forward slashes or escaped backslashes (`sdk.dir=C:\\Android`).

### 4. `Release build failed: signingConfig is not configured`
- Cause: The target application module defines a release build type without specifying release signing credentials or fallback signing configurations.
- Remedy: Assemble a debug variant instead, which uses the standard auto-generated Android debug certificate:
  ```cmd
  setup-windows.bat -BuildType Debug
  ```
  Alternatively, configure signing credentials in your module's `build.gradle` or `build.gradle.kts`:
  ```kotlin
  android {
      signingConfigs {
          create("release") {
              storeFile = file("my-release-key.jks")
              storePassword = "password"
              keyAlias = "my-alias"
              keyPassword = "password"
          }
      }
      buildTypes {
          release {
              signingConfig = signingConfigs.getByName("release")
          }
      }
  }
  ```

### 5. `Failed to find target with hash string 'android-XX'`
- Cause: The required Android platform SDK version is missing from the local SDK installation.
- Remedy: Run the engine without `-SkipSdkInstall` and include `-AcceptLicenses`. You can also override the target SDK version directly from the command line:
  ```cmd
  setup-windows.bat -CompileSdkOverride 34 -AcceptLicenses
  ```

### 6. `Unsupported class file major version` (JDK / AGP Mismatch)
- Cause: The active Java Development Kit version is incompatible with the Gradle or Android Gradle Plugin version configured in the project.
- Remedy: Android APK Builder evaluates compatibility automatically. To point to an explicit JDK installation, use the `-JdkPath` parameter:
  ```cmd
  setup-windows.bat -JdkPath "C:\Program Files\Eclipse Adoptium\jdk-17.0.10.7-hotspot"
  ```

### 7. Gradle Wrapper Missing or Corrupted Wrapper Archive
- Cause: Repositories cloned without the wrapper binary (`gradle-wrapper.jar`), or a zero-byte placeholder checked into version control.
- Remedy: The engine detects corrupted or missing wrapper archives and automatically downloads and bootstraps a fresh, compatible Gradle distribution.

### 8. Android SDK License Agreement Not Accepted
- Cause: SDK components cannot be downloaded until official Google license terms are accepted.
- Remedy: Pass the `-AcceptLicenses` parameter to allow the engine to automatically confirm license agreements:
  ```cmd
  setup-windows.bat -AcceptLicenses
  ```
