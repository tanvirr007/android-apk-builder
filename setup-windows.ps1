<#
.SYNOPSIS
    Android APK Builder - Universal Automated Android APK Compilation Engine for Windows
.DESCRIPTION
    A self-adapting, non-destructive automation system to inspect, resolve dependencies,
    and compile Android projects (Kotlin/Java with Gradle) directly on Microsoft Windows
    without requiring Android Studio.
.PARAMETER ProjectDir
    Target Android project root directory. Defaults to current working directory.
.PARAMETER BuildType
    Build variant type to assemble: "Release" (default), "Debug", or "Both".
.PARAMETER ArtifactType
    Artifact format to produce: "APK" (default), "AAB", or "Both".
.PARAMETER Module
    Specific application module to build (e.g., ":app" or "app"). Defaults to auto-detection.
.PARAMETER Variant
    Specific build variant name (e.g., "release", "freeRelease"). Defaults to auto-detection.
.PARAMETER OutputDir
    Destination directory for copied artifacts. Defaults to "dist".
.PARAMETER SdkPath
    Custom path to Android SDK.
.PARAMETER JdkPath
    Custom path to JDK.
.PARAMETER CompileSdkOverride
    Explicit compileSdk version to override project detection.
.PARAMETER BuildToolsOverride
    Explicit build-tools version to override auto-resolution.
.PARAMETER ForceLowMem
    Force low-memory profile for budget computers (<= 4GB/8GB RAM).
.PARAMETER HighMem
    Force high-performance profile.
.PARAMETER SkipSdkInstall
    Skip automatic downloading or updating of Android SDK components.
.PARAMETER SkipJdkInstall
    Skip automatic installation of JDK via winget if missing.
.PARAMETER AcceptLicenses
    Automatically accept official Android SDK licenses if unaccepted.
.PARAMETER CleanFirst
    Execute Gradle clean task prior to compilation.
.PARAMETER Offline
    Execute Gradle build in offline mode (--offline).
.PARAMETER DryRun
    Inspect and plan without executing the actual Gradle compilation.
.PARAMETER VerboseLog
    Enable verbose diagnostic logging.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ProjectDir = "",

    [ValidateSet("Release", "Debug", "Both")]
    [string]$BuildType = "Release",

    [ValidateSet("APK", "AAB", "Both")]
    [string]$ArtifactType = "APK",

    [string]$Module = "",
    [string]$Variant = "",
    [string]$OutputDir = "dist",
    [string]$SdkPath = "",
    [string]$JdkPath = "",
    [int]$CompileSdkOverride = 0,
    [string]$BuildToolsOverride = "",

    [switch]$ForceLowMem,
    [switch]$HighMem,
    [switch]$SkipSdkInstall,
    [switch]$SkipJdkInstall,
    [switch]$AcceptLicenses,
    [switch]$CleanFirst,
    [switch]$Offline,
    [switch]$DryRun,
    [switch]$VerboseLog
)

# Enforce strict parsing while retaining controlled native exit handling
$ErrorActionPreference = "Stop"

# Force TLS 1.2+ for reliable downloads on Windows PowerShell 5.1 & modern Core
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {
    # Nonfatal if platform already enforces higher or modern TLS
}

# Suppress slow progress rendering to improve download throughput
$ProgressPreference = 'SilentlyContinue'

# ==============================================================================
# SECTION 1: Logging, Diagnostics & Native Process Execution
# ==============================================================================

function Write-StageHeader([string]$Title) {
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "==================================================================" -ForegroundColor Cyan
}

function Write-Info([string]$Message) {
    Write-Host "  [i] $Message" -ForegroundColor Cyan
}

function Write-Success([string]$Message) {
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-WarningMsg([string]$Message) {
    Write-Host "  [WARN] $Message" -ForegroundColor Yellow
}

function Write-FailureMsg([string]$Message) {
    Write-Host "  [ERROR] $Message" -ForegroundColor Red
}

function Write-Dim([string]$Message) {
    Write-Host "      $Message" -ForegroundColor DarkGray
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,

        [Parameter(Mandatory = $false)]
        [string[]]$ArgumentList = @(),

        [Parameter(Mandatory = $false)]
        [string]$WorkingDirectory = "",

        [Parameter(Mandatory = $false)]
        [switch]$CaptureOutput,

        [Parameter(Mandatory = $false)]
        [string]$StdInput = "",

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 0,

        [Parameter(Mandatory = $false)]
        [switch]$IgnoreExitCode
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Executable
    $startInfo.Arguments = ($ArgumentList | ForEach-Object {
        if ($_ -match '[\s"]') {
            "`"$($_ -replace '"', '\"')`""
        } else {
            $_
        }
    }) -join " "

    if (-not [string]::IsNullOrEmpty($WorkingDirectory)) {
        $startInfo.WorkingDirectory = $WorkingDirectory
    }
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $CaptureOutput.IsPresent

    if ($CaptureOutput.IsPresent) {
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
    }
    if (-not [string]::IsNullOrEmpty($StdInput)) {
        $startInfo.RedirectStandardInput = $true
    }

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $startInfo

    try {
        $started = $proc.Start()
        if (-not $started) {
            throw "Failed to start process: $Executable"
        }

        if (-not [string]::IsNullOrEmpty($StdInput)) {
            $writer = $proc.StandardInput
            $writer.Write($StdInput)
            $writer.Flush()
            $writer.Close()
        }

        $stdout = ""
        $stderr = ""
        if ($CaptureOutput.IsPresent) {
            $stdout = $proc.StandardOutput.ReadToEnd()
            $stderr = $proc.StandardError.ReadToEnd()
        }

        if ($TimeoutSeconds -gt 0) {
            $exited = $proc.WaitForExit($TimeoutSeconds * 1000)
            if (-not $exited) {
                try { $proc.Kill() } catch {}
                throw "Command timed out after $TimeoutSeconds seconds: $Executable"
            }
        } else {
            $proc.WaitForExit()
        }

        $exitCode = $proc.ExitCode
        $global:LASTEXITCODE = $exitCode

        if ($exitCode -ne 0 -and -not $IgnoreExitCode) {
            $msg = "Native command failed with exit code ${exitCode}: $Executable $($startInfo.Arguments)"
            if (-not [string]::IsNullOrEmpty($stderr)) {
                $msg += "`nStderr: $stderr"
            }
            Write-FailureMsg $msg
        }

        return [PSCustomObject]@{
            ExitCode = $exitCode
            StdOut   = $stdout
            StdErr   = $stderr
            Success  = ($exitCode -eq 0)
        }
    } finally {
        $proc.Dispose()
    }
}

# ==============================================================================
# SECTION 2: Project Root & Configuration Parsers
# ==============================================================================

function Parse-VersionCatalogToml([string]$TomlPath) {
    $result = @{
        Versions = @{}
        Plugins  = @{}
    }
    if (-not (Test-Path $TomlPath)) {
        return $result
    }

    $currentSection = ""
    $lines = Get-Content $TomlPath -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
            continue
        }
        if ($trimmed -match '^\[([a-zA-Z0-9_\-\.]+)\]$') {
            $currentSection = $matches[1].ToLowerInvariant()
            continue
        }

        if ($currentSection -eq "versions") {
            if ($trimmed -match '^([a-zA-Z0-9_\-\.]+)\s*=\s*["'']([^"'']+)["'']') {
                $result.Versions[$matches[1]] = $matches[2]
            }
        } elseif ($currentSection -eq "plugins") {
            $pluginKey = ""
            $pluginId = ""
            $pluginVersion = ""
            $versionRef = ""

            if ($trimmed -match '^([a-zA-Z0-9_\-\.]+)\s*=\s*\{([^}]+)\}') {
                $pluginKey = $matches[1]
                $body = $matches[2]
                if ($body -match 'id\s*=\s*["'']([^"'']+)["'']') { $pluginId = $matches[1] }
                if ($body -match 'version\.ref\s*=\s*["'']([^"'']+)["'']') { $versionRef = $matches[1] }
                if ($body -match 'version\s*=\s*["'']([^"'']+)["'']') { $pluginVersion = $matches[1] }
            } elseif ($trimmed -match '^([a-zA-Z0-9_\-\.]+)\s*=\s*["'']([^"'']+)["'']') {
                $pluginKey = $matches[1]
                $pluginId = $matches[2]
            }

            if ($pluginKey) {
                $result.Plugins[$pluginKey] = @{
                    Id         = $pluginId
                    Version    = $pluginVersion
                    VersionRef = $versionRef
                }
            }
        }
    }
    return $result
}

