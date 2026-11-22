const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const projectRoot = path.resolve(__dirname, '..');
const venvPythonWin = path.join(projectRoot, '.venv', 'Scripts', 'python.exe');
const venvPythonUnix = path.join(projectRoot, '.venv', 'bin', 'python');
let pythonExe = 'python';

if (fs.existsSync(venvPythonWin)) {
    pythonExe = venvPythonWin;
} else if (fs.existsSync(venvPythonUnix)) {
    pythonExe = venvPythonUnix;
}

console.log(`Starting STMS Streamlit Live Dashboard on http://localhost:8501 ...`);
const proc = spawn(pythonExe, ['-m', 'streamlit', 'run', 'dashboard/app.py', '--server.port', '8501'], {
    cwd: projectRoot,
    stdio: 'inherit'
});

proc.on('exit', (code) => process.exit(code || 0));
