@echo off
set SCRIPT_DIR=%~dp0
call "%SCRIPT_DIR%run_battle_detached_common.bat" "%~1" dungeon_smoke "res://core/world/tests/run_dungeon_smoke_tests.gd" %2 %3 %4 %5 %6 %7 %8 %9
exit /b %ERRORLEVEL%