function Discover-ProjectModules([string]$RootDir) {
    $modules = @()
    $settingsFiles = @(
        (Join-Path $RootDir "settings.gradle.kts"),
        (Join-Path $RootDir "settings.gradle")
    )

    $foundSettings = $null
    foreach ($sf in $settingsFiles) {
        if (Test-Path $sf) {
            $foundSettings = $sf
            break
        }
    }

    if ($foundSettings) {
        $content = Get-Content $foundSettings -Raw -ErrorAction SilentlyContinue
        # Match Groovy / Kotlin DSL include statements: include(":app"), include ':app', ':core'
        $regex = 'include\s*\(?\s*([^)\r\n]+)\)?'
        $matchesList = [regex]::Matches($content, $regex)
        foreach ($m in $matchesList) {
            $argsStr = $m.Groups[1].Value
            $subTokens = [regex]::Matches($argsStr, '["'']([^"'']+)["'']')
            foreach ($st in $subTokens) {
                $rawMod = $st.Groups[1].Value.Trim()
                if (-not [string]::IsNullOrEmpty($rawMod)) {
                    $modules += $rawMod
                }
            }
        }
    }

    # Normalize modules: ensure unique entries
    $uniqueModules = @($modules | Select-Object -Unique)
    if ($uniqueModules.Count -eq 0) {
        # Check standard default folders
        if (Test-Path (Join-Path $RootDir "app")) {
            $uniqueModules = @(":app")
        } elseif (Test-Path (Join-Path $RootDir "build.gradle")) {
            $uniqueModules = @(":")
        } elseif (Test-Path (Join-Path $RootDir "build.gradle.kts")) {
            $uniqueModules = @(":")
        }
    }

    return $uniqueModules
}

function Inspect-GradleModule([string]$RootDir, [string]$ModulePath, [hashtable]$Catalog) {
    $relDir = $ModulePath.TrimStart(':').Replace(':', [System.IO.Path]::DirectorySeparatorChar)
    $moduleDir = if ([string]::IsNullOrEmpty($relDir)) { $RootDir } else { Join-Path $RootDir $relDir }

    $buildKts = Join-Path $moduleDir "build.gradle.kts"
    $buildGroovy = Join-Path $moduleDir "build.gradle"

    $buildFile = if (Test-Path $buildKts) { $buildKts } elseif (Test-Path $buildGroovy) { $buildGroovy } else { $null }

    $info = @{
        ModulePath          = $ModulePath
        ModuleDir           = $moduleDir
        BuildFile           = $buildFile
        IsApplication       = $false
        IsLibrary           = $false
        CompileSdk          = 0
        CompileSdkRaw       = ""
        TargetSdk           = 0
        MinSdk              = 0
        BuildToolsVersion   = ""
        AgpVersion          = ""
        KotlinVersion       = ""
        JavaToolchain       = 0
        SourceCompatibility = 0
        HasReleaseSigning   = $false
        SigningConfigName   = ""
        Flavors             = @()
        Namespace           = ""
    }

    if (-not $buildFile) {
        return $info
    }

    $content = Get-Content $buildFile -Raw -ErrorAction SilentlyContinue

    # Check Plugin Application
    if ($content -match 'com\.android\.application' -or
        $content -match 'alias\s*\(\s*libs\.plugins\.android\.application\s*\)' -or
        $content -match 'apply\s+plugin:\s*["'']com\.android\.application["'']' -or
        $content -match 'apply\s+plugin:\s*["'']android["'']') {
        $info.IsApplication = $true
    } elseif ($content -match 'com\.android\.library' -or
              $content -match 'alias\s*\(\s*libs\.plugins\.android\.library\s*\)' -or
              $content -match 'apply\s+plugin:\s*["'']com\.android\.library["'']') {
        $info.IsLibrary = $true
    }

    # AGP version in build file
    if ($content -match 'com\.android\.tools\.build:gradle:([0-9\.]+)') {
        $info.AgpVersion = $matches[1]
    } elseif ($content -match 'id\s*\(?["'']com\.android\.application["'']\)?\s*version\s*["'']([^"'']+)["'']') {
        $info.AgpVersion = $matches[1]
    }

    # compileSdk / compileSdkVersion
    if ($content -match 'compileSdk\s*=?\s*(\d+)') {
        $info.CompileSdk = [int]$matches[1]
        $info.CompileSdkRaw = $matches[1]
    } elseif ($content -match 'compileSdk\.set\((\d+)\)') {
        $info.CompileSdk = [int]$matches[1]
        $info.CompileSdkRaw = $matches[1]
    } elseif ($content -match 'compileSdkVersion\s*=?\s*(\d+)') {
        $info.CompileSdk = [int]$matches[1]
        $info.CompileSdkRaw = $matches[1]
    } elseif ($content -match 'compileSdk\s*=\s*libs\.versions\.([a-zA-Z0-9_\-\.]+)') {
        $verKey = $matches[1]
        $info.CompileSdkRaw = "libs.versions.$verKey"
        if ($Catalog.Versions.ContainsKey($verKey)) {
            $parsed = 0
            if ([int]::TryParse($Catalog.Versions[$verKey], [ref]$parsed)) {
                $info.CompileSdk = $parsed
            }
        }
    }

    # targetSdk / targetSdkVersion
    if ($content -match 'targetSdk\s*=?\s*(\d+)') {
        $info.TargetSdk = [int]$matches[1]
    } elseif ($content -match 'targetSdkVersion\s*=?\s*(\d+)') {
        $info.TargetSdk = [int]$matches[1]
    }

    # minSdk / minSdkVersion
    if ($content -match 'minSdk\s*=?\s*(\d+)') {
        $info.MinSdk = [int]$matches[1]
    } elseif ($content -match 'minSdkVersion\s*=?\s*(\d+)') {
        $info.MinSdk = [int]$matches[1]
    }

    # buildToolsVersion
    if ($content -match 'buildToolsVersion\s*=?\s*["'']([^"'']+)["'']') {
        $info.BuildToolsVersion = $matches[1]
    }

    # Java Toolchain
    if ($content -match 'jvmToolchain\s*\(?\s*(\d+)\s*\)?') {
        $info.JavaToolchain = [int]$matches[1]
    } elseif ($content -match 'JavaVersion\.VERSION_(\d+)') {
        $info.SourceCompatibility = [int]$matches[1]
    } elseif ($content -match 'jvmTarget\s*=\s*["''](\d+)["'']') {
        $info.SourceCompatibility = [int]$matches[1]
    }

    # Signing Configs
    if ($content -match 'buildTypes\s*\{[^}]*release\s*\{[^}]*signingConfig\s*=\s*signingConfigs\.([a-zA-Z0-9_]+)') {
        $info.HasReleaseSigning = $true
        $info.SigningConfigName = $matches[1]
    } elseif ($content -match 'buildTypes\s*\{[^}]*release\s*\{[^}]*signingConfig\s*=\s*signingConfigs\.getByName\s*\(["'']([^"'']+)["'']\)') {
        $info.HasReleaseSigning = $true
        $info.SigningConfigName = $matches[1]
    }

    # Namespace
    if ($content -match 'namespace\s*=?\s*["'']([^"'']+)["'']') {
        $info.Namespace = $matches[1]
    }

    return $info
}

