import io
import urllib.request
import zipfile
import os
import sys

URL = "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz"
TOTAL_SIZE = 1073228327

class CachedRangeFile(io.RawIOBase):
    def __init__(self, url, size, block_size=4*1024*1024):
        self.url = url
        self.size = size
        self.block_size = block_size
        self.pos = 0
        self.cache_start = 0
        self.cache_data = b""

    def readable(self):
        return True

    def seekable(self):
        return True

    def seek(self, offset, whence=io.SEEK_SET):
        if whence == io.SEEK_SET:
            self.pos = offset
        elif whence == io.SEEK_CUR:
            self.pos += offset
        elif whence == io.SEEK_END:
            self.pos = self.size + offset
        self.pos = max(0, min(self.pos, self.size))
        return self.pos

    def tell(self):
        return self.pos

    def readinto(self, b):
        if self.pos >= self.size:
            return 0
        
        # Check if current pos is within cache
        if not (self.cache_start <= self.pos < self.cache_start + len(self.cache_data)):
            # Fetch a new block into cache
            fetch_size = max(len(b), self.block_size)
            end = min(self.pos + fetch_size - 1, self.size - 1)
            req = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{end}"})
            with urllib.request.urlopen(req) as resp:
                self.cache_data = resp.read()
            self.cache_start = self.pos

        # Read from cache
        offset = self.pos - self.cache_start
        available = len(self.cache_data) - offset
        to_read = min(len(b), available)
        b[:to_read] = self.cache_data[offset:offset+to_read]
        self.pos += to_read
        return to_read

def install_templates(godot_version="4.3.stable"):
    appdata = os.environ.get("APPDATA")
    if not appdata:
        print("[ERROR] APPDATA environment variable not found.")
        sys.exit(1)

    target_dir = os.path.join(appdata, "Godot", "export_templates", godot_version)
    os.makedirs(target_dir, exist_ok=True)
    print(f"[INFO] Target export templates directory: {target_dir}")

    # Check if templates are already present
    win_template = os.path.join(target_dir, "windows_release_x86_64.exe")
    web_template = os.path.join(target_dir, "web_release.zip")
    if os.path.exists(win_template) and os.path.exists(web_template):
        print(f"[OK] Templates for {godot_version} are already installed.")
        return target_dir

    print(f"[INFO] Downloading export templates for Godot {godot_version} directly from official GitHub release...")
    raw_file = CachedRangeFile(URL, TOTAL_SIZE, block_size=4*1024*1024)
    zf = zipfile.ZipFile(raw_file)

    # We need Windows, Web, and version.txt
    needed_prefixes = ("templates/windows_", "templates/web_", "templates/version.txt")
    members_to_extract = [m for m in zf.namelist() if any(m.startswith(p) for p in needed_prefixes)]
    
    print(f"[INFO] Found {len(members_to_extract)} relevant template files to install:")
    for m in members_to_extract:
        base_name = m.replace("templates/", "")
        dest_path = os.path.join(target_dir, base_name)
        if os.path.exists(dest_path):
            print(f"  [EXISTS] {base_name}")
            continue
        
        info = zf.getinfo(m)
        print(f"  [EXTRACTING] {base_name} ({info.file_size / 1024 / 1024:.2f} MB)...", end=" ", flush=True)
        content = zf.read(m)
        with open(dest_path, "wb") as f_out:
            f_out.write(content)
        print("DONE")

    print("[SUCCESS] All Windows and Web export templates installed successfully!")
    return target_dir

if __name__ == "__main__":
    install_templates()
