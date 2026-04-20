@echo off
set SCRIPT_DIR=%~dp0
call "%SCRIPT_DIR%run_battle_detached_common.bat" "%~1" logic "res://core/battle/tests/run_battle_logic_tests.gd" %2 %3 %4 %5 %6 %7 %8 %9
exit /b %ERRORLEVEL%