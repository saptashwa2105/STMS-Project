const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const projectRoot = path.resolve(__dirname, '..');

// Locate Python executable
const venvPythonWin = path.join(projectRoot, '.venv', 'Scripts', 'python.exe');
const venvPythonUnix = path.join(projectRoot, '.venv', 'bin', 'python');
let pythonExe = 'python';

if (fs.existsSync(venvPythonWin)) {
    pythonExe = venvPythonWin;
} else if (fs.existsSync(venvPythonUnix)) {
    pythonExe = venvPythonUnix;
}

console.log('\x1b[36m%s\x1b[0m', '================================================================');
console.log('\x1b[36m%s\x1b[0m', '   Smart Traffic Management System (STMS) - Dev Server');
console.log('\x1b[36m%s\x1b[0m', '================================================================');
console.log(`Python: ${pythonExe}`);
console.log('');
console.log('\x1b[32m%s\x1b[0m', '🚀 Services launching:');
console.log('   📡 Backend API:      \x1b[34mhttp://127.0.0.1:8000\x1b[0m (Docs: \x1b[34mhttp://127.0.0.1:8000/docs\x1b[0m)');
console.log('   📊 Analytics UI:     \x1b[35mhttp://localhost:8501\x1b[0m');
console.log('   🎮 3D Simulation:    Run "\x1b[33mnpm run simulation\x1b[0m" to launch Godot 4');
console.log('\x1b[36m%s\x1b[0m', '================================================================');
console.log('');

const children = [];

function startProcess(name, colorCode, command, args, cwd) {
    const proc = spawn(command, args, {
        cwd: cwd || projectRoot,
        env: { ...process.env, PYTHONUNBUFFERED: '1' },
        shell: false
    });

    children.push(proc);

    const prefix = `\x1b[${colorCode}m[${name}]\x1b[0m `;

    proc.stdout.on('data', (data) => {
        const lines = data.toString().split('\n');
        for (const line of lines) {
            if (line.trim()) process.stdout.write(prefix + line + '\n');
        }
    });

    proc.stderr.on('data', (data) => {
        const lines = data.toString().split('\n');
        for (const line of lines) {
            if (line.trim()) process.stderr.write(prefix + line + '\n');
        }
    });

    proc.on('exit', (code, signal) => {
        if (code !== null && code !== 0) {
            console.log(`${prefix}Process exited with code ${code}`);
        }
    });

    return proc;
}

// 1. Start FastAPI backend (port 8000)
startProcess(
    'BACKEND',
    '36', // Cyan
    pythonExe,
    ['-m', 'uvicorn', 'backend.main:app', '--host', '127.0.0.1', '--port', '8000', '--reload']
);

// 2. Start Streamlit dashboard (port 8501)
startProcess(
    'DASHBOARD',
    '35', // Magenta
    pythonExe,
    ['-m', 'streamlit', 'run', 'dashboard/app.py', '--server.port', '8501', '--server.headless', 'true']
);

// Graceful cleanup
function cleanup() {
    console.log('\n\x1b[33mStopping STMS services...\x1b[0m');
    for (const child of children) {
        try {
            if (!child.killed) {
                if (process.platform === 'win32') {
                    spawn('taskkill', ['/pid', child.pid, '/f', '/t']);
                } else {
                    child.kill('SIGINT');
                }
            }
        } catch (e) {
            // ignore
        }
    }
    process.exit(0);
}

process.on('SIGINT', cleanup);
process.on('SIGTERM', cleanup);
