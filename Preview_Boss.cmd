@echo off
cd /d "%~dp0"
start "" "%~dp0Godot_v4.7.2-stable_win64.exe" --path "%~dp0." res://scenes/main.tscn -- --boss-now
