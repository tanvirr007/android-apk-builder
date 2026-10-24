@echo off
rem ==============================================================================
rem Android APK Builder - Universal 1-Click Interactive Build Launcher
rem ==============================================================================
rem Author:  Tanvir Hasan
rem Website: https://tanvir.info
rem GitHub:  https://github.com/tanvirr007
rem
rem Automatically bypasses PowerShell ExecutionPolicy restrictions and launches
rem the interactive build wizard or executes with forwarded arguments.
rem
rem USAGE:
rem   1. Interactive Build (Double-click or run from terminal):
rem      build.bat
rem
rem   2. Drag-and-drop:
rem      Drag your Android project folder onto build.bat in Windows Explorer.
rem
rem   3. Direct project path:
rem      build.bat "C:\path\to\your\android-project"
rem
rem   4. Advanced CLI usage:
rem      build.bat -ProjectDir "C:\path\to\project" -BuildType Release -ArtifactType APK
rem
rem   5. Custom Release Signing Key:
rem      build.bat -ProjectDir "C:\path\to\project" -KeystorePath "C:\keys\my-key.jks" -StorePassword "secret"
rem ==============================================================================

setlocal
if "%~1"=="" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-windows.ps1" -Interactive
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-windows.ps1" %*
)
set EXITCODE=%ERRORLEVEL%
endlocal & exit /b %EXITCODE%
