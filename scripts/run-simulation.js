const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const projectRoot = path.resolve(__dirname, '..');
const godotExe = path.join(projectRoot, 'tools', 'godot', 'godot.exe');

if (!fs.existsSync(godotExe)) {
    console.error(`Godot executable not found at ${godotExe}`);
    process.exit(1);
}

console.log('Launching Godot 4 3D Digital Twin Simulation...');
const proc = spawn(godotExe, ['--path', 'simulation'], {
    cwd: projectRoot,
    stdio: 'inherit'
});

proc.on('exit', (code) => process.exit(code || 0));
