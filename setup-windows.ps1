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
.PARAMETER Interactive
    Launch interactive build wizard to choose target project path, build variant, artifact type, and hardware options.
.PARAMETER KeystorePath
    Optional path to an existing custom .jks or .keystore file.
.PARAMETER StorePassword
    Keystore password. Defaults to "android" if auto-generated.
.PARAMETER KeyAlias
    Key alias name. Defaults to "release" if auto-generated.
.PARAMETER KeyPassword
    Key password. Defaults to StorePassword if omitted.
.PARAMETER KeyDName
    Distinguished Name (DName) for release keystore certificate generation (e.g. "CN=MyName,O=MyOrg,C=US").
.PARAMETER SkipSigning
    Bypass automatic release keystore generation and APK signing.
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

    [string]$KeystorePath = "",
    [string]$StorePassword = "",
    [string]$KeyAlias = "",
    [string]$KeyPassword = "",
    [string]$KeyDName = "",
    [switch]$SkipSigning,

    [switch]$ForceLowMem,
    [switch]$HighMem,
    [switch]$SkipSdkInstall,
    [switch]$SkipJdkInstall,
    [switch]$AcceptLicenses,
    [switch]$CleanFirst,
    [switch]$Offline,
    [switch]$DryRun,
    [switch]$VerboseLog,
    [switch]$Interactive
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

