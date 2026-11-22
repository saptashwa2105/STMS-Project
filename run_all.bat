@echo off
echo =======================================================
echo   Launching STMS Full Stack: Backend + Dashboard + Godot
echo =======================================================
cd /d "%~dp0"

echo [1/3] Starting Python FastAPI backend on http://127.0.0.1:8000 ...
start "STMS Backend Server" cmd /k "run_backend.bat"

echo [2/3] Starting Streamlit Live Dashboard on http://localhost:8501 ...
timeout /t 2 /nobreak >nul
start "STMS Streamlit Dashboard" cmd /k "run_dashboard.bat"

echo [3/3] Launching Godot 4 3D Simulation ...
timeout /t 2 /nobreak >nul
start "STMS Godot Simulation" cmd /c "run_simulation.bat"

echo.
echo All services launched!
echo - Backend API:  http://127.0.0.1:8000/docs
echo - Live Analytics: http://localhost:8501
echo.
