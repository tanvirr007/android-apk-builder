# AGENTS.md — Repository Instructions for AI Agents

Welcome to **Android APK Builder** (`tanvirr007/android-apk-builder`). This document serves as the canonical orientation and operational guide for AI coding assistants, agents, and automation workflows operating within this repository.

---

## 1. Repository Purpose & Architecture

**Android APK Builder** is a standalone, headless Android build automation engine designed for Windows 10 and 11. It compiles modern Android applications (Kotlin, Java, Jetpack Compose) directly from Command Prompt and PowerShell without requiring Android Studio to be installed or running.

### Core Architecture

- **`setup-windows.ps1`** (~2,300+ lines): The core orchestration engine. Executes all inspection, compatibility resolution, hardware profiling, JDK/SDK bootstrapping, wrapper validation, compilation invocation, keystore generation, release signing, and artifact harvesting.
- **`build.bat`**: The 1-click Windows batch launcher. Automatically bypasses PowerShell `ExecutionPolicy` restrictions, handles interactive drag-and-drop or folder selection wizard mode, and transparently forwards CLI arguments to `setup-windows.ps1`.
- **`dist/`**: The local output harvest directory where generated APKs, AABs, signing keystores (`.jks`), and credential manifests are mirrored after compilation (ignored in `.gitignore`).
- **`README.md`**: Comprehensive technical documentation, architecture deep-dives, compatibility matrices, and troubleshooting guides.

---

## 2. Core Non-Negotiables & Design Principles

Any agent making changes or proposing updates to this codebase **must** adhere strictly to the following principles:

1. **Strict Session-Only Environment Scoping**:
   - Environment variables (`JAVA_HOME`, `PATH`, `GRADLE_OPTS`, `ANDROID_HOME`, `ANDROID_SDK_ROOT`, `ANDROID_USER_HOME`) must **NEVER** be written to the Windows User Registry or System Environment table permanently.
   - All environment variables must remain strictly scoped to the active PowerShell process (`$env:...`) to prevent polluting the host machine.
2. **Non-Destructive Project Operations**:
   - Never modify or destroy user project code, `build.gradle`, or `build.gradle.kts` files.
   - When modifying `local.properties` (e.g., setting `sdk.dir`), preserve all existing user comments and custom properties using regex replacement or safe appending.
   - Always **copy** build artifacts from project build directories into `dist/`. **Never move or delete** artifacts from Gradle's build folder, as this invalidates Gradle build caches.
3. **PowerShell 5.1 & Core Compatibility**:
   - Scripts must execute seamlessly on **Windows PowerShell 5.1 (Desktop Edition)** which ships by default on Windows 10/11, as well as **PowerShell 7+ (Core)**.
   - **Do NOT** use PowerShell 7-exclusive syntax (such as the ternary operator `? :` or the null-coalescing operator `??`) unless strictly protected with backward-compatible fallbacks. Standard `if/else` is preferred.
4. **Resilient Native Process Execution**:
   - Native binaries (e.g., `gradlew.bat`, `keytool.exe`, `apksigner.bat`, `sdkmanager.bat`) must be invoked through the internal `Invoke-NativeCommand` helper function.
   - This ensures stdout and stderr are captured cleanly, exit codes are accurately tracked, and PowerShell does not crash prematurely on standard stderr warnings.
5. **Hardware-Aware Memory Tuning**:
   - The engine profiles host RAM using WMI/CIM and applies dynamic JVM heap sizing and worker concurrency limits.
   - Retain low-memory safeguards (`-ForceLowMem`) so budget systems (<= 4 GB or 8 GB RAM) can build reliably without triggering Out-Of-Memory (OOM) or thrashing Windows pagefile.

---

## 3. Script Structure & Codebase Sections