function Inspect-AndroidProject([string]$RootDir) {
    if (-not (Test-Path $RootDir)) {
        throw "Target project directory does not exist: $RootDir"
    }

    $catalogPath = Join-Path $RootDir "gradle\libs.versions.toml"
    $catalog = Parse-VersionCatalogToml $catalogPath

    $detectedAgp = ""
    $detectedKotlin = ""
    if ($catalog.Versions.ContainsKey("agp")) {
        $detectedAgp = $catalog.Versions["agp"]
    } elseif ($catalog.Versions.ContainsKey("androidGradlePlugin")) {
        $detectedAgp = $catalog.Versions["androidGradlePlugin"]
    }
    if ($catalog.Versions.ContainsKey("kotlin")) {
        $detectedKotlin = $catalog.Versions["kotlin"]
    }

    # Check root build file for AGP / Kotlin classpath or plugin definitions
    $rootKts = Join-Path $RootDir "build.gradle.kts"
    $rootGroovy = Join-Path $RootDir "build.gradle"
    $rootBuildFile = if (Test-Path $rootKts) { $rootKts } elseif (Test-Path $rootGroovy) { $rootGroovy } else { $null }

    if ($rootBuildFile) {
        $rootContent = Get-Content $rootBuildFile -Raw -ErrorAction SilentlyContinue
        if (-not $detectedAgp -and $rootContent -match 'com\.android\.tools\.build:gradle:([0-9\.]+)') {
            $detectedAgp = $matches[1]
        }
        if (-not $detectedAgp -and $rootContent -match 'id\s*\(?["'']com\.android\.application["'']\)?\s*version\s*["'']([^"'']+)["'']') {
            $detectedAgp = $matches[1]
        }
        if (-not $detectedKotlin -and $rootContent -match 'org\.jetbrains\.kotlin:kotlin-gradle-plugin:([0-9\.]+)') {
            $detectedKotlin = $matches[1]
        }
    }

    # Gradle Wrapper properties
    $wrapperPropPath = Join-Path $RootDir "gradle\wrapper\gradle-wrapper.properties"
    $wrapperGradleVersion = ""
    $wrapperDistributionUrl = ""
    if (Test-Path $wrapperPropPath) {
        $wLines = Get-Content $wrapperPropPath -ErrorAction SilentlyContinue
        foreach ($wl in $wLines) {
            if ($wl -match 'distributionUrl\s*=\s*(.+)$') {
                $wrapperDistributionUrl = $matches[1].Replace('\:', ':')
                if ($wrapperDistributionUrl -match 'gradle-([0-9\.]+)-(bin|all)\.zip') {
                    $wrapperGradleVersion = $matches[1]
                }
            }
        }
    }

    $moduleNames = Discover-ProjectModules $RootDir
    $modulesInfo = @()
    foreach ($m in $moduleNames) {
        $modInfo = Inspect-GradleModule $RootDir $m $catalog
        $modulesInfo += $modInfo
    }

    # Identify candidate application modules
    $appModules = @($modulesInfo | Where-Object { $_.IsApplication })
    if ($appModules.Count -eq 0 -and $modulesInfo.Count -gt 0) {
        # Check if root or :app exists even if plugin wasn't statically matched
        $appCandidate = $modulesInfo | Where-Object { $_.ModulePath -eq ":app" -or $_.ModulePath -eq ":" } | Select-Object -First 1
        if ($appCandidate) {
            $appModules = @($appCandidate)
        }
    }

    return @{
        RootDir                 = $RootDir
        Catalog                 = $catalog
        AgpVersion              = $detectedAgp
        KotlinVersion           = $detectedKotlin
        WrapperGradleVersion    = $wrapperGradleVersion
        WrapperDistributionUrl  = $wrapperDistributionUrl
        HasWrapperProperties    = (Test-Path $wrapperPropPath)
        HasWrapperBat           = (Test-Path (Join-Path $RootDir "gradlew.bat"))
        HasWrapperJar           = (Test-Path (Join-Path $RootDir "gradle\wrapper\gradle-wrapper.jar"))
        AllModules              = $modulesInfo
        ApplicationModules      = $appModules
    }
}

# ==============================================================================
# SECTION 3: Compatibility Resolution Engine
# ==============================================================================

function Resolve-AgpGradleJavaCompatibility([string]$AgpVersion, [string]$GradleVersion) {
    # Official AGP -> Minimum Gradle & JDK requirements
    # AGP 8.8+ : Gradle 8.10.2 - 8.13+, JDK 17 - 21
    # AGP 8.4 - 8.7: Gradle 8.6 - 8.11+, JDK 17 - 21
    # AGP 8.0 - 8.3: Gradle 8.0 - 8.4, JDK 17+
    # AGP 7.4 : Gradle 7.5 - 7.6, JDK 11 - 19
    # AGP 7.0 - 7.3: Gradle 7.0 - 7.4, JDK 11 - 17
    # AGP 4.0 - 4.2: Gradle 6.1.1 - 6.9, JDK 8 or 11

    $agpMajor = 8
    $agpMinor = 8
    if ($AgpVersion -match '^(\d+)\.(\d+)') {
        $agpMajor = [int]$matches[1]
        $agpMinor = [int]$matches[2]
    }

    $minJdk = 17
    $maxJdk = 21
    $targetGradle = "8.11.1"

    if ($agpMajor -ge 8) {
        $minJdk = 17
        $maxJdk = 21
        if ($agpMinor -ge 8) {
            $targetGradle = "8.11.1"
        } elseif ($agpMinor -ge 4) {
            $targetGradle = "8.7"
        } else {
            $targetGradle = "8.2"
        }
    } elseif ($agpMajor -eq 7) {
        $minJdk = 11
        $maxJdk = 17
        if ($agpMinor -ge 4) {
            $targetGradle = "7.6"
            $maxJdk = 19
        } else {
            $targetGradle = "7.4.2"
            $maxJdk = 17
        }
    } elseif ($agpMajor -le 4) {
        $minJdk = 8
        $maxJdk = 11
        $targetGradle = "6.9"
    }

    # Adjust constraints based on existing Gradle wrapper version if established
    if ($GradleVersion -match '^(\d+)\.(\d+)') {
        $gMajor = [int]$matches[1]
        $gMinor = [int]$matches[2]
        if ($gMajor -lt 7) {
            $maxJdk = [math]::Min($maxJdk, 11)
        } elseif ($gMajor -eq 7) {
            $maxJdk = [math]::Min($maxJdk, 17)
        } elseif ($gMajor -eq 8 -and $gMinor -lt 5) {
            # Gradle < 8.5 does not fully support running under Java 21 daemon
            $maxJdk = [math]::Min($maxJdk, 20)
        }
    }

    return @{
        MinJdk       = $minJdk
        MaxJdk       = $maxJdk
        TargetGradle = $targetGradle
    }
}

