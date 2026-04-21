"""
api.py – FastAPI Backend für GeoLiDAR Scout
============================================
Empfängt Scan-Pakete vom iPhone, georeferenziert sie
und gibt GeoJSON zurück.

Start: uvicorn api:app --reload --host 0.0.0.0 --port 8000
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from pathlib import Path
import json
import time

from georef import process_scan_packet

app = FastAPI(title="GeoLiDAR Scout API", version="0.1.0")

# Allow requests from the GitHub Pages frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Directory where processed GeoJSON files are stored
SCANS_DIR = Path(__file__).parent / "processed_scans"
SCANS_DIR.mkdir(exist_ok=True)

# Serve processed scans as static files
app.mount("/scans", StaticFiles(directory=str(SCANS_DIR)), name="scans")


# ─── Request Model ────────────────────────────────────────────────────────────

class ScanPacket(BaseModel):
    plyBase64:   str
    latitude:    float
    longitude:   float
    altitude:    float
    heading:     float = 0.0
    accuracy:    float = 0.0
    timestamp:   float = 0.0
    deviceModel: str   = "unknown"


# ─── Endpoints ────────────────────────────────────────────────────────────────

@app.get("/")
def root():
    return {"status": "GeoLiDAR Scout API running", "version": "0.1.0"}


@app.post("/scan")
def receive_scan(packet: ScanPacket):
    """
    Receives a scan packet from the iOS app,
    runs georeferencing, saves GeoJSON, returns its URL.
    """
    try:
        packet_dict = packet.model_dump()
        geojson     = process_scan_packet(packet_dict)
    except Exception as e:
        raise HTTPException(status_code=422, detail=f"Georeferencing failed: {e}")

    # Save GeoJSON
    scan_id  = f"scan_{int(packet.timestamp or time.time())}"
    out_path = SCANS_DIR / f"{scan_id}.geojson"
    with open(out_path, "w") as f:
        json.dump(geojson, f)

    return {
        "scan_id":    scan_id,
        "points":     len(geojson["features"]),
        "geojson_url": f"/scans/{scan_id}.geojson",
    }


@app.get("/scans")
def list_scans():
    """Lists all available processed scans."""
    files = sorted(SCANS_DIR.glob("*.geojson"), key=lambda p: p.stat().st_mtime, reverse=True)
    return [
        {"scan_id": f.stem, "url": f"/scans/{f.name}"}
        for f in files
    ]
