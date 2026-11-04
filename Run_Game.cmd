@echo off
cd /d "%~dp0"
set "GODOT_EXE=%~dp0Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" set "GODOT_EXE=A:\MonsterDone_Godot\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT_EXE%" (
	@echo Preparing project assets. The first run may take about one minute...
	"%GODOT_EXE%" --headless --import --path "%~dp0"
	if errorlevel 1 (
		echo Asset import failed. Open Open_Editor.cmd to view the error.
		pause
		exit /b 1
	)
  "%GODOT_EXE%" --path "%~dp0"
  exit /b
)
echo Godot_v4.7.2-stable_win64.exe was not found in this folder.
echo Open project.godot with Godot 4.7.2 instead.
pause
