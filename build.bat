@echo off
rem ==============================================================================
rem Android APK Builder
rem ==============================================================================
rem Author:  Tanvir Hasan
rem Website: https://tanvir.info
rem GitHub:  https://github.com/tanvirr007
rem
rem Automatically bypasses PowerShell ExecutionPolicy restrictions and launches
rem the interactive build wizard or executes with forwarded arguments.
rem
rem USAGE:
rem   1. 1-Click Interactive Build Wizard (Double-click or run from terminal):
rem      build.bat
rem
rem   2. Drag-and-drop:
rem      Drag your Android project folder onto build.bat in Windows Explorer.
rem
rem   3. Direct project path:
rem      build.bat "C:\path\to\your\android-project"
rem
rem   4. Build Debug or Release:
rem      build.bat -ProjectDir "C:\path\to\project" -BuildType Release
rem      build.bat -ProjectDir "C:\path\to\project" -BuildType Debug
rem
rem   5. Build App Bundle (.aab):
rem      build.bat -ProjectDir "C:\path\to\project" -ArtifactType AAB
rem
rem   6. Low-memory mode (Potato PC / <= 8GB RAM):
rem      build.bat -ProjectDir "C:\path\to\project" -BuildType Release -ForceLowMem
rem
rem   7. Custom Release Signing Key:
rem      build.bat -ProjectDir "C:\path\to\project" -KeystorePath "C:\keys\my.jks" -StorePassword "secret"
rem ==============================================================================

setlocal
if "%~1"=="" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-windows.ps1" -Interactive
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-windows.ps1" %*
)
set EXITCODE=%ERRORLEVEL%
endlocal & exit /b %EXITCODE%