function Exit-WithCode([int]$Code) {
    if ($global:IsInteractiveSession) {
        Write-Host ""
        Write-Host "Press Enter to exit..." -ForegroundColor Cyan
        try {
            [void][System.Console]::ReadLine()
        } catch {
            # In non-interactive host fallback
        }
    }
    exit $Code
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

function Test-IsAndroidProject([string]$Dir) {
    if ([string]::IsNullOrWhiteSpace($Dir) -or -not (Test-Path $Dir)) {
        return $false
    }
    if ((Test-Path (Join-Path $Dir "settings.gradle")) -or
        (Test-Path (Join-Path $Dir "settings.gradle.kts")) -or
        (Test-Path (Join-Path $Dir "build.gradle")) -or
        (Test-Path (Join-Path $Dir "build.gradle.kts"))) {
        return $true
    }
    return $false
}

function Invoke-InteractiveBuildWizard {
    param(
        [ref]$TargetRootRef,
        [ref]$BuildTypeRef,
        [ref]$ArtifactTypeRef,
        [ref]$CleanFirstRef,
        [ref]$ForceLowMemRef,
        [ref]$KeystorePathRef,
        [ref]$StorePasswordRef,
        [ref]$KeyAliasRef,
        [ref]$KeyPasswordRef,
        [ref]$KeyDNameRef,
        [ref]$SkipSigningRef
    )

    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "  Android APK Builder - Interactive Build Wizard                 " -ForegroundColor Cyan
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host ""

    $currentLoc = (Get-Location).Path
    $resolvedPath = ""

    # If TargetRoot was already passed (e.g. drag & drop or CLI) and valid, show it
    if (-not [string]::IsNullOrWhiteSpace($TargetRootRef.Value) -and (Test-Path $TargetRootRef.Value)) {
        $resolvedPath = (Resolve-Path $TargetRootRef.Value).Path
        Write-Host "  Target Project: $resolvedPath" -ForegroundColor Green
    } else {
        $isCurrentAndroid = Test-IsAndroidProject $currentLoc
        while ($true) {
            if ($isCurrentAndroid) {
                Write-Host "  Detected Android project in current directory:" -ForegroundColor Gray
                Write-Host "  $currentLoc" -ForegroundColor DarkCyan
                $inputPath = Read-Host "  Press Enter to build this project, or enter/drag a project path"
                if ([string]::IsNullOrWhiteSpace($inputPath)) {
                    $resolvedPath = $currentLoc
                    break
                }
            } else {
                Write-Host "  Enter target Android project directory (or drag and drop folder here):" -ForegroundColor Yellow
                $inputPath = Read-Host "  Project Path"
            }

            # Strip surrounding quotes and whitespace
            $cleaned = $inputPath.Trim().Trim('"', "'")
            if ([string]::IsNullOrWhiteSpace($cleaned)) {
                Write-Host "  [!] Project path cannot be empty. Please enter a valid path.`n" -ForegroundColor Red
                continue
            }

            if (-not (Test-Path $cleaned)) {
                Write-Host "  [!] Directory does not exist: $cleaned`n" -ForegroundColor Red
                continue
            }

            $fullPath = (Resolve-Path $cleaned).Path
            if (-not (Test-IsAndroidProject $fullPath)) {
                Write-Host "  [WARN] No build.gradle or settings.gradle found in: $fullPath" -ForegroundColor Yellow
                $confirm = Read-Host "  Are you sure this is an Android project? (y/N)"
                if ($confirm -match '^(y|yes)$') {
                    $resolvedPath = $fullPath
                    break
                } else {
                    Write-Host ""
                    continue
                }
            } else {
                $resolvedPath = $fullPath
                break
            }
        }
    }

    $TargetRootRef.Value = $resolvedPath
    Write-Host "  [OK] Selected project root: $resolvedPath`n" -ForegroundColor Green

    # Build Mode: Smart Defaults
    Write-Host "  ------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  Build Mode:" -ForegroundColor Cyan
    Write-Host "    [Enter] Build Release APK (Recommended default)" -ForegroundColor White
    Write-Host "    [C]     Customize options (Debug, AAB, Clean, Low-RAM, Signing)" -ForegroundColor White
    $modeChoice = Read-Host "  Selection [Enter]"

    if ($modeChoice -and $modeChoice.Trim() -match '^(c|customize)$') {
        Write-Host ""
        # 1. Build Type
        Write-Host "  Build Type:" -ForegroundColor Cyan
        Write-Host "    1) Release [Default - press Enter]"
        Write-Host "    2) Debug"
        Write-Host "    3) Both (Release & Debug)"
        $bt = Read-Host "  Selection [1]"
        switch ($bt.Trim()) {
            "2" { $BuildTypeRef.Value = "Debug" }
            "3" { $BuildTypeRef.Value = "Both" }
            default { $BuildTypeRef.Value = "Release" }
        }

        # 2. Artifact Format
        Write-Host ""
        Write-Host "  Artifact Format:" -ForegroundColor Cyan
        Write-Host "    1) APK [Default - press Enter]"
        Write-Host "    2) AAB (Android App Bundle)"
        Write-Host "    3) Both (APK & AAB)"
        $af = Read-Host "  Selection [1]"
        switch ($af.Trim()) {
            "2" { $ArtifactTypeRef.Value = "AAB" }
            "3" { $ArtifactTypeRef.Value = "Both" }
            default { $ArtifactTypeRef.Value = "APK" }
        }

        # 3. Clean Build
        Write-Host ""
        $cl = Read-Host "  Clean project before compilation? [y/N - press Enter for No]"
        if ($cl -match '^(y|yes)$') {
            $CleanFirstRef.Value = [switch]$true
        }

        # 4. Low-RAM profile
        Write-Host ""
        $lr = Read-Host "  Enable Low-RAM mode (Potato PC / <= 8GB RAM)? [y/N - press Enter for No]"
        if ($lr -match '^(y|yes)$') {
            $ForceLowMemRef.Value = [switch]$true
        }

        # 5. Release Signing Key Configuration
        Write-Host ""
        Write-Host "  Release Signing Key:" -ForegroundColor Cyan
        Write-Host "    1) Auto-manage / Reuse builder keystore [Default - press Enter]"
        Write-Host "    2) Custom keystore or custom credentials"
        Write-Host "    3) Skip signing (Produce unsigned release APK)"
        $signChoice = Read-Host "  Selection [1]"
        switch ($signChoice.Trim()) {
            "2" {
                Write-Host ""
                $customKs = Read-Host "  Path to existing .jks/.keystore file (leave blank to generate new with custom credentials)"
                $customKs = $customKs.Trim().Trim('"', "'")
                if (-not [string]::IsNullOrWhiteSpace($customKs)) {
                    $KeystorePathRef.Value = $customKs
                }
                $customAlias = Read-Host "  Key Alias [Default: release - press Enter]"
                if (-not [string]::IsNullOrWhiteSpace($customAlias)) {
                    $KeyAliasRef.Value = $customAlias.Trim()
                }
                while ($true) {
                    $customPass = Read-Host "  Keystore Password (min 6 characters) [Default: android - press Enter]"
                    if ([string]::IsNullOrWhiteSpace($customPass)) {
                        break
                    }
                    if ($customPass.Trim().Length -lt 6) {
                        Write-Host "  [!] Password must be at least 6 characters long for Java keystores.`n" -ForegroundColor Red
                        continue
                    }
                    $StorePasswordRef.Value = $customPass.Trim()
                    $KeyPasswordRef.Value = $customPass.Trim()
                    break
                }
                while ($true) {
                    $customKeyPass = Read-Host "  Key Password [Default: same as keystore password - press Enter]"
                    if ([string]::IsNullOrWhiteSpace($customKeyPass)) {
                        break
                    }
                    if ($customKeyPass.Trim().Length -lt 6) {
                        Write-Host "  [!] Key password must be at least 6 characters long for Java keystores.`n" -ForegroundColor Red
                        continue
                    }
                    $KeyPasswordRef.Value = $customKeyPass.Trim()
                    break
                }

                # If generating a new keystore, offer certificate identity customization (DName)
                if ([string]::IsNullOrWhiteSpace($customKs)) {
                    Write-Host ""
                    Write-Host "  Certificate Details (Developer & Organization Identity):" -ForegroundColor Cyan
                    Write-Host "    1) Auto-generate standard defaults [Default - press Enter]"
                    Write-Host "    2) Enter custom certificate details (Name, Org, Country, etc.)"
                    $certChoice = Read-Host "  Selection [1]"
                    if ($certChoice.Trim() -eq "2") {
                        Write-Host ""
                        $defaultCertName = if ($resolvedPath) { Split-Path $resolvedPath -Leaf } else { "Release" }
                        $cn = Read-Host "    Developer / App Name (CN) [Default: $defaultCertName]"
                        $ou = Read-Host "    Organizational Unit (OU) [Default: AndroidAPKBuilder]"
                        $o  = Read-Host "    Organization / Company (O) [Default: LocalBuild]"
                        $l  = Read-Host "    City / Locality (L) [Default: Local]"
                        $st = Read-Host "    State / Province (ST) [Default: Local]"
                        $c  = Read-Host "    Country Code (2 letters, e.g. US, BD, GB) [Default: US]"

                        $cnVal = if (-not [string]::IsNullOrWhiteSpace($cn)) { $cn.Trim() } else { $defaultCertName }
                        $ouVal = if (-not [string]::IsNullOrWhiteSpace($ou)) { $ou.Trim() } else { "AndroidAPKBuilder" }
                        $oVal  = if (-not [string]::IsNullOrWhiteSpace($o))  { $o.Trim() }  else { "LocalBuild" }
                        $lVal  = if (-not [string]::IsNullOrWhiteSpace($l))  { $l.Trim() }  else { "Local" }
                        $stVal = if (-not [string]::IsNullOrWhiteSpace($st)) { $st.Trim() } else { "Local" }
                        $cVal  = if (-not [string]::IsNullOrWhiteSpace($c))  { $c.Trim().ToUpper() } else { "US" }

                        $cnVal = $cnVal -replace ',', ' '
                        $ouVal = $ouVal -replace ',', ' '
                        $oVal  = $oVal  -replace ',', ' '
                        $lVal  = $lVal  -replace ',', ' '
                        $stVal = $stVal -replace ',', ' '
                        $cVal  = if ($cVal.Length -gt 2) { $cVal.Substring(0, 2) } else { $cVal }

                        $KeyDNameRef.Value = "CN=$cnVal,OU=$ouVal,O=$oVal,L=$lVal,ST=$stVal,C=$cVal"
                    }
                }
            }
            "3" {
                $SkipSigningRef.Value = [switch]$true
            }
            default {
                # Standard auto-managed builder keystore
            }
        }
    } else {
        Write-Host "  Using standard defaults: Release APK with Auto-Signing." -ForegroundColor DarkCyan
    }

    Write-Host ""
}

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
    } elseif ($content -match 'JavaLanguageVersion\.of\s*\(\s*(\d+)\s*\)') {
        $info.JavaToolchain = [int]$matches[1]
    } elseif ($content -match 'JavaVersion\.VERSION_(\d+)') {
        $info.SourceCompatibility = [int]$matches[1]
    } elseif ($content -match 'jvmTarget\s*=\s*["''](\d+)["'']') {
        $info.SourceCompatibility = [int]$matches[1]
    } elseif ($content -match 'JavaVersion\.toVersion\s*\(\s*libs\.versions\.([a-zA-Z0-9_\-\.]+)') {
        $vKey = $matches[1]
        if ($Catalog.Versions.ContainsKey($vKey)) {
            $parsed = 0
            if ([int]::TryParse($Catalog.Versions[$vKey], [ref]$parsed)) {
                $info.SourceCompatibility = $parsed
            }
        }
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

    # Gradle Daemon JVM criteria (Gradle 8.8+)
    $daemonJvmPropPath = Join-Path $RootDir "gradle\gradle-daemon-jvm.properties"
    $daemonJvmVersion = 0
    $daemonJvmVendor = ""
    if (Test-Path $daemonJvmPropPath) {
        $djLines = Get-Content $daemonJvmPropPath -ErrorAction SilentlyContinue
        foreach ($djl in $djLines) {
            if ($djl -match '^\s*toolchainVersion\s*=\s*(\d+)') {
                $daemonJvmVersion = [int]$matches[1]
            } elseif ($djl -match '^\s*toolchainVendor\s*=\s*([a-zA-Z0-9_\-\.]+)') {
                $daemonJvmVendor = $matches[1].Trim().ToUpperInvariant()
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
        DaemonJvmVersion        = $daemonJvmVersion
        DaemonJvmVendor         = $daemonJvmVendor
        HasDaemonJvmProperties  = (Test-Path $daemonJvmPropPath)
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

    $vendor = ""
    $releaseFile = Join-Path $JdkHome "release"
    if (Test-Path $releaseFile) {
        $relLines = Get-Content $releaseFile -ErrorAction SilentlyContinue
        foreach ($rl in $relLines) {
            if ($rl -match '^\s*IMPLEMENTOR\s*=\s*["'']?([^"''\r\n]+)["'']?') {
                $vendor = $matches[1].Trim()
                break
            }
        }
    }
    if (-not $vendor) {
        if ($JdkHome -match '(?i)Android Studio\\jb[re]|JetBrains') {
            $vendor = "JetBrains"
        } elseif ($JdkHome -match '(?i)Adoptium|Temurin') {
            $vendor = "Eclipse Adoptium"
        } elseif ($JdkHome -match '(?i)Microsoft') {
            $vendor = "Microsoft"
        } elseif ($JdkHome -match '(?i)Zulu') {
            $vendor = "Azul"
        } elseif ($JdkHome -match '(?i)Corretto') {
            $vendor = "Amazon"
        }
    }

    if ($major -gt 0) {
        return [PSCustomObject]@{
            Path         = $JdkHome
            MajorVersion = $major
            RawVersion   = $rawVersion
            Is64Bit      = $is64Bit
            Vendor       = $vendor
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
        $searchRoots += "$env:USERPROFILE\.gradle\jdks\*"
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

function Select-CompatibleJdk([array]$InstalledJdks, [int]$MinJdk, [int]$MaxJdk, [int]$PreferredJdk, [string]$PreferredVendor = "") {
    if ($InstalledJdks.Count -eq 0) {
        return $null
    }

    # First attempt: match preferred JDK major version (and vendor if specified)
    if ($PreferredJdk -gt 0) {
        if (-not [string]::IsNullOrEmpty($PreferredVendor)) {
            $prefVendorMatch = $InstalledJdks | Where-Object {
                $_.MajorVersion -eq $PreferredJdk -and $_.Is64Bit -and (
                    ($_.Vendor -and $_.Vendor.ToUpperInvariant().Contains($PreferredVendor.ToUpperInvariant())) -or
                    ($_.Path.ToUpperInvariant().Contains($PreferredVendor.ToUpperInvariant()))
                )
            } | Select-Object -First 1
            if ($prefVendorMatch) { return $prefVendorMatch }
        }

        $prefMatch = $InstalledJdks | Where-Object { $_.MajorVersion -eq $PreferredJdk -and $_.Is64Bit } | Select-Object -First 1
        if ($prefMatch) { return $prefMatch }
    }

    # Second attempt: filter within [MinJdk, MaxJdk]
    $compatible = @($InstalledJdks | Where-Object {
        $_.MajorVersion -ge $MinJdk -and $_.MajorVersion -le $MaxJdk -and $_.Is64Bit
    })

    if ($compatible.Count -gt 0) {
        if (-not [string]::IsNullOrEmpty($PreferredVendor)) {
            $vendorMatch = $compatible | Where-Object {
                ($_.Vendor -and $_.Vendor.ToUpperInvariant().Contains($PreferredVendor.ToUpperInvariant())) -or
                ($_.Path.ToUpperInvariant().Contains($PreferredVendor.ToUpperInvariant()))
            } | Select-Object -First 1
            if ($vendorMatch) { return $vendorMatch }
        }

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
        $check = Invoke-NativeCommand -Executable $apksigner -ArgumentList @("verify", "--verbose", $ApkPath) -CaptureOutput -IgnoreExitCode
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

function Get-ProjectSafeName([string]$ProjectDir) {
    # Prioritize actual project directory name on disk
    $name = (Split-Path (Resolve-Path $ProjectDir).Path -Leaf)

    # Fallback to settings.gradle rootProject.name if directory name cannot be determined
    if ([string]::IsNullOrWhiteSpace($name)) {
        $settingsFiles = @(
            (Join-Path $ProjectDir "settings.gradle"),
            (Join-Path $ProjectDir "settings.gradle.kts")
        )
        foreach ($sf in $settingsFiles) {
            if (Test-Path $sf) {
                $content = Get-Content $sf -Raw -ErrorAction SilentlyContinue
                if ($content -match 'rootProject\.name\s*=\s*[''"]([^''"]+)[''"]') {
                    $name = $matches[1].Trim()
                    break
                }
            }
        }
    }

    $safe = $name -replace '[^a-zA-Z0-9_\-\.]', '_'
    $safe = $safe.Trim('._-')
    if ([string]::IsNullOrWhiteSpace($safe)) {
        $safe = "android-project"
    }
    return $safe
}

function New-GradleSigningInitScript([string]$KeystorePath, [string]$StorePass, [string]$KeyAlias, [string]$KeyPass) {
    $tempScript = Join-Path $env:TEMP "builder-signing-$([System.Guid]::NewGuid().ToString('N')).gradle"
    $escapedPath = $KeystorePath.Replace('\', '/')
    $escapedStorePass = $StorePass.Replace('\', '\\').Replace('"', '\"')
    $escapedKeyAlias = $KeyAlias.Replace('\', '\\').Replace('"', '\"')
    $escapedKeyPass = $KeyPass.Replace('\', '\\').Replace('"', '\"')

    $gradleCode = @"
allprojects { project ->
    // 1. Eagerly disable strict ValidateSigningTask which throws when CI secrets are missing locally
    project.tasks.configureEach { task ->
        if (task.name.toLowerCase().contains("validatesigning")) {
            task.enabled = false
        }
    }

    // 2. Intercept and configure signing configurations
    project.afterEvaluate { proj ->
        if (proj.plugins.hasPlugin("com.android.application") || proj.plugins.hasPlugin("android")) {
            def androidExt = proj.extensions.findByName("android")
            if (androidExt != null) {
                def ksFile = new File("${escapedPath}")
                if (ksFile.exists()) {
                    // Populate existing 'release' signingConfig if missing or unresolvable
                    def relConfig = androidExt.signingConfigs.findByName("release")
                    if (relConfig != null) {
                        if (relConfig.storeFile == null || !relConfig.storeFile.exists()) {
                            relConfig.storeFile = ksFile
                            relConfig.storePassword = "${escapedStorePass}"
                            relConfig.keyAlias = "${escapedKeyAlias}"
                            relConfig.keyPassword = "${escapedKeyPass}"
                        }
                    }

                    // Populate any other signingConfigs lacking a valid storeFile
                    androidExt.signingConfigs.all { sc ->
                        if (sc.storeFile == null || !sc.storeFile.exists()) {
                            sc.storeFile = ksFile
                            sc.storePassword = "${escapedStorePass}"
                            sc.keyAlias = "${escapedKeyAlias}"
                            sc.keyPassword = "${escapedKeyPass}"
                        }
                    }

                    // Create dedicated fallback signingConfig
                    def fallbackSign = androidExt.signingConfigs.maybeCreate("builderReleaseSign")
                    fallbackSign.storeFile = ksFile
                    fallbackSign.storePassword = "${escapedStorePass}"
                    fallbackSign.keyAlias = "${escapedKeyAlias}"
                    fallbackSign.keyPassword = "${escapedKeyPass}"

                    androidExt.buildTypes.all { bt ->
                        if (bt.name == "release") {
                            if (bt.signingConfig == null || bt.signingConfig.storeFile == null || !bt.signingConfig.storeFile.exists()) {
                                bt.signingConfig = (relConfig != null && relConfig.storeFile != null && relConfig.storeFile.exists()) ? relConfig : fallbackSign
                            }
                        }
                    }
                }
            }

            // Ensure any late-registered ValidateSigningTask is also disabled
            proj.tasks.configureEach { task ->
                if (task.name.toLowerCase().contains("validatesigning")) {
                    task.enabled = false
                }
            }
        }
    }
}
"@

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tempScript, $gradleCode, $utf8NoBom)
    return $tempScript
}

function Ensure-ProjectSigningKeystore {
    param(
        [string]$ProjectDir,
        [string]$OutputDir,
        [string]$JdkPath,
        [string]$ExplicitKeystore = "",
        [string]$StorePass = "",
        [string]$KeyAlias = "",
        [string]$KeyPass = "",
        [string]$KeyDName = "",
        [switch]$SkipSigning
    )

    if ($SkipSigning.IsPresent) {
        return $null
    }

    $safeName = Get-ProjectSafeName $ProjectDir
    $builderRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $builderDistDir = Join-Path $builderRoot "dist\$safeName"
    $projectDistDir = Join-Path $ProjectDir $OutputDir

    if (-not (Test-Path $builderDistDir)) {
        New-Item -ItemType Directory -Path $builderDistDir -Force | Out-Null
    }
    if (-not (Test-Path $projectDistDir)) {
        New-Item -ItemType Directory -Path $projectDistDir -Force | Out-Null
    }

    # If explicit keystore path was passed via CLI
    if (-not [string]::IsNullOrWhiteSpace($ExplicitKeystore) -and (Test-Path $ExplicitKeystore)) {
        $resolvedKs = (Resolve-Path $ExplicitKeystore).Path
        $effectiveAlias = if ($KeyAlias) { $KeyAlias } else { "release" }
        $effectiveStorePass = if ($StorePass) { $StorePass } else { "android" }
        $effectiveKeyPass = if ($KeyPass) { $KeyPass } else { $effectiveStorePass }

        $builderKsDest = Join-Path $builderDistDir "$safeName-release.jks"
        if (-not (Test-Path $builderKsDest)) {
            Copy-Item -Path $resolvedKs -Destination $builderKsDest -Force -ErrorAction SilentlyContinue
        }

        return @{
            KeystorePath  = $resolvedKs
            StorePassword = $effectiveStorePass
            KeyAlias      = $effectiveAlias
            KeyPassword   = $effectiveKeyPass
            IsNewlyCreated= $false
            SafeName      = $safeName
            BuilderDist   = $builderDistDir
            ProjectDist   = $projectDistDir
        }
    }

    $expectedKsName = "$safeName-release.jks"
    $builderKs = Join-Path $builderDistDir $expectedKsName
    $projectKs = Join-Path $projectDistDir $expectedKsName
    $builderCreds = Join-Path $builderDistDir "signing-credentials.txt"
    $projectCreds = Join-Path $projectDistDir "signing-credentials.txt"

    # Check for existing keystore in either location (Self-healing recovery)
    $foundKs = $null
    if (Test-Path $builderKs) {
        $foundKs = $builderKs
        if (-not (Test-Path $projectKs)) {
            Copy-Item -Path $builderKs -Destination $projectKs -Force -ErrorAction SilentlyContinue
        }
        if ((Test-Path $builderCreds) -and -not (Test-Path $projectCreds)) {
            Copy-Item -Path $builderCreds -Destination $projectCreds -Force -ErrorAction SilentlyContinue
        }
    } elseif (Test-Path $projectKs) {
        $foundKs = $projectKs
        Copy-Item -Path $projectKs -Destination $builderKs -Force -ErrorAction SilentlyContinue
        if ((Test-Path $projectCreds) -and -not (Test-Path $builderCreds)) {
            Copy-Item -Path $projectCreds -Destination $builderCreds -Force -ErrorAction SilentlyContinue
        }
    }

    $hasCustomCreds = (-not [string]::IsNullOrWhiteSpace($KeyAlias)) -or 
                      (-not [string]::IsNullOrWhiteSpace($StorePass)) -or 
                      (-not [string]::IsNullOrWhiteSpace($KeyDName))

    if ($foundKs -and -not $hasCustomCreds) {
        $recoveredAlias = "release"
        $recoveredStorePass = "android"
        $recoveredKeyPass = $recoveredStorePass

        if (Test-Path $builderCreds) {
            $credContent = Get-Content $builderCreds -Raw -ErrorAction SilentlyContinue
            if ($credContent -match 'Key Alias:\s+(.+)') { $recoveredAlias = $matches[1].Trim() }
            if ($credContent -match 'Store Password:\s+(.+)') { $recoveredStorePass = $matches[1].Trim() }
            if ($credContent -match 'Key Password:\s+(.+)') { $recoveredKeyPass = $matches[1].Trim() }
        }

        Write-Success "Reusing existing release signing key: $foundKs"
        return @{
            KeystorePath  = $foundKs
            StorePassword = $recoveredStorePass
            KeyAlias      = $recoveredAlias
            KeyPassword   = $recoveredKeyPass
            IsNewlyCreated= $false
            SafeName      = $safeName
            BuilderDist   = $builderDistDir
            ProjectDist   = $projectDistDir
        }
    }

    # Generate new dedicated release keystore
    Write-Info "Generating new dedicated release signing keystore for '$safeName'..."

    $effectiveAlias = if ($KeyAlias) { $KeyAlias } else { "release" }
    $effectiveStorePass = if ($StorePass) { $StorePass } else { "android" }
    $effectiveKeyPass = if ($KeyPass) { $KeyPass } else { $effectiveStorePass }
    $effectiveDName = if (-not [string]::IsNullOrWhiteSpace($KeyDName)) {
        $KeyDName
    } else {
        "CN=$safeName,OU=AndroidAPKBuilder,O=LocalBuild,L=Local,ST=Local,C=US"
    }

    # Locate keytool
    $keytoolExe = Join-Path $JdkPath "bin\keytool.exe"
    if (-not (Test-Path $keytoolExe)) {
        $keytoolCmd = Get-Command keytool.exe -ErrorAction SilentlyContinue
        if ($keytoolCmd) {
            $keytoolExe = $keytoolCmd.Source
        }
    }

    if (-not (Test-Path $keytoolExe)) {
        Write-WarningMsg "Java keytool.exe could not be located. Automatic signing will be skipped."
        return $null
    }

    $genArgs = @(
        "-genkeypair",
        "-v",
        "-keystore", $builderKs,
        "-alias", $effectiveAlias,
        "-keyalg", "RSA",
        "-keysize", "2048",
        "-validity", "10000",
        "-storepass", $effectiveStorePass,
        "-keypass", $effectiveKeyPass,
        "-dname", $effectiveDName,
        "-storetype", "PKCS12"
    )

    if ($effectiveStorePass.Length -lt 6 -or $effectiveKeyPass.Length -lt 6) {
        Write-FailureMsg "Failed to generate keystore: Password must be at least 6 characters long for Java keystores."
        return $null
    }

    $genResult = Invoke-NativeCommand -Executable $keytoolExe -ArgumentList $genArgs -CaptureOutput -IgnoreExitCode
    if ($genResult.ExitCode -ne 0 -or -not (Test-Path $builderKs)) {
        $keytoolErr = if (-not [string]::IsNullOrWhiteSpace($genResult.StdErr)) {
            $genResult.StdErr.Trim()
        } elseif (-not [string]::IsNullOrWhiteSpace($genResult.StdOut)) {
            $genResult.StdOut.Trim()
        } else {
            "Unknown keytool failure"
        }
        Write-FailureMsg "Failed to generate keystore: $keytoolErr"
        return $null
    }

    Copy-Item -Path $builderKs -Destination $projectKs -Force

    $base64String = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($builderKs))

    # Obtain certificate fingerprints
    $listResult = Invoke-NativeCommand -Executable $keytoolExe -ArgumentList @("-list", "-v", "-keystore", $builderKs, "-storepass", $effectiveStorePass, "-alias", $effectiveAlias) -CaptureOutput -IgnoreExitCode
    $sha1 = "N/A"
    $sha256 = "N/A"
    if ($listResult.StdOut -match 'SHA1:\s+([A-Fa-f0-9:]+)') { $sha1 = $matches[1].Trim() }
    if ($listResult.StdOut -match 'SHA256:\s+([A-Fa-f0-9:]+)') { $sha256 = $matches[1].Trim() }

    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $manifestContent = @"
================================================================================
Android APK Builder - Release Signing Credentials & Deployment Manifest
Project: $safeName
Created: $now
================================================================================

KEYSTORE DETAILS:
  Keystore File:    $expectedKsName
  Keystore Format:  PKCS12 (Modern Android & Java Standard)
  Key Alias:        $effectiveAlias
  Store Password:   $effectiveStorePass
  Key Password:     $effectiveKeyPass
  Certificate DName:$effectiveDName
  Validity:         10,000 days (~27 years)

CERTIFICATE FINGERPRINTS:
  SHA-1:   $sha1
  SHA-256: $sha256

--------------------------------------------------------------------------------
GOOGLE PLAY STORE / APP DISTRIBUTION:
  - This keystore can be used directly as your Google Play Upload Key.
  - APKs and AABs signed with this key can be safely updated on user devices
    without encountering INSTALL_FAILED_UPDATE_INCOMPATIBLE errors.
  - Note: If an older version of this app was previously installed with a
    different key, uninstall the previous version from your device first.

--------------------------------------------------------------------------------
GITHUB ACTIONS CI / SECRETS CONFIGURATION:
  To build and sign with this exact key in GitHub Actions, add these
  Repository Secrets (Settings -> Secrets and variables -> Actions):

  1. KEYSTORE_BASE64:
     (Copy the full base64 string block below)

  2. KEYSTORE_PASSWORD:
     $effectiveStorePass

  3. KEY_ALIAS:
     $effectiveAlias

  4. KEY_PASSWORD:
     $effectiveKeyPass

  GITHUB ACTIONS RESTORATION STEP:
  --------------------------------------------------
  - name: Restore Release Keystore
    run: |
      echo "`$`{{ secrets.KEYSTORE_BASE64 }}" | base64 --decode > app/$expectedKsName
  --------------------------------------------------

FULL BASE64 ENCODED KEYSTORE (Copy everything between delimiters):
-----BEGIN KEYSTORE BASE64-----
$base64String
-----END KEYSTORE BASE64-----
================================================================================
"@

    Set-Content -Path $builderCreds -Value $manifestContent -Encoding UTF8
    Set-Content -Path $projectCreds -Value $manifestContent -Encoding UTF8

    Write-Success "Created release keystore: $builderKs"
    Write-Success "Saved credentials & GitHub Secrets manifest to: $builderCreds"

    return @{
        KeystorePath  = $builderKs
        StorePassword = $effectiveStorePass
        KeyAlias      = $effectiveAlias
        KeyPassword   = $effectiveKeyPass
        IsNewlyCreated= $true
        SafeName      = $safeName
        BuilderDist   = $builderDistDir
        ProjectDist   = $projectDistDir
    }
}

function Sign-ApkWithBuilderKey {
    param(
        [string]$ApkPath,
        [string]$KeystorePath,
        [string]$StorePass,
        [string]$KeyAlias,
        [string]$KeyPass,
        [string]$AndroidHome,
        [string]$BuildToolsVersion
    )

    if (-not (Test-Path $ApkPath) -or -not (Test-Path $KeystorePath)) {
        return $ApkPath
    }

    $apksigner = Join-Path $AndroidHome "build-tools\$BuildToolsVersion\apksigner.bat"
    $zipalign = Join-Path $AndroidHome "build-tools\$BuildToolsVersion\zipalign.exe"

    if (-not (Test-Path $apksigner)) {
        $found = Get-ChildItem -Path (Join-Path $AndroidHome "build-tools") -Filter "apksigner.bat" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $apksigner = $found.FullName }
    }
    if (-not (Test-Path $zipalign)) {
        $foundZ = Get-ChildItem -Path (Join-Path $AndroidHome "build-tools") -Filter "zipalign.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($foundZ) { $zipalign = $foundZ.FullName }
    }

    if (-not (Test-Path $apksigner)) {
        Write-WarningMsg "apksigner.bat not found in Android build-tools. Skipping post-build signing."
        return $ApkPath
    }

    Write-Info "Signing APK with project release key: $(Split-Path $ApkPath -Leaf)"

    # Check and run zipalign if available
    if (Test-Path $zipalign) {
        $tempAligned = Join-Path $env:TEMP "aligned-$([System.Guid]::NewGuid().ToString('N')).apk"
        $alignCheck = Invoke-NativeCommand -Executable $zipalign -ArgumentList @("-c", "-v", "4", $ApkPath) -CaptureOutput -IgnoreExitCode
        if ($alignCheck.ExitCode -ne 0) {
            Write-Dim "Zip-aligning APK (4-byte boundary)..."
            $alignExec = Invoke-NativeCommand -Executable $zipalign -ArgumentList @("-p", "-f", "4", $ApkPath, $tempAligned) -CaptureOutput -IgnoreExitCode
            if ($alignExec.ExitCode -eq 0 -and (Test-Path $tempAligned)) {
                Copy-Item -Path $tempAligned -Destination $ApkPath -Force
                Remove-Item -Path $tempAligned -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Run apksigner
    $signArgs = @(
        "sign",
        "--ks", $KeystorePath,
        "--ks-pass", "pass:$StorePass",
        "--ks-key-alias", $KeyAlias,
        "--key-pass", "pass:$KeyPass",
        "--v1-signing-enabled", "true",
        "--v2-signing-enabled", "true",
        "--v3-signing-enabled", "true",
        "--v4-signing-enabled", "false",
        $ApkPath
    )

    $signResult = Invoke-NativeCommand -Executable $apksigner -ArgumentList $signArgs -CaptureOutput -IgnoreExitCode
    if ($signResult.ExitCode -ne 0) {
        Write-WarningMsg "apksigner exited with code $($signResult.ExitCode): $($signResult.StdErr)"
        return $ApkPath
    }

    $finalApkPath = $ApkPath
    if ($ApkPath -match '-unsigned\.apk$') {
        $renamed = $ApkPath -replace '-unsigned\.apk$', '.apk'
        if (-not (Test-Path $renamed)) {
            Move-Item -Path $ApkPath -Destination $renamed -Force
            $finalApkPath = $renamed
        }
    }

    Write-Success "Successfully signed: $(Split-Path $finalApkPath -Leaf)"
    return $finalApkPath
}

# ==============================================================================
# MAIN EXECUTION ORCHESTRATION PIPELINE
# ==============================================================================

try {
    $currentDir = (Get-Location).Path
    $global:IsInteractiveSession = $Interactive.IsPresent -or ([string]::IsNullOrWhiteSpace($ProjectDir) -and -not (Test-IsAndroidProject $currentDir))

    $targetRoot = $ProjectDir
    if ($global:IsInteractiveSession) {
        Invoke-InteractiveBuildWizard `
            -TargetRootRef ([ref]$targetRoot) `
            -BuildTypeRef ([ref]$BuildType) `
            -ArtifactTypeRef ([ref]$ArtifactType) `
            -CleanFirstRef ([ref]$CleanFirst) `
            -ForceLowMemRef ([ref]$ForceLowMem) `
            -KeystorePathRef ([ref]$KeystorePath) `
            -StorePasswordRef ([ref]$StorePassword) `
            -KeyAliasRef ([ref]$KeyAlias) `
            -KeyPasswordRef ([ref]$KeyPassword) `
            -KeyDNameRef ([ref]$KeyDName) `
            -SkipSigningRef ([ref]$SkipSigning)
    } else {
        if ([string]::IsNullOrWhiteSpace($targetRoot)) {
            $targetRoot = $currentDir
        }
    }

    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "  Android APK Builder - Universal Build Automation System        " -ForegroundColor Cyan
    Write-Host '  Engineered for Robustness, Non-Destructive Operation & Portability' -ForegroundColor DarkCyan
    Write-Host "==================================================================" -ForegroundColor Cyan

    # ------------------------------------------------------------------------------
    # STAGE 1: Project Root Inspection & Compatibility Discovery
    # ------------------------------------------------------------------------------
    Write-StageHeader '[Stage 1/6] Inspecting Target Android Project'

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
    Exit-WithCode 1
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
if ($projectSpec.DaemonJvmVersion -gt 0) {
    Write-Info "Gradle Daemon JVM: Java $($projectSpec.DaemonJvmVersion)$(if ($projectSpec.DaemonJvmVendor) { ' (Vendor: ' + $projectSpec.DaemonJvmVendor + ')' } else { '' })"
}
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
    $vendorInfo = if ($j.Vendor) { " [$($j.Vendor)]" } else { "" }
    Write-Dim ('Found JDK {0} (64-bit: {1}){2} at: {3}' -f $j.MajorVersion, $j.Is64Bit, $vendorInfo, $j.Path)
}

$selectedJdk = $null
if (-not [string]::IsNullOrEmpty($JdkPath) -and (Test-Path $JdkPath)) {
    $explicitMatch = $installedJdks | Where-Object { $_.Path.TrimEnd('\') -eq $JdkPath.TrimEnd('\') } | Select-Object -First 1
    if ($explicitMatch) {
        $selectedJdk = $explicitMatch
    }
}

if (-not $selectedJdk) {
    $preferredVersion = if ($projectSpec.DaemonJvmVersion -gt 0) {
        $projectSpec.DaemonJvmVersion
    } elseif ($selectedAppModule.JavaToolchain -gt 0) {
        $selectedAppModule.JavaToolchain
    } elseif ($selectedAppModule.SourceCompatibility -gt 0) {
        $selectedAppModule.SourceCompatibility
    } else {
        17
    }

    $preferredVendor = if ($projectSpec.DaemonJvmVendor) { $projectSpec.DaemonJvmVendor } else { "" }

    $selectedJdk = Select-CompatibleJdk $installedJdks $compatibility.MinJdk $compatibility.MaxJdk $preferredVersion $preferredVendor
}

if (-not $selectedJdk -and -not $SkipJdkInstall) {
    Write-WarningMsg "No compatible JDK ($($compatibility.MinJdk)-$($compatibility.MaxJdk)) located on host."
    $winget = Get-Command "winget" -ErrorAction SilentlyContinue
    if ($winget) {
        $pkgId = if ($compatibility.MinJdk -ge 21) { "EclipseAdoptium.Temurin.21.JDK" } elseif ($compatibility.MinJdk -le 11 -and $compatibility.MaxJdk -le 11) { "EclipseAdoptium.Temurin.11.JDK" } else { "EclipseAdoptium.Temurin.17.JDK" }
        Write-Info "Attempting automated installation of $pkgId via winget..."
        $wRes = Invoke-NativeCommand -Executable "winget" -ArgumentList @("install", $pkgId, "--accept-source-agreements", "--accept-package-agreements", "--silent") -IgnoreExitCode
        if ($wRes.Success) {
            $installedJdks = Find-InstalledJdks
            $selectedJdk = Select-CompatibleJdk $installedJdks $compatibility.MinJdk $compatibility.MaxJdk $preferredVersion $preferredVendor
        }
    }
}

if (-not $selectedJdk) {
    Write-FailureMsg "Compatible JDK ($($compatibility.MinJdk)-$($compatibility.MaxJdk)) could not be located or installed."
    Write-Host "  Please install OpenJDK $($compatibility.MinJdk) from: https://adoptium.net/temurin/releases/" -ForegroundColor Yellow
    Exit-WithCode 1
}

$activeVendorInfo = if ($selectedJdk.Vendor) { " [$($selectedJdk.Vendor)]" } else { "" }
Write-Success ('Selected Active JDK: Java {0}{1} ({2})' -f $selectedJdk.MajorVersion, $activeVendorInfo, $selectedJdk.Path)

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
    Exit-WithCode 0
}

# Setup Release Signing Keystore & Init Script
$signingInfo = $null
$gradleInitScript = $null

if (($BuildType -eq "Release" -or $BuildType -eq "Both") -and -not $SkipSigning.IsPresent) {
    Write-Info "Preparing release signing keystore and credentials..."
    $signingInfo = Ensure-ProjectSigningKeystore `
        -ProjectDir $targetRoot `
        -OutputDir $OutputDir `
        -JdkPath $selectedJdk.Path `
        -ExplicitKeystore $KeystorePath `
        -StorePass $StorePassword `
        -KeyAlias $KeyAlias `
        -KeyPass $KeyPassword `
        -KeyDName $KeyDName `
        -SkipSigning:$SkipSigning

    if ($signingInfo -and (Test-Path $signingInfo.KeystorePath)) {
        $gradleInitScript = New-GradleSigningInitScript `
            -KeystorePath $signingInfo.KeystorePath `
            -StorePass $signingInfo.StorePassword `
            -KeyAlias $signingInfo.KeyAlias `
            -KeyPass $signingInfo.KeyPassword
        
        Write-Success "Configured transparent Gradle release signing injection."
    }
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
if ($installedJdks.Count -gt 0) {
    $validJdkPaths = @($installedJdks | ForEach-Object { $_.Path } | Select-Object -Unique)
    $gradleArgs += "-Dorg.gradle.java.installations.paths=$($validJdkPaths -join ',')"
}
if ($gradleInitScript -and (Test-Path $gradleInitScript)) {
    $gradleArgs += @("--init-script", $gradleInitScript)
}
if ($Offline.IsPresent) {
    $gradleArgs += "--offline"
}

# Inject common CI environment variable aliases so System.getenv() calls resolve correctly
$envAliasesToRestore = @{}
if ($signingInfo) {
    Write-Info "Injecting local signing secrets into process environment for build tasks..."
    $pathVars = @("KEYSTORE_PATH", "KEYSTORE_FILE", "KEY_STORE_PATH", "RELEASE_KEYSTORE_PATH", "SIGNING_KEYSTORE_PATH", "RELEASE_STORE_FILE")
    $storePassVars = @("KEYSTORE_PASSWORD", "KEY_STORE_PASSWORD", "STORE_PASSWORD", "RELEASE_KEYSTORE_PASSWORD", "RELEASE_STORE_PASSWORD")
    $aliasVars = @("KEY_ALIAS", "KEYSTORE_ALIAS", "RELEASE_KEY_ALIAS", "SIGNING_KEY_ALIAS", "RELEASE_KEY_NAME")
    $keyPassVars = @("KEY_PASSWORD", "KEYSTORE_KEY_PASSWORD", "RELEASE_KEY_PASSWORD")

    $allVars = $pathVars + $storePassVars + $aliasVars + $keyPassVars
    foreach ($var in $allVars) {
        $envAliasesToRestore[$var] = [System.Environment]::GetEnvironmentVariable($var, "Process")
    }

    foreach ($v in $pathVars) { [System.Environment]::SetEnvironmentVariable($v, $signingInfo.KeystorePath, "Process") }
    foreach ($v in $storePassVars) { [System.Environment]::SetEnvironmentVariable($v, $signingInfo.StorePassword, "Process") }
    foreach ($v in $aliasVars) { [System.Environment]::SetEnvironmentVariable($v, $signingInfo.KeyAlias, "Process") }
    foreach ($v in $keyPassVars) { [System.Environment]::SetEnvironmentVariable($v, $signingInfo.KeyPassword, "Process") }
}

Write-Info "Executing Gradle build command: .\gradlew.bat $($gradleArgs -join ' ')"
$buildStartTime = Get-Date

try {
    # Execute build
    $buildResult = Invoke-NativeCommand -Executable $gradlewBat -ArgumentList $gradleArgs -WorkingDirectory $targetRoot -IgnoreExitCode

    if (-not $buildResult.Success) {
        Write-Host ""
        Write-FailureMsg "Gradle build failed with exit code $($buildResult.ExitCode)."
        if ($BuildType -eq "Release" -and -not $selectedAppModule.HasReleaseSigning -and -not $signingInfo) {
            Write-WarningMsg "DIAGNOSTIC: This project does not appear to have release signing configured."
            Write-WarningMsg "Many open-source projects fail assembleRelease unless signing credentials are provided."
            Write-WarningMsg "Remedy: Try building with: build.bat -BuildType Debug"
        }
        Exit-WithCode $buildResult.ExitCode
    }
} finally {
    if ($gradleInitScript -and (Test-Path $gradleInitScript)) {
        Remove-Item -Path $gradleInitScript -Force -ErrorAction SilentlyContinue
    }
    if ($envAliasesToRestore.Count -gt 0) {
        foreach ($k in $envAliasesToRestore.Keys) {
            [System.Environment]::SetEnvironmentVariable($k, $envAliasesToRestore[$k], "Process")
        }
    }
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
    Exit-WithCode 1
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  BUILD SUCCESSFUL - HARVESTED ARTIFACTS                         " -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green

$copiedCount = 0
$harvestedFiles = @()

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

    # Inspect and apply post-build signing if needed
    if ($destFile.EndsWith(".apk")) {
        $sigInfo = Verify-ApkSignature $destFile $androidSdkRoot $effectiveBuildTools
        if (-not $sigInfo.IsSigned -and $signingInfo -and -not $SkipSigning.IsPresent) {
            $destFile = Sign-ApkWithBuilderKey `
                -ApkPath $destFile `
                -KeystorePath $signingInfo.KeystorePath `
                -StorePass $signingInfo.StorePassword `
                -KeyAlias $signingInfo.KeyAlias `
                -KeyPass $signingInfo.KeyPassword `
                -AndroidHome $androidSdkRoot `
                -BuildToolsVersion $effectiveBuildTools
            
            # Re-verify after signing
            $sigInfo = Verify-ApkSignature $destFile $androidSdkRoot $effectiveBuildTools
        }

        $sizeMb = [math]::Round((Get-Item $destFile).Length / 1MB, 2)
        $sha256 = Get-FileSha256 $destFile

        Write-Host "  File:     $destFile" -ForegroundColor Cyan
        Write-Host "  Size:     $sizeMb MB" -ForegroundColor DarkCyan
        Write-Host "  SHA-256:  $sha256" -ForegroundColor DarkGray
        if ($sigInfo.IsSigned) {
            Write-Host "  Signing:  Verified ($($sigInfo.SignerScheme) - $($sigInfo.SignerName))" -ForegroundColor Green
        } else {
            Write-Host "  Signing:  UNSIGNED (Requires signing key before device install)" -ForegroundColor Yellow
        }
    } else {
        $sizeMb = [math]::Round((Get-Item $destFile).Length / 1MB, 2)
        $sha256 = Get-FileSha256 $destFile
        Write-Host "  File:     $destFile" -ForegroundColor Cyan
        Write-Host "  Size:     $sizeMb MB" -ForegroundColor DarkCyan
        Write-Host "  SHA-256:  $sha256" -ForegroundColor DarkGray
    }

    Write-Host "------------------------------------------------------------------" -ForegroundColor DarkGray
    $copiedCount++
    $harvestedFiles += $destFile
}

# Mirror all harvested artifacts and credentials into android-apk-builder dist folder
$builderDistDir = $null
if ($signingInfo) {
    $builderDistDir = $signingInfo.BuilderDist
} else {
    $safeName = Get-ProjectSafeName $targetRoot
    $builderRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $builderDistDir = Join-Path $builderRoot "dist\$safeName"
}

if (-not (Test-Path $builderDistDir)) {
    New-Item -ItemType Directory -Path $builderDistDir -Force | Out-Null
}

foreach ($hf in $harvestedFiles) {
    Copy-Item -Path $hf -Destination (Join-Path $builderDistDir (Split-Path $hf -Leaf)) -Force
}

# Mirror keystore to project outputBaseDir as well if not already there
if ($signingInfo -and (Test-Path $signingInfo.KeystorePath)) {
    $ksLeaf = Split-Path $signingInfo.KeystorePath -Leaf
    $destKs = Join-Path $outputBaseDir $ksLeaf
    if (-not (Test-Path $destKs)) {
        Copy-Item -Path $signingInfo.KeystorePath -Destination $destKs -Force -ErrorAction SilentlyContinue
    }
    $credSrc = Join-Path (Split-Path $signingInfo.KeystorePath -Parent) "signing-credentials.txt"
    if (Test-Path $credSrc) {
        Copy-Item -Path $credSrc -Destination (Join-Path $outputBaseDir "signing-credentials.txt") -Force -ErrorAction SilentlyContinue
    }
}

Write-Success "Harvested $copiedCount artifact(s) into: $outputBaseDir"
Write-Success "Mirrored artifacts & signing archive to: $builderDistDir"
Write-Host ""
Exit-WithCode 0
} catch {
    Write-Host ""
    Write-FailureMsg $_.Exception.Message
    Exit-WithCode 1
}
