@echo off
echo =======================================================
echo   Smart Traffic Management System (STMS) Backend Server
echo   Running FastAPI on http://127.0.0.1:8000
echo =======================================================
cd /d "%~dp0"
call .venv\Scripts\activate.bat
python -m uvicorn backend.main:app --host 127.0.0.1 --port 8000 --reload
pause
