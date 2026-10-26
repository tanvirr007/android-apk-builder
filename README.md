# Android APK Builder

### Universal headless Android APK and AAB compilation engine for Windows

[![Platform: Windows](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6?style=flat-square&logo=windows&logoColor=white)](https://microsoft.com/windows)
![Visitors](https://visitor-badge.laobi.icu/badge?page_id=tanvirr007.android-apk-builder)

---

## Overview

Android APK Builder is a standalone build automation engine that compiles Kotlin, Java, and Jetpack Compose Android applications on Windows 10 and 11 from the command line without Android Studio.

Android Studio consumes 4 GB to 8 GB of RAM at idle. Android APK Builder runs directly in PowerShell or Command Prompt, configuring memory to match host hardware and compiling projects without an IDE.

### Project requirements

The engine compiles standard Android applications configured with Gradle:

- **Supported projects.** Android applications written in Java, Kotlin, or mixed source trees with `build.gradle` or `build.gradle.kts` files and the `com.android.application` plugin.
- **Unsupported targets.** AOSP or custom ROM platform packages configured with `Android.bp` or `Android.mk`, standalone non-Android Java applications, and legacy Ant or Eclipse ADT projects.

### Self-adapting architecture

The engine analyzes host hardware and project configuration files before starting a build:

- **Project inspection.** Parses Groovy build files, Kotlin DSL scripts, and Gradle version catalogs to extract target SDKs, build-tools, Android Gradle Plugin versions, and project module structures.
- **Compatibility resolution.** Evaluates project components against an integrated compatibility matrix to verify compiler and runtime requirements before launching Gradle.
- **Hardware-aware memory tuning.** Reads physical RAM and configures JVM heap limits, garbage collection options, and worker thread limits to prevent out-of-memory errors on 4 GB systems while enabling parallel caching on multi-core workstations.
- **Session-scoped environment.** Sets environment variables strictly within the running script process, leaving the Windows registry and persistent environment untouched.
- **Non-destructive operations.** Updates `sdk.dir` in `local.properties` using forward slashes while preserving existing comments and custom properties, and copies generated artifacts rather than moving them.
- **Signature verification.** Computes SHA-256 hashes for output packages and runs verification across APK signature schemes v1, v2, v3, and v4 using `apksigner`.

---

## 1. Quick start

Android APK Builder provides two primary interfaces:
1. `build.bat`: Windows batch launcher that runs the interactive wizard, accepts dragged project folders, and forwards command-line flags while bypassing PowerShell execution policies.
2. `setup-windows.ps1`: PowerShell automation engine that exposes all build parameters.

### Interactive build wizard

To run the interactive wizard on Windows:
1. Double-click `build.bat` or run it from Command Prompt:
   ```cmd
   build.bat
   ```
2. When executed outside an Android project directory, the wizard prompts for the project path. Type the path or drag and drop your project folder into the window.
3. Choose a build option:
   - Press **Enter** to build a Release APK with default settings.
   - Press **C** and then **Enter** to customize build variants, package formats, clean build tasks, and memory limits.
4. The terminal pauses after completion so you can review harvested artifact paths and signature verification details before closing.

Dragging and dropping an Android project folder onto `build.bat` in File Explorer starts the build immediately.

### Basic invocations

#### Run inside an Android project directory
Open Command Prompt or PowerShell, navigate to the target Android project directory, and run:

```cmd
cd C:\path\to\your-android-project
C:\path\to\android-apk-builder\build.bat -BuildType Release
```

#### Specify the project directory explicitly
Pass `-ProjectDir` to run the builder from any location:

```cmd
C:\path\to\android-apk-builder\build.bat -ProjectDir "C:\path\to\your-android-project" -BuildType Release
```

#### Build debug, release, or both variants
Select the variant to assemble:

```cmd
rem Build debug APK
build.bat -ProjectDir "C:\path\to\project" -BuildType Debug

rem Build release APK
build.bat -ProjectDir "C:\path\to\project" -BuildType Release

rem Build both debug and release variants in a single run
build.bat -ProjectDir "C:\path\to\project" -BuildType Both
```

#### Select artifact types
Choose whether to produce installable APK packages, Google Play AAB bundles, or both:

```cmd
rem Build Google Play App Bundle (.aab)
build.bat -ProjectDir "C:\path\to\project" -ArtifactType AAB

rem Build both APK and AAB packages
build.bat -ProjectDir "C:\path\to\project" -ArtifactType Both
```

#### Target specific multi-module projects
For repositories with multiple application modules, target the desired module:

```cmd
build.bat -ProjectDir "C:\path\to\project" -Module ":app" -BuildType Release
```

#### Memory tuning controls
Apply specific hardware profiles:

```cmd
rem Force low-memory profile for budget systems with 4 GB to 8 GB RAM
build.bat -ProjectDir "C:\path\to\project" -ForceLowMem

rem Force high-performance profile for multi-core workstations
build.bat -ProjectDir "C:\path\to\project" -HighMem
```

#### Continuous integration and automation switches
Accept SDK licenses, clean workspaces, or build offline:

```cmd
build.bat -ProjectDir "C:\path\to\project" -AcceptLicenses -CleanFirst -OutputDir "C:\builds"
```

### Parameter reference

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `-ProjectDir` | String | Current Directory | Path to the target Android project root. |
| `-BuildType` | String | `Release` | Build variant to assemble: `Release`, `Debug`, or `Both`. |
| `-ArtifactType` | String | `APK` | Output package format: `APK`, `AAB`, or `Both`. |
| `-Module` | String | Auto-detected | Specific application module name, such as `:app` or `app`. |
| `-Variant` | String | Auto-detected | Specific build variant name, such as `release` or `freeRelease`. |
| `-OutputDir` | String | `dist` | Destination folder relative to the project root for harvested artifacts. |
| `-ForceLowMem` | Switch | Off | Forces the low-memory profile with a 1.5 GB heap ceiling, single worker, and no daemon. |
| `-HighMem` | Switch | Off | Forces the high-performance profile with a 4 GB heap, parallel workers, and build cache. |
| `-AcceptLicenses` | Switch | Off | Accepts official Android SDK licenses non-interactively. |
| `-CleanFirst` | Switch | Off | Executes the Gradle `clean` task prior to assembling artifacts. |
| `-Offline` | Switch | Off | Runs Gradle compilation in offline mode using cached dependencies. |
| `-DryRun` | Switch | Off | Inspects project, resolves dependencies, and plans build without compiling. |
| `-SkipSdkInstall` | Switch | Off | Skips downloading or updating missing Android SDK platforms and build-tools. |
| `-SkipJdkInstall` | Switch | Off | Skips automated winget installation of OpenJDK if host lacks compatible JDK. |
| `-SdkPath` | String | Auto-detected | Explicit custom file system path to the Android SDK. |
| `-JdkPath` | String | Auto-detected | Explicit custom file system path to the Java Development Kit. |
| `-CompileSdkOverride`| Integer | Auto-detected | Overrides detected `compileSdk` version, such as `35`. |
| `-BuildToolsOverride`| String | Auto-detected | Overrides detected `build-tools` version string, such as `35.0.0`. |
| `-VerboseLog` | Switch | Off | Enables verbose diagnostic output during execution. |
| `-Interactive` | Switch | Off | Launches the interactive step-by-step build wizard. |
| `-KeystorePath` | String | Auto-generated | Path to an existing custom `.jks` or `.keystore` file. |
| `-StorePassword` | String | `android` | Keystore password for release signing. |
| `-KeyAlias` | String | `release` | Key alias name for release signing. |
| `-KeyPassword` | String | `StorePassword` | Private key password. |
| `-KeyDName` | String | Auto-generated | Certificate Distinguished Name, such as `CN=Dev,O=Org,C=US`. |
| `-SkipSigning` | Switch | Off | Bypasses automated release keystore generation and APK signing. |

---

## 2. How source code becomes an APK

When building an Android application from the terminal, the build process transforms human-readable source code into a signed, aligned, and optimized binary package:

```
+--------------------------------------------------------------------------+
| 1. Source Code Files: .kt, .java, .xml                                   |
|    Instructions defining your UI, data structures, and logic.            |
+--------------------------------------------------------------------------+
                                     |
                                     v
+--------------------------------------------------------------------------+
| 2. Kotlin and Java Compilers: kotlinc and javac via JDK 17 or higher     |
|    Translates source code into standard Java Virtual Machine bytecode    |
|    in .class files.                                                      |
+--------------------------------------------------------------------------+
                                     |
                                     v
+--------------------------------------------------------------------------+
| 3. Android Dexer and Code Optimizer: D8 and R8                           |
|    Converts JVM bytecode into Dalvik Executable .dex bytecode            |
|    for the Android Runtime. Release builds run R8 tree-shaking to        |
|    remove unused methods and classes.                                    |
+--------------------------------------------------------------------------+
                                     |
                                     v
+--------------------------------------------------------------------------+
| 4. Android Asset Packaging Tool: AAPT2                                   |
|    Compiles XML layouts, drawables, and strings into compact binary XML  |
|    and builds the compiled resources table in resources.arsc.            |
+--------------------------------------------------------------------------+
                                     |
                                     v
+--------------------------------------------------------------------------+
| 5. Package Assembly, Alignment, and Signing: zipalign and apksigner      |
|    Packages all .dex files, assets, and metadata into a compressed APK,  |
|    aligns data boundaries to 4-byte offsets, and signs the archive.      |
+--------------------------------------------------------------------------+
```

Running this pipeline requires three toolchain components rather than the full Android Studio desktop application:
1. Java Development Kit: JDK 17 or 21 to run the build system and compilers.
2. Gradle: The orchestration engine coordinating dependencies, tasks, and plugins.
3. Android SDK Command-Line Tools: Provides core toolchain binaries including `sdkmanager`, `aapt2`, `d8`, and `apksigner`.

---

## 3. Six-stage compilation pipeline

The automation engine executes a structured six-stage pipeline to compile projects:

```
[Stage 1: Project Inspection]   - Parses build files, catalogs, and module trees.
             |
[Stage 2: Memory Profiling]     - Benchmarks system RAM and selects JVM profiles.
             |
[Stage 3: JDK Resolution]       - Verifies host JDKs, matches matrix, or installs via winget.
             |
[Stage 4: SDK & Tools Setup]    - Sets up SDK paths, nested tools, and licenses.
             |
[Stage 5: Gradle Bootstrapping] - Validates wrapper or downloads official distribution.
             |
[Stage 6: Build & Harvesting]   - Compiles, copies to output, calculates hashes, and verifies signatures.
```

### Stage 1: Project inspection and compatibility discovery
- Scans `settings.gradle` and `settings.gradle.kts` to identify all project modules.
- Parses module build files and Gradle version catalogs at `gradle/libs.versions.toml`.
- Extracts build properties: `compileSdk`, `targetSdk`, `minSdk`, `buildToolsVersion`, AGP version, Kotlin version, Java toolchain targets, signing configurations, and namespaces.
- Evaluates the Android Gradle Plugin version against the built-in compatibility matrix to determine supported JDK versions and target Gradle distributions.

### Stage 2: Hardware profiling and memory tuning
- Queries host memory capacity through Windows WMI classes `Win32_OperatingSystem` and `Win32_PhysicalMemory`.
- Categorizes the host machine into performance tiers:
  - Systems with 8.5 GB RAM or less: Applies conservative heap limits, lightweight garbage collection via `-XX:+UseParallelGC`, single or dual worker threads, and disables persistent background daemons.
  - Systems with more than 8.5 GB RAM: Allocates heaps of 4 GB or more, enables daemon caching, allows parallel tasks, and enables `--build-cache`.
- Configures environment variables strictly for the active process session, avoiding changes to the Windows registry.

### Stage 3: JDK resolution and validation
- Searches standard system paths for verified 64-bit JDK installations: Eclipse Adoptium, Microsoft OpenJDK, Oracle Java, BellSoft Liberica, Amazon Corretto, Azul Zulu, Android Studio embedded runtimes, and the user `.jdks` and `.gradle/jdks` directories.
- Evaluates Gradle Daemon JVM criteria (`gradle/gradle-daemon-jvm.properties`), matching requested Java versions and vendors (such as JetBrains Runtime) directly to existing host JDKs to prevent redundant toolchain downloads.
- Runs `java.exe -version` and reads `release` manifests to verify major versions, vendors, and 64-bit architecture support.
- Matches available runtimes against project requirements, prioritizing LTS releases Java 17 and Java 21, and forwards all verified host JDKs via `org.gradle.java.installations.paths`.
- If no compatible JDK is detected, the engine attempts an unattended installation of Eclipse Adoptium Temurin OpenJDK through Windows Package Manager (`winget`).

### Stage 4: Android SDK, platform tools, and licenses setup
- Discovers existing Android SDK roots from custom parameters, project `local.properties`, `ANDROID_HOME`, `ANDROID_SDK_ROOT`, AppData paths, or standard installation directories.
- Generates or updates `local.properties` with forward-slash formatted paths, such as `sdk.dir=C:/Android`, preserving existing properties and creating a `local.properties.bak` backup.
- Validates the `cmdline-tools` directory structure. If tools are extracted outside the required `latest` folder, the engine restructures them automatically. If missing, it downloads the official Google command-line tools package.
- Accepts SDK license agreements non-interactively when `-AcceptLicenses` is specified.
- Verifies and downloads required SDK platform packages and build tools matching the project target.

### Stage 5: Gradle wrapper verification and recovery
- Verifies the integrity of `gradlew.bat`, `gradle/wrapper/gradle-wrapper.jar`, and `gradle/wrapper/gradle-wrapper.properties`.
- Confirms that `gradle-wrapper.jar` is valid and non-empty to guard against incomplete Git checkouts.
- If the wrapper is missing or corrupted, the engine downloads the official Gradle binary distribution matched to the project AGP requirements, runs `gradle wrapper`, and generates a clean wrapper environment.

### Stage 6: Compilation, signing, harvesting, and signature verification
- Constructs the target Gradle task list based on the requested `-BuildType` and `-ArtifactType`.
- Scopes tasks to the identified application module, such as `:app:assembleRelease`.
- Injects release signing configurations: Creates a project release keystore if none exists, and supplies a temporary init script to configure release signing in Gradle, avoiding local build crashes caused by missing keystore secrets.
- Aligns and signs release APKs: When an unsigned release APK is produced, the engine aligns the archive to 4-byte boundaries with `zipalign` and signs it across v1, v2, and v3 schemes using `apksigner`.
- Preserves and mirrors keystores: Stores the keystore in `android-apk-builder/dist/<project-name>/` and mirrors it into the project `dist/` folder. Reuses existing keystores across subsequent builds to maintain signature continuity.
- Generates a deployment manifest: Writes `signing-credentials.txt` containing passwords, key aliases, certificate fingerprints, a Base64-encoded keystore for CI secrets, and a ready GitHub Actions step.
- Copies harvested artifacts into the specified output directory, defaulting to `dist/`, and mirrors them to `android-apk-builder/dist/<project-name>/`.
- Calculates SHA-256 cryptographic hashes for every harvested artifact.
- Invokes `apksigner` to verify signatures and report active schemes v1, v2, v3, and v4.

---

## 4. Key architectural improvements

Android APK Builder improves upon conventional terminal build scripts across several areas:

### 1. Non-destructive local.properties management
- Previous scripts: Overwrote `local.properties` completely, erasing developer-defined properties such as `ndk.dir`, `cmake.dir`, and custom build flags.
- This engine: Reads the file line by line, updates only the `sdk.dir` key using normalized forward slashes, preserves all existing comments and properties, and creates a backup file at `local.properties.bak`.

### 2. Session-scoped environment variables
- Previous scripts: Called `[Environment]::SetEnvironmentVariable` to set permanent User registry values, altering paths globally for future terminals and other developer tools.
- This engine: Scopes `$env:JAVA_HOME`, `$env:ANDROID_HOME`, and `$env:GRADLE_OPTS` strictly to the executing PowerShell process. Once the build finishes, the host environment remains untouched.

### 3. AGP, Gradle, and JDK compatibility matrix
- Previous scripts: Hardcoded JDK 17 and a single fixed Gradle version, causing build failures when compiling older projects or AGP 8.8+ releases.
- This engine: Evaluates the project AGP version and wrapper settings dynamically to apply matching toolchain versions:

| AGP version | Compatible Gradle version | Supported JDK range | Default target Gradle |
| :--- | :--- | :--- | :--- |
| AGP 8.8+ | 8.10.2 to 8.13+ | JDK 17 to JDK 21 | Gradle 8.11.1 |
| AGP 8.4 to 8.7 | 8.6 to 8.11+ | JDK 17 to JDK 21 | Gradle 8.7 |
| AGP 8.0 to 8.3 | 8.0 to 8.4 | JDK 17 or higher | Gradle 8.2 |
| AGP 7.4 | 7.5 to 7.6 | JDK 11 to JDK 19 | Gradle 7.6 |
| AGP 7.0 to 7.3 | 7.0 to 7.4 | JDK 11 to JDK 17 | Gradle 7.4.2 |
| AGP 4.0 to 4.2 | 6.1.1 to 6.9 | JDK 8 to JDK 11 | Gradle 6.9 |

### 4. Version catalog parsing
- Previous scripts: Relied on regular expressions matching only literal numbers within `build.gradle`, such as `compileSdk = 34`. Projects declaring versions via version catalogs fell back to arbitrary defaults.
- This engine: Reads `gradle/libs.versions.toml`, parses `[versions]` and `[plugins]` tables, and resolves version references across all modules.

### 5. Multi-module project support and collision prevention
- Previous scripts: Assumed all projects contained only a single `:app` module, failing on multi-module repositories and feature-split projects.
- This engine: Detects modules declared in `settings.gradle` or `settings.gradle.kts`, identifies application modules versus library modules, and allows targeting via `-Module`. If multiple modules produce identical artifact names, it prefixes file names with the module name during harvesting.

### 6. Copying artifacts instead of moving them
- Previous scripts: Moved files out of Gradle build outputs, clearing task caches and forcing complete rebuilds on subsequent runs.
- This engine: Copies artifacts into `-OutputDir`, leaving internal build outputs intact for incremental rebuilds.

### 7. Signature verification and SHA-256 hashes
- Previous scripts: Ended execution after compilation without verifying signatures, leaving output signing status unclear.
- This engine: Runs `apksigner verify --verbose` on all output APKs, reports scheme support across v1, v2, v3, and v4, and generates SHA-256 hashes for release distribution manifests.

### 8. Network retry logic
- Previous scripts: Single download requests for tools failed on unstable connections, resulting in corrupted archives.
- This engine: Wraps tool downloads in retry loops with timeout protection and payload size validation before extraction.

---

## 5. Memory architecture and hardware profiles

Gradle and the Kotlin compiler run inside Java Virtual Machines. Unconstrained heap allocation on memory-limited machines triggers heavy Windows pagefile swapping, leading to disk thrashing and system unresponsiveness.

### Memory flags

- `-Xmx`: Caps the physical heap memory available to Java objects. On an 8 GB system, setting `-Xmx1536m` leaves RAM available for system processes. On a 32 GB workstation, setting `-Xmx4096m` enables deeper in-memory caching.
- `-XX:MaxMetaspaceSize`: Limits memory for class definitions and reflection metadata. Setting this between `512m` and `1024m` accommodates synthetic classes generated by Kotlin and Jetpack Compose.
- `-XX:+UseParallelGC`: Enables a lightweight parallel garbage collector with lower CPU overhead than G1GC, improving throughput on constrained machines.
- `--no-daemon`: Instructs the Gradle worker process to exit immediately after compilation completes, returning memory to the operating system.
- `--max-workers`: Limits concurrent compilation threads to avoid CPU contention.

### Hardware memory matrix

| Hardware profile | Physical RAM | `GRADLE_OPTS` settings | Daemon mode | Worker threads | Parallel tasks | Build cache |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Constrained systems | 4.5 GB or less | `-Xmx1024m -XX:MaxMetaspaceSize=384m -XX:+UseParallelGC` | `--no-daemon` | 1 worker | Disabled | Disabled |
| Budget systems | 4.5 GB to 8.5 GB | `-Xmx1536m -XX:MaxMetaspaceSize=512m -XX:+UseParallelGC` | `--no-daemon` | 2 workers | Disabled | Optional |
| Standard systems | 8.5 GB to 16 GB | `-Xmx2048m -XX:MaxMetaspaceSize=512m` | `--daemon` | 4 workers | Enabled with `--parallel` | Enabled with `--build-cache` |
| Workstations | More than 16 GB | `-Xmx4096m -XX:MaxMetaspaceSize=1024m` | `--daemon` | All logical cores | Enabled with `--parallel` | Enabled with `--build-cache` |

---

## 6. Standalone PowerShell script

For environments where cloning the repository is not feasible, copy and run this self-contained script inside any Android project root directory:

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

## 7. Troubleshooting and diagnostic reference

### 1. Running scripts is disabled on this system
- Cause: Windows sets the default PowerShell execution policy to `Restricted`, which prevents scripts from running.
- Remedy: Use `build.bat`, which invokes PowerShell with `-ExecutionPolicy Bypass` automatically. Alternatively, adjust the execution policy for your active session:
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
  ```

### 2. Out-of-memory errors or system freezing
- Cause: The Gradle process exceeds available physical RAM, forcing Windows to page heavily to disk and slowing down the build.
- Remedy: Apply the low-memory profile to cap heap usage and disable background daemons:
  ```cmd
  build.bat -BuildType Release -ForceLowMem
  ```

### 3. SDK location not found
- Cause: Gradle cannot locate the Android SDK, or `local.properties` contains unescaped Windows backslashes.
- Remedy: The engine formats `sdk.dir` with forward slashes, such as `sdk.dir=C:/Android`, and preserves the rest of the file. If setting paths manually, format them with forward slashes or escaped backslashes, such as `sdk.dir=C:\\Android`.

### 4. Release signing not configured
- Cause: The target application module defines a release build type without specifying release signing credentials.
- Remedy: Assemble a debug variant to sign with the standard debug certificate:
  ```cmd
  build.bat -BuildType Debug
  ```
  Alternatively, configure signing credentials in your module build file:
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

### 5. Target hash string not found
- Cause: The required Android platform SDK package is missing from the local SDK installation.
- Remedy: Run the engine without `-SkipSdkInstall` and include `-AcceptLicenses`. You can also override the target SDK version from the command line:
  ```cmd
  build.bat -CompileSdkOverride 34 -AcceptLicenses
  ```

### 6. Unsupported class file major version
- Cause: The selected Java Development Kit version is incompatible with the Gradle or Android Gradle Plugin version configured in the project.
- Remedy: The engine evaluates compatibility automatically. To specify a JDK installation directly, pass `-JdkPath`:
  ```cmd
  build.bat -JdkPath "C:\Program Files\Eclipse Adoptium\jdk-17.0.10.7-hotspot"
  ```

### 7. Gradle wrapper missing or corrupted
- Cause: The project lacks `gradle/wrapper/gradle-wrapper.jar`, or the wrapper file is empty.
- Remedy: The engine detects missing or invalid wrapper archives and downloads a matching Gradle distribution to regenerate the wrapper files automatically.

### 8. Android SDK license agreement not accepted
- Cause: SDK components cannot be downloaded until Google license terms are accepted.
- Remedy: Pass `-AcceptLicenses` to accept license terms non-interactively:
  ```cmd
  build.bat -AcceptLicenses
  ```

---

## 8. Reporting issues and feedback

- [Report a bug](https://github.com/tanvirr007/android-apk-builder/issues/new?template=bug_report.yml)
- [Request a feature](https://github.com/tanvirr007/android-apk-builder/issues/new?template=feature_request.yml)
- [Browse all issues](https://github.com/tanvirr007/android-apk-builder/issues)
