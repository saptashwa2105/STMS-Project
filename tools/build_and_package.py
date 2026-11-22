import os
import sys
import subprocess
import zipfile
import shutil

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SIMULATION_DIR = os.path.join(PROJECT_ROOT, "simulation")
BUILD_DIR = os.path.join(PROJECT_ROOT, "build")
GODOT_EXE = os.path.join(PROJECT_ROOT, "tools", "godot", "godot_console.exe")

def zip_directory_contents(source_dir, output_zip):
    print(f"[PACKAGING] Creating zip archive: {output_zip}...")
    with zipfile.ZipFile(output_zip, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(source_dir):
            for file in files:
                abs_path = os.path.join(root, file)
                rel_path = os.path.relpath(abs_path, source_dir)
                zf.write(abs_path, rel_path)
    size_mb = os.path.getsize(output_zip) / (1024 * 1024)
    print(f"[PACKAGING] Created {os.path.basename(output_zip)} ({size_mb:.2f} MB)")

def export_project():
    print("=======================================================")
    print("   STMS Godot 4 Automated Export & Packaging Pipeline  ")
    print("=======================================================")

    windows_build_dir = os.path.join(BUILD_DIR, "windows")
    web_build_dir = os.path.join(BUILD_DIR, "web")
    os.makedirs(windows_build_dir, exist_ok=True)
    os.makedirs(web_build_dir, exist_ok=True)

    windows_exe_path = os.path.join(windows_build_dir, "STMS_Simulation.exe")
    web_html_path = os.path.join(web_build_dir, "index.html")

    # 1. Export Windows Desktop
    print("\n[1/4] Exporting 'Windows Desktop'...")
    cmd_win = [
        GODOT_EXE,
        "--headless",
        "--path", SIMULATION_DIR,
        "--export-release", "Windows Desktop",
        os.path.relpath(windows_exe_path, SIMULATION_DIR)
    ]
    res_win = subprocess.run(cmd_win, capture_output=True, text=True)
    print("Godot Output:", res_win.stdout)
    if res_win.stderr:
        print("Godot Stderr:", res_win.stderr)

    if not os.path.exists(windows_exe_path):
        print(f"[ERROR] Windows export failed, executable not found at: {windows_exe_path}")
        sys.exit(1)
    print(f"[SUCCESS] Windows build generated: {windows_exe_path}")

    # 2. Package Windows ZIP
    print("\n[2/4] Zipping Windows Desktop release...")
    windows_zip_path = os.path.join(BUILD_DIR, "STMS_Simulation_Windows_v1.0.zip")
    zip_directory_contents(windows_build_dir, windows_zip_path)

    # 3. Export Web
    print("\n[3/4] Exporting 'Web'...")
    cmd_web = [
        GODOT_EXE,
        "--headless",
        "--path", SIMULATION_DIR,
        "--export-release", "Web",
        os.path.relpath(web_html_path, SIMULATION_DIR)
    ]
    res_web = subprocess.run(cmd_web, capture_output=True, text=True)
    print("Godot Output:", res_web.stdout)
    if res_web.stderr:
        print("Godot Stderr:", res_web.stderr)

    if not os.path.exists(web_html_path):
        print(f"[ERROR] Web export failed, index.html not found at: {web_html_path}")
        sys.exit(1)
    print(f"[SUCCESS] Web build generated: {web_html_path}")

    # 4. Package Web ZIP
    print("\n[4/4] Zipping Web release...")
    web_zip_path = os.path.join(BUILD_DIR, "STMS_Simulation_Web_v1.0.zip")
    zip_directory_contents(web_build_dir, web_zip_path)

    print("\n=======================================================")
    print("   EXPORT & PACKAGING COMPLETE!")
    print(f"   Windows ZIP: {windows_zip_path} ({os.path.getsize(windows_zip_path)/(1024*1024):.2f} MB)")
    print(f"   Web ZIP:     {web_zip_path} ({os.path.getsize(web_zip_path)/(1024*1024):.2f} MB)")
    print("=======================================================")

if __name__ == "__main__":
    export_project()
