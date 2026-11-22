# 🚦 Smart Traffic Management System (STMS)

> **An End-to-End 3D IoT Digital Twin & Cloud-Controlled Traffic Simulation**  
> Powered by **Godot Engine 4.3**, **Python FastAPI**, **Neon Serverless PostgreSQL**, and **Streamlit**.

[![Godot 4](https://img.shields.io/badge/Godot_4.3-478CBF?style=for-the-badge&logo=godotengine&logoColor=white)](https://godotengine.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Python](https://img.shields.io/badge/Python_3.11+-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Neon](https://img.shields.io/badge/Neon_Serverless-00E599?style=for-the-badge&logo=postgresql&logoColor=black)](https://neon.tech/)
[![Streamlit](https://img.shields.io/badge/Streamlit-FF4B4B?style=for-the-badge&logo=streamlit&logoColor=white)](https://streamlit.io/)
[![Render](https://img.shields.io/badge/Render-46E3B7?style=for-the-badge&logo=render&logoColor=black)](https://render.com/)
[![WebAssembly](https://img.shields.io/badge/WebAssembly-654FF0?style=for-the-badge&logo=webassembly&logoColor=white)](https://webassembly.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

---

## 🌐 Live Deployments & Playable Links

Experience the full-stack system live without installing anything locally:

| Component | Target Platform | Link | Description |
| :--- | :--- | :--- | :--- |
| **🎮 3D Digital Twin (Web)** | Any Browser / itch.io | [**Play in Browser**](https://saptashwa2105.itch.io/smart-traffic-management-system-stms) | Single-threaded WebAssembly / HTML5 build running directly in browser |
| **💻 3D Digital Twin (Desktop)** | Windows 64-bit | [**Download Windows `.exe`**](https://github.com/saptashwa2105/STMS-Project/releases/latest) | High-performance native build with standalone `.pck` packaging |
| **📱 Live Control Dashboard** | Mobile & Desktop Web | [**Open Cloud Dashboard**](https://stms-dashboard.onrender.com) | Real-time analytics, queue monitoring & remote cloud overrides |
| **⚡ Backend API & Swagger** | Cloud API (Render) | [**Swagger Interactive Docs**](https://stms-project-l3vl.onrender.com/docs) | Live FastAPI REST endpoints, OpenAPI schemas & health probes |

> ### 💡 How to Try the Cloud-to-Edge Loop Live:
> 1. Launch the **3D Simulation** on your laptop (either via [itch.io in browser](https://saptashwa2105.itch.io/smart-traffic-management-system-stms) or the [Windows `.exe`](https://github.com/saptashwa2105/STMS-Project/releases/latest)).
> 2. Open the **[Live Control Dashboard](https://stms-dashboard.onrender.com)** on your smartphone or in a side-by-side browser window.
> 3. Click **"Trigger Emergency Corridor"**, **"Force All Red"**, or **"Inject Traffic Surge"** on your phone.
> 4. Watch the 3D edge simulation respond dynamically across the cloud in **< 50 milliseconds**!

---

## 🎬 Demo

<!-- DROP DEMO VIDEO / SIDE-BY-SIDE GIF HERE (e.g. ![STMS Live Demo](assets/demo.gif)) -->
> *Side-by-side smartphone remote control + laptop 3D digital twin video demonstration coming soon.*

---

## 🏗️ System Architecture

```mermaid
flowchart TD
    subgraph OperatorLayer ["📱 Operator & Analytics Layer (Cloud)"]
        Streamlit["Streamlit Live Dashboard<br/>(Render Cloud)<br/>• Real-Time Queue Analytics<br/>• Remote Traffic Control Center"]
    end

    subgraph CloudLayer ["☁️ Cloud API Layer (Render)"]
        FastAPI["FastAPI High-Performance Gateway<br/>• CORS Enabled (*)<br/>• Non-blocking REST Endpoints"]
        CommandQueue["⚡ In-Memory Command Queue<br/>(collections.deque)<br/>• Sub-10ms Dispatch<br/>• Atomic Pop & Zero Drops"]
        DBEngine["SQLAlchemy Engine<br/>(Connection Pooling)"]
    end

    subgraph DataLayer ["🗄️ Persistence Layer (Serverless Cloud)"]
        NeonDB[("Neon PostgreSQL<br/>(Serverless Database)<br/>• Historical Telemetry Logs<br/>• Analytics Time-Series")]
    end

    subgraph EdgeLayer ["🚦 Edge Digital Twin Layer (Godot 4.3)"]
        subgraph GodotClient ["Godot 4 Client (Windows .exe / WebAssembly)"]
            SimController["TrafficController.gd<br/>• Adaptive Timing & Mutex Locks<br/>• Anti-Gridlock Yellow Box<br/>• Anti-Starvation Watchdog"]
            EVP["Emergency Vehicle Preemption<br/>(EVP Green Corridors)"]
            
            subgraph DualHTTP ["Dual Dedicated HTTPRequest Nodes"]
                TelemNode["TelemetryBridge HTTPRequest<br/>(POST /api/telemetry @ 1.8s)"]
                CmdNode["CommandPoller HTTPRequest<br/>(GET /api/commands @ 0.5s)"]
            end
        end
    end

    %% Flow interactions
    Streamlit -->|1. POST /api/command<br/>(Force Red, EVP, Surge, Auto)| FastAPI
    FastAPI -->|2. Instant Push (<10ms)| CommandQueue
    FastAPI -->|3. Async Telemetry Log| DBEngine
    DBEngine --> NeonDB
    NeonDB -.->|Historical Stats Query| Streamlit

    CmdNode -->|4. High-Frequency Poll (0.5s)| CommandQueue
    CommandQueue -->|5. Atomic Drain & Deliver| SimController
    SimController --> EVP

    SimController -->|6. Intersection Metrics| TelemNode
    TelemNode -->|7. Telemetry Dispatch (1.8s)| FastAPI
```

---

## ⚡ Key Engineering Highlights

### 1. Low-Latency Two-Way Control (< 10ms Dispatch)
- **Problem**: Querying or writing remote commands directly to a relational cloud database introduces round-trip network latency (50–150ms) and database transaction overhead.
- **Solution**: Implemented an in-memory `collections.deque(maxlen=200)` command queue inside FastAPI. When an operator triggers an emergency corridor or all-red freeze from Streamlit, the command is queued in memory in under 1 millisecond.
- **Result**: Sub-10ms cloud dispatch latency while telemetry logging remains safely persisted in Neon Serverless PostgreSQL.

### 2. Zero-Drop Concurrency in Godot Engine
- **Problem**: In Godot 4, calling `request()` on an `HTTPRequest` node while another request is in flight throws `ERR_BUSY` (code 4), causing dropped commands or failed telemetry transmissions.
- **Solution**:
  - Architected **two completely decoupled `HTTPRequest` nodes**: one dedicated solely to telemetry dispatch (`POST /api/telemetry` every 1.8s) and the second dedicated solely to command polling (`GET /api/commands` every 0.5s).
  - Implemented client-side connection status guards (`HTTPClient.STATUS_DISCONNECTED`) and batch queue execution (`_process_single_command_data`) to pop and execute multiple pending commands atomically without drops.

### 3. Smart Edge Intersection Logic
- **Anti-Gridlock (Yellow Box Junction Rule)**: An active `Area3D` clear zone monitors vehicles inside the intersection box. Vehicles approaching on a green signal hold at the stop line if downstream traffic is blocking their exit road.
- **Anti-Starvation Watchdog**: Cumulative wait timers track queues across all lanes. If a low-priority lane is starved past threshold, the controller automatically forces an adaptive phase cycle.
- **Emergency Vehicle Preemption (EVP)**: Ambulances and fire engines trigger an instantaneous priority preemption. Conflicting phases execute a safe **1.8s Yellow ➔ 1.5s All-Red** clearance flush before opening the dedicated emergency green corridor.
- **Intersection Mutex Lock**: Strict enum state machine (`FREE`, `NS_ACTIVE`, `EW_ACTIVE`) prevents conflicting green phases under all concurrent conditions.

### 4. Cross-Platform Edge Delivery Pipeline
- Built a fully automated headless export and packaging pipeline ([`tools/build_and_package.py`](tools/build_and_package.py)) utilizing official Godot 4.3 export templates.
- **Windows Desktop**: Standalone native 64-bit executable published directly to [GitHub Releases](https://github.com/saptashwa2105/STMS-Project/releases/latest).
- **WebAssembly (HTML5)**: Single-threaded WASM build (`variant/thread_support=false`) hosted on [itch.io](https://saptashwa2105.itch.io/smart-traffic-management-system-stms) that runs seamlessly in any modern mobile or desktop browser without requiring COOP/COEP isolation headers.

---

## 📁 Repository Structure

```text
STMS-Project/
├── backend/                        # FastAPI Cloud Service
│   ├── main.py                     # Main API: endpoints, CORS, in-memory deque, SQLAlchemy models
│   ├── app.py                      # WebSocket & telemetry processing helpers
│   ├── requirements.txt            # Backend dependencies (fastapi, uvicorn, sqlalchemy, psycopg)
│   └── traffic.db                  # Local development SQLite database (git-ignored)
├── dashboard/                      # Streamlit Analytics & Remote Control UI
│   ├── app.py                      # Real-time charts, metrics cards, cloud-to-edge control panel
│   └── requirements.txt            # Dashboard dependencies (streamlit, plotly, pandas)
├── simulation/                     # Godot 4 3D Digital Twin Project
│   ├── project.godot               # Godot 4.3 project configuration
│   ├── export_presets.cfg          # Export presets for Windows Desktop & WebAssembly
│   ├── scenes/                     # 3D Scenes (MainIntersection, Vehicle, TrafficLightPole, UIOverlay)
│   ├── scripts/
│   │   ├── TrafficController.gd    # Signal state machine, EVP, anti-starvation, command polling
│   │   ├── TelemetryBridge.gd      # Non-blocking telemetry dispatcher (POST /api/telemetry)
│   │   ├── IntersectionClearZone.gd# Yellow Box junction anti-gridlock tracker
│   │   ├── VehicleSpawner.gd       # Dynamic traffic generation & vehicle pooling
│   │   └── Vehicle.gd              # Vehicle physics, waypoint steering, raycast avoidance
│   └── assets/models/              # 3D procedural OBJ models (Car, Truck, Bike, Ambulance, Firetruck)
├── tools/                          # Automation & Testing Tools
│   ├── build_and_package.py        # Automated headless build & zip pipeline for Windows and Web
│   ├── install_export_templates.py # Auto-installer for official Godot 4.3 export templates
│   ├── test_backend_and_dashboard.py # Complete backend unit & integration test suite
│   └── fetch_or_build_assets.py    # Procedural 3D model generation pipeline
├── .gitignore                      # Air-tight security & build artifact exclusions
├── package.json                    # Development script runner & build verification
├── run_all.bat                     # 1-Click launcher for full local stack
├── run_backend.bat                 # Local FastAPI server runner
├── run_dashboard.bat               # Local Streamlit dashboard runner
└── run_simulation.bat              # Local Godot simulation runner
```

---

## 🛠️ Local Development & Quick Start

### Prerequisites
- **Python 3.10+**
- **Godot Engine 4.3** (Standard 64-bit)

### 1. Clone & Set Up Virtual Environment
```bash
git clone https://github.com/saptashwa2105/STMS-Project.git
cd STMS-Project

# Create and activate virtual environment
python -m venv .venv
# Windows:
.venv\Scripts\activate
# Linux/macOS:
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Environment Variables (Optional)
The system runs out-of-the-box locally with SQLite fallbacks. To connect to cloud databases or endpoints, create a `.env` file in the root:
```env
# Optional: Neon Serverless PostgreSQL connection string (defaults to local SQLite if omitted)
DATABASE_URL=postgresql://user:password@ep-cool-sample.region.neon.tech/stms?sslmode=require

# Optional: Point Streamlit dashboard to a custom backend (defaults to http://127.0.0.1:8000)
API_BASE_URL=http://127.0.0.1:8000
```

### 3. Launching Services Locally

#### Option A: 1-Click Launch (Windows)
Double-click `run_all.bat` or run:
```cmd
run_all.bat
```

#### Option B: Terminal-by-Terminal
1. **Start the FastAPI Backend**:
   ```bash
   uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
   ```
   *Swagger Docs: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)*

2. **Start the Streamlit Control Dashboard**:
   ```bash
   streamlit run dashboard/app.py --server.port 8501
   ```
   *Dashboard UI: [http://localhost:8501](http://localhost:8501)*

3. **Launch the Godot 4 3D Simulation**:
   ```bash
   # Using Godot console binary
   .\tools\godot\godot_console.exe --path simulation
   # Or open simulation/project.godot directly in Godot 4.3 Editor
   ```

---

## 🎮 Simulation Keyboard Controls

When running the desktop simulation, you can interact with the intersection manually:

| Key / Input | Action | Description |
| :--- | :--- | :--- |
| **`A`** | **Spawn Ambulance** | Dispatches emergency ambulance; triggers EVP Green Corridor |
| **`F`** | **Spawn Fire Truck** | Dispatches heavy fire engine; forces emergency preemption |
| **`R`** | **Traffic Surge Burst** | Injects high-density vehicle burst to test adaptive signal scaling |
| **`C`** | **Toggle Camera Mode** | Cycles: 45° High Isometric ➔ Top-Down Orthogonal ➔ Close Cinematic |
| **`RMB + Drag`** | **Free 3D Orbit** | Rotates camera freely around the intersection |
| **`Scroll Wheel`** | **Zoom In / Out** | Adjusts camera elevation and distance |

---

## 🧪 Automated Testing & Verification

Run the full end-to-end backend test suite (validates database CRUD, schema, endpoints, and in-memory queue):
```bash
python tools/test_backend_and_dashboard.py
```

Run the headless Godot simulation test suite (validates vehicle orientations, EVP sequence, yellow box clearance, and remote commands):
```bash
.\tools\godot\godot_console.exe --headless --path simulation -s tests/test_simulation.gd
```

---

## 📜 License

This project is open-source under the [MIT License](https://opensource.org/licenses/MIT).