function Resolve-BuildToolsVersion([int]$CompileSdk, [string]$ExplicitBuildTools) {
    if (-not [string]::IsNullOrEmpty($ExplicitBuildTools)) {
        return $ExplicitBuildTools
    }

    # Standard default build-tools mapping per compileSdk level
    switch ($CompileSdk) {
        36 { return "36.0.0" }
        35 { return "35.0.0" }
        34 { return "34.0.0" }
        33 { return "33.0.2" }
        32 { return "32.0.0" }
        31 { return "31.0.0" }
        30 { return "30.0.3" }
        29 { return "29.0.3" }
        28 { return "28.0.3" }
        default {
            if ($CompileSdk -gt 36) {
                return "$CompileSdk.0.0"
            } elseif ($CompileSdk -gt 0) {
                return "$CompileSdk.0.0"
            } else {
                return "34.0.0"
            }
        }
    }
}

# ==============================================================================
# SECTION 4: Hardware Profiling & Constrained-Memory Tuning
# ==============================================================================

function Get-HostMemoryProfile([switch]$ForceLow, [switch]$ForceHigh) {
    $totalRamGb = 8.0
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os -and $os.TotalVisibleMemorySize) {
            $totalRamGb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        } else {
            $mem = (Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | Measure-Object -Property Capacity -Sum).Sum
            if ($mem) {
                $totalRamGb = [math]::Round($mem / 1GB, 1)
            }
        }
    } catch {
        # Fallback to standard 8 GB estimate
    }

    $isLowMem = ($totalRamGb -le 8.5) -or $ForceLow.IsPresent
    if ($ForceHigh.IsPresent) {
        $isLowMem = $false
    }

    if ($isLowMem) {
        $heapMb = if ($totalRamGb -le 4.5) { 1024 } else { 1536 }
        $metaMb = if ($totalRamGb -le 4.5) { 384 } else { 512 }
        $workers = if ($totalRamGb -le 4.5) { 1 } else { 2 }

        return @{
            ProfileName   = "Low-Memory / Potato PC ($totalRamGb GB RAM)"
            TotalRamGb    = $totalRamGb
            IsLowMem      = $true
            GradleOpts    = "-Xmx${heapMb}m -XX:MaxMetaspaceSize=${metaMb}m -XX:+UseParallelGC"
            ExtraArgs     = @("--no-daemon", "--max-workers=$workers")
        }
    } else {
        return @{
            ProfileName   = "High-Performance Workstation ($totalRamGb GB RAM)"
            TotalRamGb    = $totalRamGb
            IsLowMem      = $false
            GradleOpts    = "-Xmx4096m -XX:MaxMetaspaceSize=1024m"
            ExtraArgs     = @("--parallel", "--build-cache")
        }
    }
}

# ==============================================================================
# SECTION 5: JDK Discovery, Validation & Selection
# ==============================================================================

function Query-JdkVersion([string]$JdkHome) {
    $javaExe = Join-Path $JdkHome "bin\java.exe"
    $javacExe = Join-Path $JdkHome "bin\javac.exe"

    if (-not (Test-Path $javaExe) -or -not (Test-Path $javacExe)) {
        return $null
    }

    $res = Invoke-NativeCommand -Executable $javaExe -ArgumentList @("-version") -CaptureOutput -IgnoreExitCode
    $combinedOut = "$($res.StdOut)`n$($res.StdErr)"

    # Example outputs:
    # openjdk version "17.0.10" 2024-01-16
    # java version "21.0.2" 2024-01-16 LTS
    # java version "1.8.0_351"
    $major = 0
    $rawVersion = ""

    if ($combinedOut -match 'version\s*["'']1\.(\d+)') {
        $major = [int]$matches[1]
        $rawVersion = "1.$major"
    } elseif ($combinedOut -match 'version\s*["''](\d+)(?:\.([0-9\.]+))?') {
        $major = [int]$matches[1]
        $rawVersion = $matches[0]
    }

    $is64Bit = $combinedOut -match '64-Bit' -or (Test-Path (Join-Path $JdkHome "lib\modules"))

    if ($major -gt 0) {
        return [PSCustomObject]@{
            Path         = $JdkHome
            MajorVersion = $major
            RawVersion   = $rawVersion
            Is64Bit      = $is64Bit
        }
    }
    return $null
}

