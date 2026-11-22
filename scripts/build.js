const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

console.log('\x1b[36m%s\x1b[0m', '=======================================================');
console.log('\x1b[36m%s\x1b[0m', '   STMS: Building & Verifying Project Components');
console.log('\x1b[36m%s\x1b[0m', '=======================================================');

const projectRoot = path.resolve(__dirname, '..');

// 1. Locate Python executable (.venv or system python)
const venvPythonWin = path.join(projectRoot, '.venv', 'Scripts', 'python.exe');
const venvPythonUnix = path.join(projectRoot, '.venv', 'bin', 'python');
let pythonExe = 'python';

if (fs.existsSync(venvPythonWin)) {
    pythonExe = venvPythonWin;
} else if (fs.existsSync(venvPythonUnix)) {
    pythonExe = venvPythonUnix;
}

console.log(`[1/4] Using Python executable: ${pythonExe}`);
const pyVersion = spawnSync(pythonExe, ['--version'], { encoding: 'utf-8' });
if (pyVersion.error) {
    console.error('\x1b[31m[ERROR]\x1b[0m Failed to execute Python: ' + pyVersion.error.message);
    process.exit(1);
}
console.log(`      Version: ${(pyVersion.stdout || pyVersion.stderr || '').trim()}`);

// 2. Validate essential files
console.log('[2/4] Validating project structure and essential files...');
const requiredFiles = [
    'backend/main.py',
    'backend/app.py',
    'dashboard/app.py',
    'simulation/project.godot',
    'tools/test_backend_and_dashboard.py'
];

let missingFiles = 0;
for (const relPath of requiredFiles) {
    const fullPath = path.join(projectRoot, relPath);
    if (!fs.existsSync(fullPath)) {
        console.error(`\x1b[31m  [MISSING]\x1b[0m ${relPath}`);
        missingFiles++;
    } else {
        console.log(`  \x1b[32m[OK]\x1b[0m ${relPath}`);
    }
}

if (missingFiles > 0) {
    console.error(`\x1b[31m[ERROR]\x1b[0m ${missingFiles} essential files missing! Build aborted.`);
    process.exit(1);
}

// 3. Verify SQLite and Backend Schema
console.log('[3/4] Running Backend & SQLite Engine test validation...');
const testResult = spawnSync(pythonExe, [path.join(projectRoot, 'tools', 'test_backend_and_dashboard.py')], {
    encoding: 'utf-8',
    cwd: projectRoot
});

if (testResult.status !== 0) {
    console.error('\x1b[31m[FAIL]\x1b[0m Backend test suite failed:');
    console.error(testResult.stdout || '');
    console.error(testResult.stderr || '');
    process.exit(1);
} else {
    console.log('  \x1b[32m[PASS]\x1b[0m Backend endpoints, SQLite schema, and CRUD verified successfully.');
}

// 4. Verification completed
console.log('[4/4] Finalizing build checks...');
console.log('\x1b[32m%s\x1b[0m', '=======================================================');
console.log('\x1b[32m%s\x1b[0m', '   BUILD SUCCESSFUL! STMS is ready for development.');
console.log('\x1b[32m%s\x1b[0m', '   Run "npm run dev" to start all services.');
console.log('\x1b[32m%s\x1b[0m', '=======================================================');
process.exit(0);
