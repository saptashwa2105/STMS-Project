# 🚦 Smart Traffic Management System (STMS) - 3D IoT Digital Twin (v1.1)

A real-time, adaptive 4-way intersection Smart Traffic Management System (STMS) digital twin simulation powered by **Godot 4.3** with **Anti-Gridlock (Yellow Box Junction Rule)** and **Anti-Starvation** algorithms, connected via real-time telemetry to a **Python FastAPI / WebSocket** cloud backend.

---

## 🏗️ System Architecture

```mermaid
graph TD
    subgraph StreamlitUI ["Streamlit Cloud Dashboard (http://localhost:8501)"]
        RemoteControl["🎛️ Remote Control Center (Force Red, EVP, Surge, Auto)"]
    end

    subgraph Backend ["Python FastAPI Cloud Ingestion (http://127.0.0.1:8000)"]
        Ingest["POST /api/telemetry"]
        CmdPost["POST /api/command (Command Dispatcher)"]
        CmdGet["GET /api/command (Command Queue)"]
        SignalOpt["GET /api/signal-state"]
        Metrics["GET /metrics"]
        Stats["GET /api/stats (SQLite traffic.db)"]
        WS["WebSocket /ws (Live Broadcast)"]
    end

    subgraph Godot4 ["Godot 4.3 Simulation (Digital Twin)"]
        Vehicles["3D Vehicles: Passenger Car, Motorbike, Cargo Truck, Ambulance, Fire Truck"]
        YellowBox["IntersectionClearZone Area3D (Anti-Gridlock Yellow Box Rule)"]
        Sensors["Lane Density & Wait-Time Trackers"]
        Signals["4x Traffic Signal Poles (Emissive 3D Mesh)"]
        Controller["TrafficController.gd (Adaptive Timing + Remote Command Poller 1.0s)"]
        EVP["Emergency Vehicle Preemption (EVP) Engine"]
        Bridge["TelemetryBridge.gd (HTTPRequest Dispatcher 1.0s)"]
        HUD["UIOverlay.gd (Real-Time Metrics HUD)"]
    end

    RemoteControl -->|POST /api/command| CmdPost
    CmdPost --> CmdGet
    Controller -->|GET /api/command (1.0s Poller)| CmdGet
    YellowBox -->|Exit Clearance Verification| Vehicles
    Sensors -->|Lane Queue Counts & Wait Times| Controller
    Vehicles -->|EVP Trigger Key A / F| EVP
    EVP -->|Force Green Corridor| Controller
    Controller -->|Signal States (Green, 2.5s Yellow, 1.5s All-Red)| Signals
    Controller -->|Telemetry Payload| Bridge
    Bridge -->|JSON HTTP POST 1.0s| Ingest
    Stats --> StreamlitUI
```

---

## ✨ Key Enhancements in v1.3 (Two-Way Cloud-to-Edge Control)

1. **Bidirectional Cloud-to-Edge Command Remote Override**:
   - **Streamlit Control Center**: Allows dispatching live overrides from the browser (sidebar & quick actions panel).
   - **Interactive Overrides**:
     - 🚨 **Emergency Corridor (EVP)**: Dispatches emergency corridor on target lane (North/South/East/West) and spawns 3D emergency vehicle.
     - 🛑 **Force All Red**: Freezes all signals to RED immediately and halts all incoming traffic.
     - 🚗 **Traffic Surge**: Injects high-density queue burst across lanes to test adaptive signal scaling.
     - ✅ **Resume Auto**: Safely clears overrides and returns control to dynamic adaptive timing.
   - **Non-blocking Polling**: Godot edge simulation polls `GET /api/command` on a 1.0s non-blocking timer and executes commands with fail-safe local fallback if the cloud is offline.

---

## ✨ Key Enhancements in v1.2 (Anti-Gridlock & 3D Procedural Digital Twin)

