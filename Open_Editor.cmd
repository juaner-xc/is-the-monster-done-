@echo off
cd /d "%~dp0"
set "GODOT_EXE=%~dp0Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" set "GODOT_EXE=A:\MonsterDone_Godot\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT_EXE%" (
  "%GODOT_EXE%" --editor --path "%~dp0"
  exit /b
)
echo Godot_v4.7.2-stable_win64.exe was not found in this folder.
echo Open project.godot with Godot 4.7.2 instead.
pause
