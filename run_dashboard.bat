@echo off
echo =======================================================
echo   Smart Traffic Management System (STMS) Live Dashboard
echo   Running Streamlit on http://localhost:8501
echo =======================================================
cd /d "%~dp0"
call .venv\Scripts\activate.bat
python -m streamlit run dashboard/app.py --server.port 8501
pause
