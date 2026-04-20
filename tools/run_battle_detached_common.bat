@echo off
REM Shared detached runner for Godot-based battle test suites.

setlocal enabledelayedexpansion

set PROJECT_PATH=%cd%
if not "%~1"=="" set PROJECT_PATH=%~1
set TEST_LABEL=%~2
set TEST_SCRIPT=%~3

if "%TEST_LABEL%"=="" (
    echo ERROR: Missing test label
    exit /b 1
)

if "%TEST_SCRIPT%"=="" (
    echo ERROR: Missing test script path
    exit /b 1
)

shift
shift
shift

set EXTRA_ARGS=
:collect_args
if "%~1"=="" goto args_done
set EXTRA_ARGS=!EXTRA_ARGS! %~1
shift
goto collect_args

:args_done
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a-%%b)
set TIMESTAMP=%mydate%_%mytime%

set LOG_DIR=%PROJECT_PATH%\docs\qa\logs
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
set LOG_FILE=%LOG_DIR%\battle_%TEST_LABEL%_%TIMESTAMP%.log

for %%E in (godot.exe Godot_v4.6-stable_win64_console.exe Godot_v4.6-stable_win64.exe) do (
    for /f %%F in ('where %%E 2^>nul') do (
        set GODOT_EXE=%%F
        goto found
    )
)

:found
if "!GODOT_EXE!"=="" (
    echo ERROR: Godot executable not found
    exit /b 1
)

echo Running Godot battle %TEST_LABEL% tests...
echo Godot: !GODOT_EXE!
echo Log: %LOG_FILE%

"!GODOT_EXE!" --headless --path "%PROJECT_PATH%" --script "%TEST_SCRIPT%" -- !EXTRA_ARGS! > "%LOG_FILE%" 2>&1
set EXITCODE=!ERRORLEVEL!

if !EXITCODE! equ 0 (
    echo Battle %TEST_LABEL% tests: PASS
) else (
    echo Battle %TEST_LABEL% tests: FAIL ^(exit !EXITCODE!^)
)

exit /b !EXITCODE!