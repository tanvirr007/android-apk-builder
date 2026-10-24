@echo off
rem ==============================================================================
rem Android APK Builder - Universal 1-Click Windows Batch Launcher
rem ==============================================================================
rem Author:  Tanvir Hasan
rem Website: https://tanvir.info
rem GitHub:  https://github.com/tanvirr007
rem
rem Automatically bypasses PowerShell ExecutionPolicy restrictions and invokes
rem setup-windows.ps1 with full argument forwarding.
rem
rem USAGE:
rem   1. Inside your target Android project directory:
rem      C:\path\to\android-apk-builder\setup-windows.bat -BuildType Release
rem
rem   2. Passing the target project directory explicitly:
rem      setup-windows.bat -ProjectDir "C:\path\to\project" -BuildType Release
rem
rem   3. Forcing low memory (Potato PC profile):
rem      setup-windows.bat -ProjectDir "C:\path\to\project" -BuildType Release -ForceLowMem
rem
rem   4. Interactive Build Wizard:
rem      setup-windows.bat (or use build.bat)
rem ==============================================================================

setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-windows.ps1" %*
set EXITCODE=%ERRORLEVEL%
endlocal & exit /b %EXITCODE%