function Find-InstalledJdks([string]$CustomJdk = "") {
    $candidates = @()

    if (-not [string]::IsNullOrEmpty($CustomJdk) -and (Test-Path $CustomJdk)) {
        $candidates += $CustomJdk
    }

    if ($env:JAVA_HOME -and (Test-Path $env:JAVA_HOME)) {
        $candidates += $env:JAVA_HOME
    }

    $searchRoots = @(
        "C:\Program Files\Eclipse Adoptium\*",
        "C:\Program Files\Microsoft\*",
        "C:\Program Files\Java\*",
        "C:\Program Files\BellSoft\*",
        "C:\Program Files\Amazon Corretto\*",
        "C:\Program Files\Zulu\*",
        "C:\Program Files\Android\Android Studio\jbr",
        "C:\Program Files\Android\Android Studio\jre"
    )

    if ($env:USERPROFILE) {
        $searchRoots += "$env:USERPROFILE\.jdks\*"
    }

    foreach ($pat in $searchRoots) {
        $matched = Get-Item -Path $pat -ErrorAction SilentlyContinue
        foreach ($m in $matched) {
            if ($m.PSIsContainer) {
                $candidates += $m.FullName
            }
        }
    }

    # Query Windows Registry for standard JDK registrations
    $regKeys = @(
        "HKLM:\SOFTWARE\JavaSoft\JDK",
        "HKLM:\SOFTWARE\Eclipse Adoptium\JDK",
        "HKLM:\SOFTWARE\AdoptOpenJDK\JDK",
        "HKLM:\SOFTWARE\Microsoft\JDK"
    )
    foreach ($rk in $regKeys) {
        if (Test-Path $rk) {
            $subKeys = Get-ChildItem -Path $rk -ErrorAction SilentlyContinue
            foreach ($sk in $subKeys) {
                $javaVal = (Get-ItemProperty -Path $sk.PSPath -Name "JavaHome" -ErrorAction SilentlyContinue).JavaHome
                if ($javaVal -and (Test-Path $javaVal)) {
                    $candidates += $javaVal
                }
            }
        }
    }

    $verifiedJdks = @()
    $seenPaths = @{}

    foreach ($cand in $candidates) {
        $normPath = $cand.TrimEnd('\')
        if (-not $seenPaths.ContainsKey($normPath.ToLowerInvariant())) {
            $seenPaths[$normPath.ToLowerInvariant()] = $true
            $details = Query-JdkVersion $normPath
            if ($details) {
                $verifiedJdks += $details
            }
        }
    }

    return $verifiedJdks
}

function Select-CompatibleJdk([array]$InstalledJdks, [int]$MinJdk, [int]$MaxJdk, [int]$PreferredJdk) {
    if ($InstalledJdks.Count -eq 0) {
        return $null
    }

    # First attempt: match preferred JDK major version exactly
    if ($PreferredJdk -gt 0) {
        $prefMatch = $InstalledJdks | Where-Object { $_.MajorVersion -eq $PreferredJdk -and $_.Is64Bit } | Select-Object -First 1
        if ($prefMatch) { return $prefMatch }
    }

    # Second attempt: filter within [MinJdk, MaxJdk]
    $compatible = @($InstalledJdks | Where-Object {
        $_.MajorVersion -ge $MinJdk -and $_.MajorVersion -le $MaxJdk -and $_.Is64Bit
    })

    if ($compatible.Count -gt 0) {
        # Prefer LTS versions: 17, then 21, then highest
        $match17 = $compatible | Where-Object { $_.MajorVersion -eq 17 } | Select-Object -First 1
        if ($match17) { return $match17 }

        $match21 = $compatible | Where-Object { $_.MajorVersion -eq 21 } | Select-Object -First 1
        if ($match21) { return $match21 }

        return ($compatible | Sort-Object MajorVersion -Descending | Select-Object -First 1)
    }

    return $null
}

# ==============================================================================
# SECTION 6: Android SDK & local.properties Management
# ==============================================================================

function Find-AndroidSdkRoot([string]$ExplicitPath, [string]$ProjectDir) {
    if (-not [string]::IsNullOrEmpty($ExplicitPath) -and (Test-Path $ExplicitPath)) {
        return $ExplicitPath
    }

    # Inspect project's existing local.properties sdk.dir
    $localProps = Join-Path $ProjectDir "local.properties"
    if (Test-Path $localProps) {
        $lines = Get-Content $localProps -ErrorAction SilentlyContinue
        foreach ($l in $lines) {
            if ($l -match '^\s*sdk\.dir\s*=\s*(.+)$') {
                $rawSdk = $matches[1].Trim().Replace('\\', '\').Replace('\:', ':')
                if (Test-Path $rawSdk) {
                    return $rawSdk
                }
            }
        }
    }

    # Check environment variables
    if ($env:ANDROID_HOME -and (Test-Path $env:ANDROID_HOME)) {
        return $env:ANDROID_HOME
    }
    if ($env:ANDROID_SDK_ROOT -and (Test-Path $env:ANDROID_SDK_ROOT)) {
        return $env:ANDROID_SDK_ROOT
    }

    # Standard per-user AppData location (preferred non-admin path)
    if ($env:LOCALAPPDATA) {
        $userSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
        if (Test-Path $userSdk) {
            return $userSdk
        }
    }

    # Common Windows system locations
    $standardLocations = @(
        "C:\Android\Sdk",
        "C:\Android",
        "C:\Program Files (x86)\Android\android-sdk",
        "C:\Program Files\Android\android-sdk"
    )
    foreach ($loc in $standardLocations) {
        if (Test-Path $loc) {
            return $loc
        }
    }

    # Check Registry
    $regStudio = "HKCU:\Software\Android Studio"
    if (Test-Path $regStudio) {
        $p = (Get-ItemProperty -Path $regStudio -Name "SdkPath" -ErrorAction SilentlyContinue).SdkPath
        if ($p -and (Test-Path $p)) {
            return $p
        }
    }

    # Fallback to user-writable AppData folder
    if ($env:LOCALAPPDATA) {
        $targetUserSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
        return $targetUserSdk
    }

    return "C:\Android"
}

function Update-LocalProperties([string]$ProjectDir, [string]$AndroidHome) {
    $localPropsPath = Join-Path $ProjectDir "local.properties"
    $formattedSdk = $AndroidHome.Replace('\', '/')

    if (-not (Test-Path $localPropsPath)) {
        Set-Content -Path $localPropsPath -Value "sdk.dir=$formattedSdk" -Encoding UTF8
        Write-Success "Created local.properties: sdk.dir=$formattedSdk"
        return
    }

    # Read existing lines and preserve all other properties
    $lines = Get-Content $localPropsPath -ErrorAction Stop
    $sdkUpdated = $false
    $newLines = @()

    foreach ($line in $lines) {
        if ($line -match '^\s*sdk\.dir\s*=') {
            $newLines += "sdk.dir=$formattedSdk"
            $sdkUpdated = $true
        } else {
            $newLines += $line
        }
    }

    if (-not $sdkUpdated) {
        $newLines += "sdk.dir=$formattedSdk"
    }

    # Create backup before writing
    $bakPath = "$localPropsPath.bak"
    Copy-Item -Path $localPropsPath -Destination $bakPath -Force

    Set-Content -Path $localPropsPath -Value $newLines -Encoding UTF8
    Write-Success "Updated local.properties without altering other configuration."
}

function Ensure-AndroidCmdlineTools([string]$AndroidHome) {
    $sdkManager = Join-Path $AndroidHome "cmdline-tools\latest\bin\sdkmanager.bat"
    if (Test-Path $sdkManager) {
        return $sdkManager
    }

    # Check for misnested cmdline-tools (e.g. cmdline-tools\bin\sdkmanager.bat)
    $looseSdkManager = Join-Path $AndroidHome "cmdline-tools\bin\sdkmanager.bat"
    if (Test-Path $looseSdkManager) {
        Write-Info "Restructuring unnested cmdline-tools into cmdline-tools\latest..."
        $tempRename = Join-Path $AndroidHome "cmdline-tools-tmp"
        $cmdlineDir = Join-Path $AndroidHome "cmdline-tools"
        Move-Item -Path $cmdlineDir -Destination $tempRename -Force
        New-Item -ItemType Directory -Path $cmdlineDir -Force | Out-Null
        Move-Item -Path $tempRename -Destination (Join-Path $cmdlineDir "latest") -Force
        if (Test-Path $sdkManager) {
            return $sdkManager
        }
    }

    # Acquire official commandline tools from Google repository
    Write-Info "Android cmdline-tools missing. Downloading official package from Google..."
    $downloadUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
    $tempZip = Join-Path $env:TEMP "cmdline-tools-$([System.Guid]::NewGuid().ToString('N')).zip"
    $tempExtract = Join-Path $env:TEMP "cmdline-extracted-$([System.Guid]::NewGuid().ToString('N'))"

    try {
        $attempts = 0
        $maxAttempts = 3
        $downloaded = $false

        while ($attempts -lt $maxAttempts -and -not $downloaded) {
            $attempts++
            try {
                Write-Dim "Downloading tools archive (Attempt $attempts of $maxAttempts)..."
                Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing -TimeoutSec 120
                if ((Test-Path $tempZip) -and (Get-Item $tempZip).Length -gt 10000000) {
                    $downloaded = $true
                }
            } catch {
                if ($attempts -ge $maxAttempts) { throw }
                Start-Sleep -Seconds 3
            }
        }

        Write-Dim "Extracting command-line tools..."
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

        $targetLatest = Join-Path $AndroidHome "cmdline-tools\latest"
        $parentCmdline = Join-Path $AndroidHome "cmdline-tools"
        New-Item -ItemType Directory -Path $parentCmdline -Force | Out-Null

        if (Test-Path $targetLatest) {
            Remove-Item -Path $targetLatest -Recurse -Force -ErrorAction SilentlyContinue
        }

        $extractedRoot = Join-Path $tempExtract "cmdline-tools"
        Move-Item -Path $extractedRoot -Destination $targetLatest -Force
        Write-Success "Android cmdline-tools successfully installed."
    } finally {
        if (Test-Path $tempZip) { Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tempExtract) { Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
    }

    if (-not (Test-Path $sdkManager)) {
        throw "Failed to install or verify sdkmanager.bat at: $sdkManager"
    }

    return $sdkManager
}

function Ensure-SdkLicenses([string]$AndroidHome, [string]$SdkManagerBat, [switch]$AutoAccept) {
    $licenseDir = Join-Path $AndroidHome "licenses"
    $mainLicense = Join-Path $licenseDir "android-sdk-license"

    if (Test-Path $mainLicense) {
        Write-Success "Android SDK licenses previously accepted."
        return $true
    }

    if ($AutoAccept.IsPresent) {
        Write-Info "Executing official license agreement..."
        # Feed 50 'y' responses safely via cmd to avoid Windows PowerShell pipeline deadlocks
        $yesLines = (1..50 | ForEach-Object { "y" }) -join "`r`n"
        $res = Invoke-NativeCommand -Executable "cmd.exe" -ArgumentList @("/c", "`"$SdkManagerBat`" --licenses") -StdInput $yesLines -CaptureOutput -IgnoreExitCode
        if (Test-Path $mainLicense) {
            Write-Success "Android SDK licenses accepted."
            return $true
        }
    }

    Write-WarningMsg "Android SDK licenses are not yet accepted."
    Write-WarningMsg "Run with -AcceptLicenses or execute: $SdkManagerBat --licenses"
    return (Test-Path $mainLicense)
}

# ==============================================================================
# SECTION 7: Gradle Wrapper Bootstrapping & Recovery
# ==============================================================================

function Ensure-ProjectGradleWrapper([string]$ProjectDir, [string]$TargetGradleVersion, [string]$JavaHome) {
    $gradlewBat = Join-Path $ProjectDir "gradlew.bat"
    $wrapperJar = Join-Path $ProjectDir "gradle\wrapper\gradle-wrapper.jar"
    $wrapperProps = Join-Path $ProjectDir "gradle\wrapper\gradle-wrapper.properties"

    $wrapperIntact = (Test-Path $gradlewBat) -and (Test-Path $wrapperJar) -and (Test-Path $wrapperProps)
    if ($wrapperIntact) {
        # Verify wrapper jar size (must not be zero bytes from empty git checkout)
        if ((Get-Item $wrapperJar).Length -gt 10000) {
            return $gradlewBat
        }
    }

    Write-WarningMsg "Project Gradle Wrapper missing or incomplete."
    Write-Info "Bootstrapping official Gradle $TargetGradleVersion distribution..."

    $tempDir = Join-Path $env:TEMP "gradle-boot-$([System.Guid]::NewGuid().ToString('N'))"
    $zipPath = Join-Path $tempDir "gradle-$TargetGradleVersion-bin.zip"
    $extractPath = Join-Path $tempDir "extracted"

    try {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        $downloadUrl = "https://services.gradle.org/distributions/gradle-$TargetGradleVersion-bin.zip"

        Write-Dim "Downloading Gradle $TargetGradleVersion ($downloadUrl)..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing -TimeoutSec 180

        Write-Dim "Extracting Gradle standalone binary..."
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        $tempGradleBat = (Get-ChildItem -Path $extractPath -Filter "gradle.bat" -Recurse | Select-Object -First 1).FullName
        if (-not $tempGradleBat) {
            throw "Failed to locate gradle.bat in extracted distribution."
        }

        Write-Dim "Generating Gradle wrapper inside project root..."
        $genRes = Invoke-NativeCommand -Executable $tempGradleBat -ArgumentList @("wrapper", "--gradle-version", $TargetGradleVersion) -WorkingDirectory $ProjectDir -CaptureOutput

        if (-not (Test-Path $gradlewBat) -or -not (Test-Path $wrapperJar)) {
            throw "Gradle wrapper generation failed: $($genRes.StdErr)"
        }

        Write-Success "Gradle wrapper $TargetGradleVersion successfully bootstrapped."
        return $gradlewBat
    } finally {
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ==============================================================================
# SECTION 8: Artifact Verification & Signature Inspection
# ==============================================================================

function Verify-ApkSignature([string]$ApkPath, [string]$AndroidHome, [string]$BuildToolsVersion) {
    $result = @{
        IsSigned    = $false
        SignerScheme= "Unsigned"
        SignerName  = "None"
        Verified    = $false
        RawOutput   = ""
    }

    $apksigner = Join-Path $AndroidHome "build-tools\$BuildToolsVersion\apksigner.bat"
    if (-not (Test-Path $apksigner)) {
        # Look for any installed build-tools containing apksigner
        $apksigners = Get-ChildItem -Path (Join-Path $AndroidHome "build-tools") -Filter "apksigner.bat" -Recurse -ErrorAction SilentlyContinue
        if ($apksigners) {
            $apksigner = ($apksigners | Select-Object -First 1).FullName
        }
    }

    if (Test-Path $apksigner) {
        $check = Invoke-NativeCommand -Executable $apksigner -ArgumentList @("verify", "--verbose", "`"$ApkPath`"") -CaptureOutput -IgnoreExitCode
        $result.RawOutput = "$($check.StdOut)`n$($check.StdErr)"
        if ($check.ExitCode -eq 0) {
            $result.IsSigned = $true
            $result.Verified = $true

            $schemes = @()
            if ($result.RawOutput -match 'Verified using v1 scheme \(JAR signing\): true') { $schemes += "v1" }
            if ($result.RawOutput -match 'Verified using v2 scheme \(APK Signature Scheme v2\): true') { $schemes += "v2" }
            if ($result.RawOutput -match 'Verified using v3 scheme \(APK Signature Scheme v3\): true') { $schemes += "v3" }
            if ($result.RawOutput -match 'Verified using v4 scheme \(APK Signature Scheme v4\): true') { $schemes += "v4" }

            if ($schemes.Count -gt 0) {
                $result.SignerScheme = $schemes -join ", "
            } else {
                $result.SignerScheme = "Signed"
            }

            if ($result.RawOutput -match 'CN=Android Debug') {
                $result.SignerName = "Android Debug Certificate"
            } else {
                $result.SignerName = "Release Certificate"
            }
        }
    }

    return $result
}

function Get-FileSha256([string]$FilePath) {
    try {
        $hasher = [System.Security.Cryptography.SHA256]::Create()
        $stream = [System.IO.File]::OpenRead($FilePath)
        $bytes = $hasher.ComputeHash($stream)
        $stream.Close()
        return [System.BitConverter]::ToString($bytes).Replace("-", "").ToLowerInvariant()
    } catch {
        return "N/A"
    }
}

# ==============================================================================
# MAIN EXECUTION ORCHESTRATION PIPELINE
# ==============================================================================

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Android APK Builder - Universal Build Automation System        " -ForegroundColor Cyan
Write-Host '  Engineered for Robustness, Non-Destructive Operation & Portability' -ForegroundColor DarkCyan
Write-Host "==================================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# STAGE 1: Project Root Inspection & Compatibility Discovery
# ------------------------------------------------------------------------------
Write-StageHeader '[Stage 1/6] Inspecting Target Android Project'

$targetRoot = if ([string]::IsNullOrWhiteSpace($ProjectDir)) { (Get-Location).Path } else { $ProjectDir }
$targetRoot = (Resolve-Path $targetRoot).Path

Write-Info "Project Root: $targetRoot"

$projectSpec = Inspect-AndroidProject $targetRoot

# Determine Application Module
$selectedAppModule = $null
if (-not [string]::IsNullOrEmpty($Module)) {
    $normMod = if ($Module.StartsWith(":")) { $Module } else { ":$Module" }
    $selectedAppModule = $projectSpec.AllModules | Where-Object { $_.ModulePath -eq $normMod } | Select-Object -First 1
    if (-not $selectedAppModule) {
        Write-WarningMsg "Specified module '$Module' was not found in project. Falling back to auto-detection."
    }
}

if (-not $selectedAppModule) {
    if ($projectSpec.ApplicationModules.Count -eq 1) {
        $selectedAppModule = $projectSpec.ApplicationModules[0]
    } elseif ($projectSpec.ApplicationModules.Count -gt 1) {
        $appCandidate = $projectSpec.ApplicationModules | Where-Object { $_.ModulePath -eq ":app" } | Select-Object -First 1
        $selectedAppModule = if ($appCandidate) { $appCandidate } else { $projectSpec.ApplicationModules[0] }
        Write-Info "Discovered multiple application modules: $(($projectSpec.ApplicationModules | ForEach-Object { $_.ModulePath }) -join ', ')"
    } else {
        # Check root or fallback
        $selectedAppModule = $projectSpec.AllModules | Select-Object -First 1
    }
}

if (-not $selectedAppModule) {
    Write-FailureMsg "No Android modules could be detected in: $targetRoot"
    exit 1
}

Write-Success "Target Application Module: $($selectedAppModule.ModulePath)"

# Resolve compileSdk
$effectiveCompileSdk = if ($CompileSdkOverride -gt 0) { $CompileSdkOverride } elseif ($selectedAppModule.CompileSdk -gt 0) { $selectedAppModule.CompileSdk } else { 34 }
Write-Success "Target compileSdk: $effectiveCompileSdk $(if ($CompileSdkOverride -gt 0) { '(Overridden by user)' } else { '' })"

# Resolve AGP, Gradle and JDK Compatibility
$compatibility = Resolve-AgpGradleJavaCompatibility $projectSpec.AgpVersion $projectSpec.WrapperGradleVersion
$effectiveBuildTools = Resolve-BuildToolsVersion $effectiveCompileSdk $selectedAppModule.BuildToolsVersion
if (-not [string]::IsNullOrEmpty($BuildToolsOverride)) {
    $effectiveBuildTools = $BuildToolsOverride
}

Write-Info "Android Gradle Plugin (AGP): $(if ($projectSpec.AgpVersion) { $projectSpec.AgpVersion } else { 'Auto (8.8+ assumed)' })"
Write-Info "Gradle Wrapper Version: $(if ($projectSpec.WrapperGradleVersion) { $projectSpec.WrapperGradleVersion } else { 'Missing (Target: ' + $compatibility.TargetGradle + ')' })"
Write-Info "Compatible JDK Range: Java $($compatibility.MinJdk) - Java $($compatibility.MaxJdk)"
Write-Info "Target build-tools: $effectiveBuildTools"

# ------------------------------------------------------------------------------
# STAGE 2: Memory Architecture & Hardware Profiling
# ------------------------------------------------------------------------------
Write-StageHeader '[Stage 2/6] Host Memory Profiling & Low-RAM Optimization'

$memProfile = Get-HostMemoryProfile -ForceLow:$ForceLowMem -ForceHigh:$HighMem
Write-Success "Memory Profile: $($memProfile.ProfileName)"
Write-Dim "Scoped GRADLE_OPTS: $($memProfile.GradleOpts)"
Write-Dim ('Daemon & Worker Flags: {0}' -f ($memProfile.ExtraArgs -join ' '))

# Apply GRADLE_OPTS strictly to current process session without polluting Windows User Registry
$env:GRADLE_OPTS = $memProfile.GradleOpts

# ------------------------------------------------------------------------------
# STAGE 3: Java Development Kit (JDK) Selection & Validation
# ------------------------------------------------------------------------------
Write-StageHeader '[Stage 3/6] Java Development Kit (JDK) Resolution'

$installedJdks = Find-InstalledJdks $JdkPath
Write-Info "Discovered $( $installedJdks.Count ) verified JDK installations on host."

foreach ($j in $installedJdks) {
    Write-Dim ('Found JDK {0} (64-bit: {1}) at: {2}' -f $j.MajorVersion, $j.Is64Bit, $j.Path)
}

$preferredVersion = if ($selectedAppModule.JavaToolchain -gt 0) { $selectedAppModule.JavaToolchain } elseif ($selectedAppModule.SourceCompatibility -gt 0) { $selectedAppModule.SourceCompatibility } else { 17 }

$selectedJdk = Select-CompatibleJdk $installedJdks $compatibility.MinJdk $compatibility.MaxJdk $preferredVersion

if (-not $selectedJdk -and -not $SkipJdkInstall) {
    Write-WarningMsg "No compatible JDK ($($compatibility.MinJdk)-$($compatibility.MaxJdk)) located on host."
    $winget = Get-Command "winget" -ErrorAction SilentlyContinue
    if ($winget) {
        $pkgId = if ($compatibility.MinJdk -ge 21) { "EclipseAdoptium.Temurin.21.JDK" } elseif ($compatibility.MinJdk -le 11 -and $compatibility.MaxJdk -le 11) { "EclipseAdoptium.Temurin.11.JDK" } else { "EclipseAdoptium.Temurin.17.JDK" }
        Write-Info "Attempting automated installation of $pkgId via winget..."
        $wRes = Invoke-NativeCommand -Executable "winget" -ArgumentList @("install", $pkgId, "--accept-source-agreements", "--accept-package-agreements", "--silent") -IgnoreExitCode
        if ($wRes.Success) {
            $installedJdks = Find-InstalledJdks
            $selectedJdk = Select-CompatibleJdk $installedJdks $compatibility.MinJdk $compatibility.MaxJdk $preferredVersion
        }
    }
}

if (-not $selectedJdk) {
    Write-FailureMsg "Compatible JDK ($($compatibility.MinJdk)-$($compatibility.MaxJdk)) could not be located or installed."
    Write-Host "  Please install OpenJDK $($compatibility.MinJdk) from: https://adoptium.net/temurin/releases/" -ForegroundColor Yellow
    exit 1
}

Write-Success ('Selected Active JDK: Java {0} ({1})' -f $selectedJdk.MajorVersion, $selectedJdk.Path)

# Scope JAVA_HOME and PATH strictly to current PowerShell process
$env:JAVA_HOME = $selectedJdk.Path
if ($env:Path -notlike ("*" + $selectedJdk.Path + "\bin*")) {
    $env:Path = $selectedJdk.Path + "\bin;" + $env:Path
}

# ------------------------------------------------------------------------------
# STAGE 4: Android SDK, Platform Tools & Licenses
# ------------------------------------------------------------------------------
Write-StageHeader '[Stage 4/6] Android SDK, Command-Line Tools & Platform Setup'

$androidSdkRoot = Find-AndroidSdkRoot $SdkPath $targetRoot
Write-Success "Android SDK Location: $androidSdkRoot"

# Non-destructively sync local.properties
Update-LocalProperties $targetRoot $androidSdkRoot

$env:ANDROID_HOME = $androidSdkRoot
$env:ANDROID_SDK_ROOT = $androidSdkRoot

$sdkManagerBat = Ensure-AndroidCmdlineTools $androidSdkRoot

# Licenses check
$licensesOk = Ensure-SdkLicenses $androidSdkRoot $sdkManagerBat -AutoAccept:$AcceptLicenses
if (-not $licensesOk -and -not $AcceptLicenses) {
    Write-WarningMsg "SDK licenses are not confirmed. Build may fail if requested packages are missing."
}

# Install missing SDK platform and build-tools
if (-not $SkipSdkInstall) {
    $platformPkg = "platforms;android-$effectiveCompileSdk"
    $buildToolsPkg = "build-tools;$effectiveBuildTools"
    $platformToolsPkg = "platform-tools"

    $hasPlatform = Test-Path (Join-Path $androidSdkRoot "platforms\android-$effectiveCompileSdk")
    $hasBuildTools = Test-Path (Join-Path $androidSdkRoot "build-tools\$effectiveBuildTools")

    if (-not $hasPlatform -or -not $hasBuildTools) {
        Write-Info "Installing missing Android SDK components: $platformPkg $buildToolsPkg..."
        $installRes = Invoke-NativeCommand -Executable $sdkManagerBat -ArgumentList @($platformToolsPkg, $platformPkg, $buildToolsPkg) -IgnoreExitCode
        if (-not $installRes.Success) {
            Write-WarningMsg "sdkmanager reported non-zero code while installing packages. Continuing build check..."
        } else {
            Write-Success "Android SDK platform components installed and verified."
        }
    } else {
        Write-Success "Required Android platform ($effectiveCompileSdk) and build-tools ($effectiveBuildTools) already present."
    }
}

# ------------------------------------------------------------------------------
# STAGE 5: Gradle Wrapper Verification & Recovery
# ------------------------------------------------------------------------------
Write-StageHeader '[Stage 5/6] Gradle Wrapper Verification'

$gradlewBat = Ensure-ProjectGradleWrapper $targetRoot $compatibility.TargetGradle $selectedJdk.Path
Write-Success "Verified Gradle executable: $gradlewBat"

# ------------------------------------------------------------------------------
# STAGE 6: Compilation, Artifact Discovery & Verification
# ------------------------------------------------------------------------------
Write-StageHeader '[Stage 6/6] Executing Android Compilation & Artifact Harvesting'

if ($DryRun.IsPresent) {
    Write-Success "Dry-run mode activated. Inspection and tool resolution succeeded."
    exit 0
}

# Assemble Gradle tasks
$tasksToRun = @()
if ($CleanFirst.IsPresent) {
    $tasksToRun += "clean"
}

$modulePrefix = if ($selectedAppModule.ModulePath -eq ":") { "" } else { "$($selectedAppModule.ModulePath):" }

switch ($BuildType) {
    "Debug" {
        if ($ArtifactType -eq "AAB") {
            $tasksToRun += "${modulePrefix}bundleDebug"
        } elseif ($ArtifactType -eq "Both") {
            $tasksToRun += @("${modulePrefix}assembleDebug", "${modulePrefix}bundleDebug")
        } else {
            $tasksToRun += "${modulePrefix}assembleDebug"
        }
    }
    "Release" {
        if ($ArtifactType -eq "AAB") {
            $tasksToRun += "${modulePrefix}bundleRelease"
        } elseif ($ArtifactType -eq "Both") {
            $tasksToRun += @("${modulePrefix}assembleRelease", "${modulePrefix}bundleRelease")
        } else {
            $tasksToRun += "${modulePrefix}assembleRelease"
        }
    }
    "Both" {
        $tasksToRun += @("${modulePrefix}assembleDebug", "${modulePrefix}assembleRelease")
        if ($ArtifactType -eq "AAB" -or $ArtifactType -eq "Both") {
            $tasksToRun += @("${modulePrefix}bundleDebug", "${modulePrefix}bundleRelease")
        }
    }
}

$gradleArgs = @() + $tasksToRun + $memProfile.ExtraArgs
if ($Offline.IsPresent) {
    $gradleArgs += "--offline"
}

Write-Info "Executing Gradle build command: .\gradlew.bat $($gradleArgs -join ' ')"
$buildStartTime = Get-Date

# Execute build
$buildResult = Invoke-NativeCommand -Executable $gradlewBat -ArgumentList $gradleArgs -WorkingDirectory $targetRoot -IgnoreExitCode

if (-not $buildResult.Success) {
    Write-Host ""
    Write-FailureMsg "Gradle build failed with exit code $($buildResult.ExitCode)."
    if ($BuildType -eq "Release" -and -not $selectedAppModule.HasReleaseSigning) {
        Write-WarningMsg "DIAGNOSTIC: This project does not appear to have release signing configured."
        Write-WarningMsg "Many open-source projects fail assembleRelease unless signing credentials are provided."
        Write-WarningMsg "Remedy: Try building with: setup-windows.bat -BuildType Debug"
    }
    exit $buildResult.ExitCode
}

Write-Success "Gradle task execution completed successfully."

# Discover freshly produced artifacts
$outputBaseDir = Join-Path $targetRoot $OutputDir
if (-not (Test-Path $outputBaseDir)) {
    New-Item -ItemType Directory -Path $outputBaseDir -Force | Out-Null
}

$rawArtifacts = Get-ChildItem -Path $targetRoot -Include "*.apk", "*.aab" -Recurse -ErrorAction SilentlyContinue | Where-Object {
    $_.FullName -notmatch '[\\/]intermediates[\\/]' -and
    $_.FullName -notmatch '[\\/]tmp[\\/]' -and
    ($_.FullName -match '[\\/]outputs[\\/]apk[\\/]' -or $_.FullName -match '[\\/]outputs[\\/]bundle[\\/]') -and
    $_.LastWriteTime -ge $buildStartTime.AddSeconds(-5)
}

# Fallback: if time resolution on filesystem is coarse, take artifacts modified within last 10 minutes
if (-not $rawArtifacts) {
    $rawArtifacts = Get-ChildItem -Path $targetRoot -Include "*.apk", "*.aab" -Recurse -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch '[\\/]intermediates[\\/]' -and
        $_.FullName -notmatch '[\\/]tmp[\\/]' -and
        ($_.FullName -match '[\\/]outputs[\\/]apk[\\/]' -or $_.FullName -match '[\\/]outputs[\\/]bundle[\\/]') -and
        $_.LastWriteTime -ge $buildStartTime.AddMinutes(-10)
    }
}

if (-not $rawArtifacts) {
    Write-WarningMsg "No freshly generated APK or AAB artifacts were detected in build outputs."
    exit 1
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  BUILD SUCCESSFUL - HARVESTED ARTIFACTS                         " -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green

$copiedCount = 0
foreach ($art in $rawArtifacts) {
    $destFile = Join-Path $outputBaseDir $art.Name
    # Prevent collision across modules/flavors
    if (Test-Path $destFile) {
        $modTag = $selectedAppModule.ModulePath.Trim(':').Replace(':', '_')
        if ($modTag -and $art.Name -notmatch "^$modTag") {
            $destFile = Join-Path $outputBaseDir "$modTag-$($art.Name)"
        }
    }

    Copy-Item -Path $art.FullName -Destination $destFile -Force
    $sizeMb = [math]::Round((Get-Item $destFile).Length / 1MB, 2)
    $sha256 = Get-FileSha256 $destFile

    Write-Host "  File:     $destFile" -ForegroundColor Cyan
    Write-Host "  Size:     $sizeMb MB" -ForegroundColor DarkCyan
    Write-Host "  SHA-256:  $sha256" -ForegroundColor DarkGray

    if ($destFile.EndsWith(".apk")) {
        $sigInfo = Verify-ApkSignature $destFile $androidSdkRoot $effectiveBuildTools
        if ($sigInfo.IsSigned) {
            Write-Host "  Signing:  Verified ($($sigInfo.SignerScheme) - $($sigInfo.SignerName))" -ForegroundColor Green
        } else {
            Write-Host "  Signing:  UNSIGNED (Requires signing key before device install)" -ForegroundColor Yellow
        }
    }
    Write-Host "------------------------------------------------------------------" -ForegroundColor DarkGray
    $copiedCount++
}

Write-Success "Harvested $copiedCount artifact(s) into: $outputBaseDir"
Write-Host ""
exit 0