1. **Active Anti-Gridlock & Yellow Box Junction Rule**:
   - `IntersectionClearZone` (`Area3D`) actively tracks all vehicles in the central intersection box.
   - **Cross-Traffic Clearance Guarantee**: Vehicles approaching on green hold at the stop line if conflicting cross-traffic is still clearing the junction box.
   - **Exit Road Clearance Verification**: `ExitClearRay` verifies that the exit lane has free space, preventing tailbacks into the intersection.
   - **Visual Yellow Box Junction**: Added yellow perimeter border and diagonal crosshatching on the intersection asphalt.

2. **Intelligent Right-Of-Way (ROW) & Anti-Stall Watchdog**:
   - Inside the junction, vehicles accelerate to clearance speed (16.5 m/s).
   - Priority resolution: Emergency vehicles receive absolute right-of-way; earlier entrants have priority; yielding vehicles smoothly pause.
   - Anti-stall watchdog automatically nudges and clears any vehicle stopped inside the intersection for > 2.0s to eliminate all deadlocks.

3. **Safe Emergency Vehicle Preemption (EVP) Clearance Sequence**:
   - When an ambulance or fire engine is dispatched, conflicting green phases undergo a safe **1.8s Yellow ➔ 1.5s All-Red** clearance flush before the Emergency Green Corridor opens.
   - Prevents cut-off collisions when emergency preemption is triggered mid-cycle.

4. **Procedural PBR 3D Vehicles & Visual Improvisations**:
   - **Sedan Cars**: Randomized metallic car paint colors, dark smoked glass windows, chrome grilles, glowing LED headlights & taillights, silver alloy rims, rubber tires.
   - **Cargo Trucks**: Heavy semi cab with radiator grille, huge ribbed freight container with safety stripes, 6 heavy wheels with double rear axles.
   - **Sport Motorbikes**: Streamlined chassis frame, engine block, spoked wheels, handlebars, and 3D rider in racing suit & helmet.
   - **Ambulances**: Pure white medical livery, reflective red side chevrons, medical cross emblems, dual rooftop flashing strobe lightbars with dynamic light emission.
   - **Fire Trucks**: Safety red heavy rescue engine, diamond plate silver steps, roll-up gear doors, roof rescue ladder, dual heavy strobe beacon lightbars.

5. **Enhanced HUD with Live Box Monitoring & Gridlock Flush**:
   - Live **Yellow Box Status** indicator (Clear vs Clearing).
   - Added **🧹 Clear Gridlock** button to instantly reset active traffic if required.

---

## 🚀 How to Run

### Method 1: 1-Click Full Stack Launch
In Command Prompt or PowerShell:
```cmd
cd Desktop\PROJECT\STMS
run_all.bat
```

### Method 2: Running with NPM
You can run build verification and start development servers using standard npm scripts:
```cmd
npm run build    # Verifies database, API schema, and system components
npm run dev      # Launches FastAPI backend (port 8000) & Streamlit UI (port 8501)
npm run simulation # Launches Godot 4 3D Digital Twin simulation
```

### Method 3: Running in Separate Terminals
1. **Start Backend Server**:
   ```cmd
   cd Desktop\PROJECT\STMS
   run_backend.bat
   ```
   Open **`http://127.0.0.1:8000`** in your browser for the live dashboard.

2. **Start Godot 4 3D Simulation**:
   ```cmd
   cd Desktop\PROJECT\STMS
   run_simulation.bat
   ```

---

## 🎮 Keyboard & Mouse Controls

| Key / Control | Action | Function |
|---|---|---|
| `A` | **Spawn Ambulance** | Dispatches ambulance, triggers EVP Green Corridor |
| `F` | **Spawn Fire Truck** | Dispatches fire engine, overrides conflicting signals |
| `R` | **Traffic Surge Burst** | Injects high-density queue burst to test 35s adaptive scaling |
| `C` | **Cycle Camera Mode** | Toggles Isometric 45°, Top-Down Orthogonal, and Close Cinematic |
| `RMB + Drag` | **Free 3D Orbit** | Rotates camera around intersection |
| `Mouse Scroll`| **Zoom In / Out** | Adjusts camera distance |

---

## 🧪 Automated Test Verification

Run the automated test suite headlessly:
```cmd
.\tools\godot\godot_console.exe --headless --path simulation -s tests/test_simulation.gd
```