When editing [setup-windows.ps1](file:///c:/Users/tanvir/Desktop/android-apk-builder/setup-windows.ps1), note its organized modular structure:

| Section / Stage | Purpose & Responsibilities |
| :--- | :--- |
| **Param Block** | Strongly-typed parameter declarations (`[CmdletBinding()]`), validation sets (`ValidateSet`), defaults, and switch flags. |
| **Section 1** | Logging and diagnostics formatting (`Write-Log`, `Write-Success`, `Write-Diagnostic`), and `Invoke-NativeCommand` execution wrapper. |
| **Section 2** | Project root discovery and configuration parsers: extracts `compileSdk`, `targetSdk`, AGP version, Gradle Daemon JVM criteria (`gradle-daemon-jvm.properties`), and module layout from Groovy, Kotlin DSL, and Version Catalogs (`libs.versions.toml`). |
| **Section 3** | Compatibility resolution engine: evaluates project AGP against Gradle and JDK compatibility matrices. |
| **Section 4** | Hardware profiling and memory tuning: dynamically calculates JVM heap ceilings and applies tailored `GRADLE_OPTS`. |
| **Section 5** | JDK discovery and selection: scans standard paths, Android Studio `jbr`, user and Gradle `.jdks` caches, and winget for matching JDK versions (8, 11, 17, 21) and vendor requirements. |
| **Section 6** | Android SDK management: localizes SDK, validates `cmdline-tools`, accepts official licenses, updates `local.properties`, and installs missing platform/build-tools. |
| **Section 7** | Gradle wrapper recovery: verifies `gradlew.bat` and `gradle-wrapper.jar`, restoring missing or corrupted wrappers dynamically if necessary. |
| **Section 8** | Artifact verification and signature inspection: extracts SHA-256 hashes, runs `apksigner verify` (v1, v2, v3, v4 schemes), and handles key generation. |
| **Pipeline (Stages 1-6)**| End-to-end build orchestration, task execution, artifact discovery, and output packaging to `dist/`. |

---

## 4. Key Developer & Agent Commands

### Syntax & Lint Validation
Always validate PowerShell syntax after modifying [setup-windows.ps1](file:///c:/Users/tanvir/Desktop/android-apk-builder/setup-windows.ps1):

```powershell
$tokens = $null; $errors = $null; [void][System.Management.Automation.Language.Parser]::ParseInput((Get-Content .\setup-windows.ps1 -Raw), [ref]$tokens, [ref]$errors); if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Error $_ }; exit 1 } else { Write-Host 'Syntax OK' -ForegroundColor Green }
```

### Dry Run Testing
Inspect and validate the resolution pipeline against any target Android project without compiling:

```cmd
build.bat -ProjectDir "C:\path\to\android-project" -DryRun -VerboseLog
```

### Build Variants & Artifact Types

```cmd
rem Build release APK (Default)
build.bat -ProjectDir "C:\path\to\android-project" -BuildType Release

rem Build debug APK
build.bat -ProjectDir "C:\path\to\android-project" -BuildType Debug

rem Build both debug and release variants
build.bat -ProjectDir "C:\path\to\android-project" -BuildType Both

rem Build Google Play App Bundle (.aab)
build.bat -ProjectDir "C:\path\to\android-project" -ArtifactType AAB

rem Build both APK and AAB
build.bat -ProjectDir "C:\path\to\android-project" -ArtifactType Both
```

### Keystore & Signing Options

```cmd
rem Auto-generate a dedicated release keystore and sign release builds
build.bat -ProjectDir "C:\path\to\android-project" -BuildType Release

rem Use an existing custom keystore
build.bat -ProjectDir "C:\path\to\android-project" -KeystorePath "C:\keys\my-release.jks" -StorePassword "secret123" -KeyAlias "myalias"

rem Skip release signing entirely
build.bat -ProjectDir "C:\path\to\android-project" -SkipSigning
```

### Memory & Performance Flags

```cmd
rem Low-memory profile for budget computers (<= 4GB / 8GB RAM)
build.bat -ProjectDir "C:\path\to\android-project" -ForceLowMem

rem High-performance profile for high-end workstations
build.bat -ProjectDir "C:\path\to\android-project" -HighMem
```