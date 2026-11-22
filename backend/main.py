import os
import time
from typing import Dict, Any, List, Optional
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, Float, String, Boolean
from sqlalchemy.orm import declarative_base, sessionmaker, Session

# -------------------------------------------------------------
# Database Setup (SQLAlchemy + SQLite: traffic.db)
# -------------------------------------------------------------
DB_DIR = os.path.dirname(os.path.abspath(__file__))
DB_FILE = os.path.join(DB_DIR, "traffic.db")
DATABASE_URL = f"sqlite:///{DB_FILE}"

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class TrafficLog(Base):
    """
    Schema for TrafficLog in SQLite traffic.db
    Columns: id (PK), timestamp (Float), north (Int), south (Int),
             east (Int), west (Int), current_phase (String), emergency_active (Boolean)
    """
    __tablename__ = "traffic_logs"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    timestamp = Column(Float, nullable=False, default=time.time)
    north = Column(Integer, nullable=False, default=0)
    south = Column(Integer, nullable=False, default=0)
    east = Column(Integer, nullable=False, default=0)
    west = Column(Integer, nullable=False, default=0)
    current_phase = Column(String, nullable=False, default="NS_GREEN")
    emergency_active = Column(Boolean, nullable=False, default=False)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "timestamp": self.timestamp,
            "north": self.north,
            "south": self.south,
            "east": self.east,
            "west": self.west,
            "current_phase": self.current_phase,
            "emergency_active": bool(self.emergency_active),
        }

# Automatically create tables if not present
Base.metadata.create_all(bind=engine)

# -------------------------------------------------------------
# FastAPI Application & Middleware
# -------------------------------------------------------------
app = FastAPI(
    title="STMS Fail-Safe Telemetry Backend",
    description="Crash-proof cloud ingestion API for Godot 3D digital twin telemetry",
    version="1.0.0"
)

# Enable CORS for all origins to prevent connection blocking
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -------------------------------------------------------------
# Endpoints
# -------------------------------------------------------------
@app.get("/")
def health_check():
    return {
        "status": "online",
        "service": "STMS Fail-Safe Backend API",
        "database": DB_FILE,
        "endpoints": {
            "POST": "/api/telemetry",
            "GET": "/api/stats"
        }
    }

@app.post("/api/telemetry")
async def ingest_telemetry(request: Request):
    """
    Receives JSON payload from Godot.
    MUST include try/except block. If malformed data is sent,
    returns 400 gracefully without crashing the uvicorn server.
    Saves valid payload to traffic.db.
    """
    try:
        data = await request.json()
        if not isinstance(data, dict):
            return JSONResponse(
                status_code=status.HTTP_400_BAD_REQUEST,
                content={"status": "error", "message": "Payload must be a valid JSON object"}
            )

        # Support both Godot's nested lane_densities format and flat format
        if "lane_densities" in data and isinstance(data["lane_densities"], dict):
            densities = data["lane_densities"]
            north = int(densities.get("north", 0))
            south = int(densities.get("south", 0))
            east = int(densities.get("east", 0))
            west = int(densities.get("west", 0))
        else:
            north = int(data.get("north", 0))
            south = int(data.get("south", 0))
            east = int(data.get("east", 0))
            west = int(data.get("west", 0))

        ts = float(data.get("timestamp", time.time()))
        phase = str(data.get("current_phase", "UNKNOWN"))
        emerg = bool(data.get("emergency_active", False))

        # Save to SQLite database
        db: Session = SessionLocal()
        try:
            log_entry = TrafficLog(
                timestamp=ts,
                north=north,
                south=south,
                east=east,
                west=west,
                current_phase=phase,
                emergency_active=emerg
            )
            db.add(log_entry)
            db.commit()
            db.refresh(log_entry)
            saved_id = log_entry.id
        finally:
            db.close()

        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "status": "success",
                "message": "Telemetry saved to traffic.db",
                "id": saved_id
            }
        )

    except Exception as exc:
        return JSONResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            content={
                "status": "error",
                "message": f"Malformed payload or error processing telemetry: {str(exc)}"
            }
        )

@app.get("/api/stats")
def get_stats():
    """
    Returns the latest 60 records (representing the last 1 minute of telemetry at 1 tick/sec)
    sorted by timestamp ascending.
    """
    try:
        db: Session = SessionLocal()
        try:
            # Query last 60 records by id descending, then reverse for ascending timestamp order
            logs = db.query(TrafficLog).order_by(TrafficLog.id.desc()).limit(60).all()
            records = [log.to_dict() for log in reversed(logs)]
            return JSONResponse(status_code=status.HTTP_200_OK, content=records)
        finally:
            db.close()
    except Exception as exc:
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"status": "error", "message": f"Database error: {str(exc)}"}
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.main:app", host="127.0.0.1", port=8000, reload=True)
