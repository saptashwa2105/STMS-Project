import time
import datetime
import json
import urllib.request
import plotly.graph_objects as go
import streamlit as st

# -------------------------------------------------------------
# Page Configuration
# -------------------------------------------------------------
st.set_page_config(
    layout="wide",
    page_title="Smart Traffic Dashboard",
    page_icon="🚦",
    initial_sidebar_state="collapsed"
)

# Custom Styling for polished dashboard aesthetic
st.markdown("""
<style>
    .metric-card {
        background-color: #1e293b;
        border-radius: 8px;
        padding: 12px;
        border: 1px solid #334155;
    }
    .phase-badge-green {
        background-color: #065f46;
        color: #34d399;
        padding: 6px 14px;
        border-radius: 6px;
        font-weight: 700;
        display: inline-block;
        font-size: 1.1rem;
        letter-spacing: 0.05em;
    }
    .phase-badge-yellow {
        background-color: #78350f;
        color: #fcd34d;
        padding: 6px 14px;
        border-radius: 6px;
        font-weight: 700;
        display: inline-block;
        font-size: 1.1rem;
        letter-spacing: 0.05em;
    }
    .phase-badge-red {
        background-color: #7f1d1d;
        color: #f87171;
        padding: 6px 14px;
        border-radius: 6px;
        font-weight: 700;
        display: inline-block;
        font-size: 1.1rem;
        letter-spacing: 0.05em;
    }
</style>
""", unsafe_allow_html=True)

# -------------------------------------------------------------
# Data Fetching
# -------------------------------------------------------------
BACKEND_URL = "http://127.0.0.1:8000/api/stats"

data = None
fetch_error = None

try:
    req = urllib.request.Request(BACKEND_URL, headers={"User-Agent": "STMS-Dashboard/1.0"})
    with urllib.request.urlopen(req, timeout=1.8) as resp:
        if resp.status == 200:
            data = json.loads(resp.read().decode("utf-8"))
        else:
            fetch_error = f"Backend returned HTTP {resp.status}"
except Exception:
    fetch_error = "Waiting for Backend Server..."

# -------------------------------------------------------------
# Header Section
# -------------------------------------------------------------
header_col1, header_col2 = st.columns([3, 1])

with header_col1:
    st.title("🚦 Smart Traffic Management System")
    st.caption("Live Cloud Ingestion & Digital Twin Telemetry Monitor")

with header_col2:
    if data is not None and not fetch_error:
        st.success("🟢 Backend Connected (127.0.0.1:8000)")
    else:
        st.warning("🟡 Waiting for Backend Server...")

st.markdown("---")

# -------------------------------------------------------------
# Dashboard Display Logic
# -------------------------------------------------------------
if fetch_error or data is None:
    st.warning("⚠️ Waiting for Backend Server... (Ensure FastAPI is running on http://127.0.0.1:8000)")
    st.info("💡 To start the backend, run: `run_backend.bat` or `python -m uvicorn backend.main:app --port 8000`")
elif len(data) == 0:
    st.info("📡 Backend is online. Waiting for initial telemetry from Godot 3D simulation...")
    st.write("Launch the Godot simulation using `run_simulation.bat`.")
else:
    # Latest record (last element of sorted ascending array)
    latest = data[-1]
    prev = data[-2] if len(data) >= 2 else latest

    # 1. Alert Banner for Emergency Vehicle Preemption
    is_emergency = latest.get("emergency_active", False)
    if is_emergency:
        st.error("🚨 EMERGENCY PREEMPTION ACTIVE - GREEN CORRIDOR INITIATED")

    # 2. Current Signal State
    current_phase = latest.get("current_phase", "UNKNOWN")
    phase_class = "phase-badge-red"
    if "GREEN" in current_phase:
        phase_class = "phase-badge-green"
    elif "YELLOW" in current_phase:
        phase_class = "phase-badge-yellow"

    c_phase1, c_phase2 = st.columns([2, 2])
    with c_phase1:
        st.markdown(
            f"**Current Signal Phase:** <span class='{phase_class}'>{current_phase}</span>",
            unsafe_allow_html=True
        )
    with c_phase2:
        record_time = datetime.datetime.fromtimestamp(latest.get("timestamp", time.time())).strftime("%H:%M:%S")
        st.markdown(f"**Last Telemetry Tick:** `{record_time}` | **Window:** `{len(data)} records (last 60s)`")

    st.write("")

    # 3. Top Row: KPI Metrics (North, South, East, West)
    col_n, col_s, col_e, col_w = st.columns(4)

    with col_n:
        st.metric(
            label="North Lane Queue",
            value=f"{latest.get('north', 0)} veh",
            delta=f"{latest.get('north', 0) - prev.get('north', 0)} vs prev"
        )
    with col_s:
        st.metric(
            label="South Lane Queue",
            value=f"{latest.get('south', 0)} veh",
            delta=f"{latest.get('south', 0) - prev.get('south', 0)} vs prev"
        )
    with col_e:
        st.metric(
            label="East Lane Queue",
            value=f"{latest.get('east', 0)} veh",
            delta=f"{latest.get('east', 0) - prev.get('east', 0)} vs prev"
        )
    with col_w:
        st.metric(
            label="West Lane Queue",
            value=f"{latest.get('west', 0)} veh",
            delta=f"{latest.get('west', 0) - prev.get('west', 0)} vs prev"
        )

    st.write("")

    # 4. Live Chart: 4 Lane Densities Over Time
    time_strs = []
    north_counts = []
    south_counts = []
    east_counts = []
    west_counts = []

    for i, r in enumerate(data):
        ts = r.get("timestamp")
        if ts:
            time_strs.append(datetime.datetime.fromtimestamp(ts).strftime("%H:%M:%S"))
        else:
            time_strs.append(str(i))
        north_counts.append(int(r.get("north", 0) or 0))
        south_counts.append(int(r.get("south", 0) or 0))
        east_counts.append(int(r.get("east", 0) or 0))
        west_counts.append(int(r.get("west", 0) or 0))

    fig = go.Figure()
    fig.add_trace(go.Scatter(x=time_strs, y=north_counts, name="North", line=dict(color="#38bdf8", width=2.5), mode="lines+markers"))
    fig.add_trace(go.Scatter(x=time_strs, y=south_counts, name="South", line=dict(color="#4ade80", width=2.5), mode="lines+markers"))
    fig.add_trace(go.Scatter(x=time_strs, y=east_counts, name="East", line=dict(color="#fbbf24", width=2.5), mode="lines+markers"))
    fig.add_trace(go.Scatter(x=time_strs, y=west_counts, name="West", line=dict(color="#f472b6", width=2.5), mode="lines+markers"))

    fig.update_layout(
        template="plotly_dark",
        hovermode="x unified",
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
        margin=dict(l=20, r=20, t=50, b=20),
        height=380,
        xaxis=dict(showgrid=True, gridcolor="#334155", title="Time (HH:MM:SS)"),
        yaxis=dict(showgrid=True, gridcolor="#334155", title="Vehicle Queue Count"),
        title="📈 Real-Time Lane Density Trends (Rolling 60-Second Window)"
    )

    st.plotly_chart(fig, use_container_width=True)

# -------------------------------------------------------------
# Auto-Refresh Loop (1-second tick)
# -------------------------------------------------------------
time.sleep(1)
st.rerun()
