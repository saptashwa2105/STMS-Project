@echo off
echo =======================================================
echo   Smart Traffic Management System (STMS) 3D Simulation
echo   Launching Godot Engine 4 Digital Twin
echo =======================================================
cd /d "%~dp0"
tools\godot\godot.exe --path simulation
