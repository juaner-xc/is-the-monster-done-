@echo off
cd /d "%~dp0"
"%~dp0Godot_v4.7.2-stable_win64.exe" --headless --import --path .
if errorlevel 1 exit /b 1
"%~dp0Godot_v4.7.2-stable_win64.exe" --path . res://scenes/opening_film.tscn

