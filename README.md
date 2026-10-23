<div align="center">

# Android APK Builder

### Universal Headless Android APK Compilation Engine & Windows CLI Guide

<br/>

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6?style=flat-square&logo=windows&logoColor=white)](https://microsoft.com/windows)
[![Target: Any Android Project](https://img.shields.io/badge/Target-Any%20Android%20Gradle%20Project-3DDC84?style=flat-square&logo=android&logoColor=white)](https://developer.android.com)
![Visitors](https://visitor-badge.laobi.icu/badge?page_id=tanvirr007.android-apk-builder)

</div>

---

## Overview

**Android APK Builder** is a standalone, universal automation engine and comprehensive technical guide designed to compile **any modern Android application** (Kotlin, Java, Jetpack Compose) directly on Microsoft Windows from the command line—**with zero Android Studio installation required**.

Whether running on a budget machine with 4 GB of RAM ("Potato PC") or a high-end multi-core workstation, this tool handles JDK setup, Android SDK command-line tools installation, dynamic API target resolution, automatic license signing, memory profiling, and Gradle execution in a single unattended command.

---

## 1. Quick Start (The 1-Click Way)

### Method A: Run from Your Android Project Directory
Open Command Prompt or PowerShell, navigate to any Android project on your disk, and invoke the builder:

```cmd
cd C:\path\to\your-android-project
C:\path\to\android-apk-builder\setup-windows.bat -BuildType Release
```

### Method B: Pass the Project Path Directly
```cmd
cd C:\path\to\android-apk-builder
setup-windows.bat -ProjectDir "C:\path\to\your-android-project" -BuildType Release
```

### Method C: Force Low-Memory Mode (For Low-RAM / Potato PCs)
```cmd
setup-windows.bat -ProjectDir "C:\path\to\your-android-project" -BuildType Release -ForceLowMem
```

---

## 2. Conceptual Foundation: How Code Becomes an APK

If you have never built an Android app from the terminal, think of building an APK like manufacturing a precision device from blueprints:

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

To run this entire pipeline, you do **not** need Android Studio (which consumes 4 GB to 8 GB of RAM merely sitting idle). You only need:
1. **JDK 17 or 21:** The Java engine running the compilers.
2. **Gradle:** The task runner that coordinates dependencies and build phases.
3. **Android SDK Command-Line Tools:** The official Google binaries (`sdkmanager`, `aapt2`, `d8`).

---

## 3. Memory Architecture: Potato PC vs. High-Performance Workstation

Gradle and the Kotlin compiler run inside Java Virtual Machines. By default, Gradle spawns background daemons and allocates large heap spaces. On budget machines with limited RAM (4 GB to 8 GB), unconstrained Gradle runs exhaust physical memory, triggering aggressive Windows pagefile swapping (100% disk usage and total OS freezing).

### What Each Flag Does

- **`-Xmx` (Maximum Heap Size):** The ceiling of memory that Java objects can occupy.
  - On a 4 GB RAM PC, setting `-Xmx1536m` limits the heap to 1.5 GB, keeping the OS responsive.
  - On a 16 GB+ workstation, setting `-Xmx4096m` allows Gradle to cache more class files in memory.
- **`-XX:MaxMetaspaceSize`:** Memory allocated for loaded class definitions and reflection metadata. Kotlin and Jetpack Compose generate thousands of synthetic classes. Setting this to `512m` prevents native Metaspace leaks.
- **`-XX:+UseParallelGC`:** Uses a lightweight parallel garbage collector with lower CPU and memory tracking overhead than the modern G1GC collector, ideal for constrained systems.
- **`--no-daemon`:** Instructs Gradle to terminate its background worker immediately after compilation finishes, instantly releasing all memory back to Windows.
- **`--max-workers=2`:** Limits parallel compilation threads to 2, preventing CPU thread starvation on dual-core and quad-core CPUs.

### Tuning Comparison Matrix

- **`GRADLE_OPTS`**
  - Potato PC (<= 8 GB RAM): `-Xmx1536m -XX:MaxMetaspaceSize=512m -XX:+UseParallelGC`
  - Balanced (8 - 16 GB RAM): `-Xmx2048m -XX:MaxMetaspaceSize=512m`
  - Workstation (32 GB+ RAM): `-Xmx4096m -XX:MaxMetaspaceSize=1024m`
- **Daemon Policy**
  - Potato PC: `--no-daemon` (reclaims RAM immediately)
  - Balanced: `--daemon` (keeps warm daemon)
  - Workstation: `--daemon` (instant incremental builds)
- **Worker Threads**
  - Potato PC: `--max-workers=2`
  - Balanced: `--max-workers=4`
  - Workstation: Default (all logical cores)
- **Parallel Tasks**
  - Potato PC: Disabled (`org.gradle.parallel=false`)
  - Balanced: Enabled (`org.gradle.parallel=true`)
  - Workstation: Enabled (`org.gradle.parallel=true`)
- **Build Cache**
  - Potato PC: Optional
  - Balanced: `--build-cache`
  - Workstation: `--build-cache`

---

## 4. Universal Turnkey PowerShell Script (Copy & Paste)

If you prefer to run a single script without cloning extra files, copy and paste this complete block into PowerShell inside your Android project root:

```powershell
# ==============================================================================
# UNIVERSAL ANDROID APK COMPILATION SCRIPT — TANVIR HASAN (https://tanvir.info)
# Paste this directly into PowerShell inside ANY Android project root folder!
# ==============================================================================

# 1. Enforce TLS 1.2 and Suppress Progress Bars (Accelerates downloads by 10x)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

# 2. Inspect Project & Detect compileSdk
$targetDir = (Get-Location).Path
$buildFiles = @("app\build.gradle.kts", "app\build.gradle", "build.gradle.kts", "build.gradle")
$targetSdk = 36
foreach ($bf in $buildFiles) {
    if (Test-Path $bf) {
        $content = Get-Content $bf -Raw
        if ($content -match 'compileSdk\s*=?\s*(\d+)') { $targetSdk = [int]$matches[1]; break }
        if ($content -match 'compileSdkVersion\s*=?\s*(\d+)') { $targetSdk = [int]$matches[1]; break }
    }
}
Write-Host "[1/6] Target compileSdk detected: $targetSdk" -ForegroundColor Green

# 3. Configure Memory Limit for Host
$env:GRADLE_OPTS = "-Xmx1536m -XX:MaxMetaspaceSize=512m -XX:+UseParallelGC"
[Environment]::SetEnvironmentVariable("GRADLE_OPTS", $env:GRADLE_OPTS, "User")
Write-Host "[2/6] Memory profile applied: $env:GRADLE_OPTS" -ForegroundColor Cyan

# 4. Locate or Install JDK 17
$jdk = Get-ChildItem -Path @("C:\Program Files\Eclipse Adoptium\jdk-17*", "C:\Program Files\Java\jdk-17*", "C:\Program Files\Microsoft\jdk-17*", "C:\Program Files\Android\Android Studio\jbr") -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
if (-not $jdk) {
    Write-Host "[3/6] Installing OpenJDK 17 via winget..." -ForegroundColor Yellow
    winget install EclipseAdoptium.Temurin.17.JDK --accept-source-agreements --accept-package-agreements --silent
    $jdk = Get-ChildItem -Path "C:\Program Files\Eclipse Adoptium\jdk-17*" -Directory | Select-Object -First 1
}
$env:JAVA_HOME = $jdk.FullName
$env:Path = "$($jdk.FullName)\bin;$env:Path"
[Environment]::SetEnvironmentVariable("JAVA_HOME", $jdk.FullName, "User")
Write-Host "[3/6] JDK configured at: $($jdk.FullName)" -ForegroundColor Green

# 5. Set up Android SDK Directory (Non-Admin safe)
$androidHome = if (Test-Path "C:\Android") { "C:\Android" } else {
    try { New-Item -ItemType Directory -Path "C:\Android" -Force -ErrorAction Stop | Out-Null; "C:\Android" }
    catch { "$env:LOCALAPPDATA\Android\Sdk" }
}
New-Item -ItemType Directory -Force -Path "$androidHome\cmdline-tools" | Out-Null
$env:ANDROID_HOME = $androidHome
[Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidHome, "User")
$sdkDirFormatted = $androidHome -replace '\\', '/'
Set-Content -Path ".\local.properties" -Value "sdk.dir=$sdkDirFormatted"

$sdkManager = "$androidHome\cmdline-tools\latest\bin\sdkmanager.bat"
if (-not (Test-Path $sdkManager)) {
    Write-Host "[4/6] Downloading Android command-line tools..." -ForegroundColor Yellow
    $zip = "$env:TEMP\cmdline-tools.zip"
    $ext = "$env:TEMP\cmdline-extracted"
    Invoke-WebRequest -Uri "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $ext -Force
    $targetLatest = "$androidHome\cmdline-tools\latest"
    if (Test-Path $targetLatest) { Remove-Item $targetLatest -Recurse -Force -ErrorAction SilentlyContinue }
    Move-Item -Path "$ext\cmdline-tools" -Destination $targetLatest -Force
    Remove-Item $zip, $ext -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "[4/6] Android SDK tools ready at: $sdkManager" -ForegroundColor Green

# 6. Auto-Accept Licenses & Install Required SDK Platform
Write-Host "[5/6] Installing platforms;android-$targetSdk and build-tools;$targetSdk.0.0..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path "$androidHome\licenses" | Out-Null
Set-Content -Path "$androidHome\licenses\android-sdk-license" -Value "8933bad161af4178b1185d1a37fbf41ea5269c55`nd56f5187479451eabf01fb78af6dfcb131a6481e`n24333f8a63b6824ea7279bf34f796040be778e1e`n84831b9409646a918e30573bab4c9c91346d8abd"
1..30 | ForEach-Object { "y" } | & $sdkManager --licenses | Out-Null
& $sdkManager "platform-tools" "platforms;android-$targetSdk" "build-tools;$targetSdk.0.0"

# 7. Bootstrap Gradle Wrapper if Missing
if (-not (Test-Path ".\gradlew.bat")) {
    Write-Host "[6/6] Bootstrapping Gradle Wrapper 8.11.1..." -ForegroundColor Yellow
    $gZip = "$env:TEMP\g.zip"
    $gExt = "$env:TEMP\g-ext"
    Invoke-WebRequest -Uri "https://services.gradle.org/distributions/gradle-8.11.1-bin.zip" -OutFile $gZip -UseBasicParsing
    Expand-Archive -Path $gZip -DestinationPath $gExt -Force
    $gBat = (Get-ChildItem -Path $gExt -Filter "gradle.bat" -Recurse | Select-Object -First 1).FullName
    & $gBat wrapper --gradle-version 8.11.1
    Remove-Item $gZip, $gExt -Recurse -Force -ErrorAction SilentlyContinue
}

# 8. Compile Release APK & Move to Project Root
Write-Host "Compiling release APK..." -ForegroundColor Cyan
.\gradlew.bat assembleRelease --no-daemon --max-workers=2

Write-Host "`nBUILD COMPLETE! Moving artifacts to project root..." -ForegroundColor Green
Get-ChildItem -Path ".\app\build\outputs" -Include "*.apk","*.aab" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    $dest = Join-Path (Get-Location).Path $_.Name
    Move-Item -Path $_.FullName -Destination $dest -Force
    Write-Host "Output moved to root: $dest ($([math]::Round((Get-Item $dest).Length/1MB, 2)) MB)" -ForegroundColor Green
}
```

---

## 5. Step-by-Step Technical Breakdown

### Step 1: Dynamic Project Discovery & compileSdk Parsing
Every Android Gradle project declares an API level it compiles against in its `build.gradle` or `build.gradle.kts` file:
```kotlin
android {
    compileSdk = 36 // or 35, 34, etc.
}
```
If a build script hardcodes an arbitrary version (e.g. 36), running it against a project targeting API 34 will fail with:
```
Failed to find target with hash string 'android-34' in: C:\Android
```
Android APK Builder dynamically scans the project's build files using regular expressions, extracts the exact `compileSdk` integer, and feeds it directly into `sdkmanager`.

---

### Step 2: Java Development Kit (JDK 17+) & Environment Hierarchy
Android Gradle Plugin (AGP) version 8.x and Kotlin 2.0+ strictly require Java 17+. Older versions (JDK 8 or JDK 11) will throw `UnsupportedClassVersionError`.

#### Session Variables vs. Windows Registry Variables
- `$env:JAVA_HOME = "..."`: Changes the variable **only for the current terminal**. Once you close the window, it disappears.
- `[Environment]::SetEnvironmentVariable("JAVA_HOME", "...", "User")`: Writes the variable into the **Windows Registry** under `HKEY_CURRENT_USER\Environment`. Every program and command prompt opened in the future inherits it.
- This builder configures **both**, guaranteeing immediate functionality in the current shell while permanently fixing the configuration for the operating system.

---

### Step 3: Android SDK & The "latest" Directory Trap
When downloading command-line tools from Google's repository, extracting the zip yields a folder called `cmdline-tools`. If you run `sdkmanager.bat` directly from `cmdline-tools\bin`, it crashes with:
```
Error: Could not determine SDK root.
```

**Why does this happen?**  
Google's `sdkmanager` script detects the root of the Android SDK by moving three directory levels up from its location:
- In `C:\Android\cmdline-tools\latest\bin\sdkmanager.bat`:
  - 1 level up = `latest`
  - 2 levels up = `cmdline-tools`
  - 3 levels up = `C:\Android` (Recognized as SDK root)

If `latest` is omitted, traversing up fails. Android APK Builder automatically nests the extracted tools inside a `latest` directory, resolving this error permanently.

---

### Step 4: Non-Admin Writable Paths & License Pre-Seeding

1. **Permission Isolation:** Writing directly to `C:\` requires Windows Administrator privileges. If a standard user runs the build, creating `C:\Android` produces `Access is denied`. Android APK Builder dynamically falls back to `%LOCALAPPDATA%\Android\Sdk`, which is 100% writable by any user.
2. **License Automation:** Android SDK components cannot be downloaded until licenses are accepted. Rather than relying on interactive prompts that break unattended scripts, Android APK Builder pre-populates official SHA1 hashes into `$ANDROID_HOME\licenses\android-sdk-license` and pipes automated confirmations.

---

### Step 5: Gradle Wrapper Bootstrapping
The Gradle Wrapper (`gradlew.bat` and `gradle-wrapper.jar`) ensures that builds execute with an exact, reproducible Gradle version. If a cloned repository is missing these wrapper files, Android APK Builder downloads the official standalone Gradle binary, generates the wrapper into the project, and purges the temporary installation files.

---

### Step 6: Debug vs. Release Compilation

| Attribute | `assembleDebug` | `assembleRelease` |
| :--- | :--- | :--- |
| **Command** | `setup-windows.bat -BuildType Debug` | `setup-windows.bat -BuildType Release` |
| **R8 Optimization** | Disabled (fast build) | **Full Mode Enabled** (tree-shaking, shrinking) |
| **Signing** | Signed with default Android debug key | Signed with release/debug key |
| **Use Case** | Fast local development and testing | Final optimized distribution APK |

---

## 6. Troubleshooting & Diagnostic Dictionary

### 1. "Running scripts is disabled on this system"
- **Cause:** Windows PowerShell ExecutionPolicy is set to `Restricted` by default.
- **Solution:** Use `setup-windows.bat`, which runs with `-ExecutionPolicy Bypass` automatically, or run:
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
  ```

### 2. `java.lang.OutOfMemoryError: Java heap space`
- **Cause:** Gradle exceeded physical memory limits.
- **Solution:** Force the Potato PC profile to constrain the daemon and limit workers:
  ```cmd
  setup-windows.bat -BuildType Release -ForceLowMem
  ```

### 3. `SDK location not found`
- **Cause:** Gradle cannot find the Android SDK path.
- **Solution:** Android APK Builder automatically generates `local.properties` with forward slashes (`sdk.dir=C:/Android`). If modifying manually, never use unescaped backslashes in properties files.


