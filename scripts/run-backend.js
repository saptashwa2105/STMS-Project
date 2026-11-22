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

console.log(`Starting STMS FastAPI Backend on http://127.0.0.1:8000 ...`);
const proc = spawn(pythonExe, ['-m', 'uvicorn', 'backend.main:app', '--host', '127.0.0.1', '--port', '8000', '--reload'], {
    cwd: projectRoot,
    stdio: 'inherit'
});

proc.on('exit', (code) => process.exit(code || 0));
