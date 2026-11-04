@echo off
cd /d "%~dp0"
start "" "Godot_v4.7.2-stable_win64.exe" --path "%~dp0." --script res://tools/preview_overheat_dash.gd
