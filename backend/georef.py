"""
georef.py – Georeferenzierung von ARKit-Punktwolken
====================================================
Nimmt eine ASCII-PLY-Datei + GPS-Anker und transformiert
die ARKit-Lokalkoordinaten in WGS84 (lon/lat/altitude).

ARKit-Koordinatensystem:
  X  →  rechts (Ost, wenn Gerät nach Norden zeigt)
  Y  →  oben
  Z  →  rückwärts (Süd, wenn Gerät nach Norden zeigt)
  Einheit: Meter

Georef-Formel:
  Δlat  = -Δz / 111_320
  Δlon  = +Δx / (111_320 * cos(lat_rad))
  Δalt  = +Δy
  (Heading-Rotation wird angewendet, falls vorhanden)
"""

import math
import json
import base64
from pathlib import Path
from typing import Optional


# ─── PLY Parser ──────────────────────────────────────────────────────────────

def parse_ply_vertices(ply_text: str) -> list[tuple[float, float, float]]:
    """Parses an ASCII PLY string and returns list of (x, y, z) tuples."""
    lines = ply_text.strip().splitlines()
    in_header = True
    vertex_count = 0
    vertices = []

    for line in lines:
        line = line.strip()
        if in_header:
            if line.startswith("element vertex"):
                vertex_count = int(line.split()[-1])
            if line == "end_header":
                in_header = False
            continue

        parts = line.split()
        if len(parts) >= 3:
            try:
                x, y, z = float(parts[0]), float(parts[1]), float(parts[2])
                vertices.append((x, y, z))
            except ValueError:
                continue

        if len(vertices) >= vertex_count > 0:
            break

    return vertices


# ─── Coordinate Transformation ───────────────────────────────────────────────

def rotate_2d(x: float, z: float, heading_deg: float) -> tuple[float, float]:
    """
    Rotates ARKit (x, z) by the device heading so that
    X always points East and Z always points South in world space.
    heading_deg: true north bearing the device was facing (0° = North).
    """
    theta = math.radians(heading_deg)
    x_rot =  x * math.cos(theta) + z * math.sin(theta)
    z_rot = -x * math.sin(theta) + z * math.cos(theta)
    return x_rot, z_rot


def arkit_to_wgs84(
    vertices: list[tuple[float, float, float]],
    anchor_lat: float,
    anchor_lon: float,
    anchor_alt: float,
    heading_deg: float = 0.0,
) -> list[dict]:
    """
    Converts ARKit local coordinates to WGS84 lon/lat/altitude.

    Returns a list of dicts: {"lon": ..., "lat": ..., "alt": ...}
    """
    lat_rad = math.radians(anchor_lat)

    # Metres per degree
    metres_per_deg_lat = 111_320.0
    metres_per_deg_lon = 111_320.0 * math.cos(lat_rad)

    geo_points = []
    for (x, y, z) in vertices:
        # Apply heading rotation so X=East, Z=South
        x_rot, z_rot = rotate_2d(x, z, heading_deg)

        delta_lat = -z_rot / metres_per_deg_lat   # Z points South → negative Δlat
        delta_lon =  x_rot / metres_per_deg_lon   # X points East  → positive Δlon
        delta_alt =  y                             # Y is up

        geo_points.append({
            "lon": anchor_lon + delta_lon,
            "lat": anchor_lat + delta_lat,
            "alt": anchor_alt + delta_alt,
        })

    return geo_points


# ─── GeoJSON Builder ─────────────────────────────────────────────────────────

def to_geojson(geo_points: list[dict], scan_id: str = "scan") -> dict:
    """Wraps georeferenced points in a GeoJSON FeatureCollection."""
    features = []
    for pt in geo_points:
        features.append({
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [pt["lon"], pt["lat"], pt["alt"]],
            },
            "properties": {"alt": round(pt["alt"], 3)},
        })

    return {
        "type": "FeatureCollection",
        "id": scan_id,
        "features": features,
    }


# ─── Main pipeline function ──────────────────────────────────────────────────

def process_scan_packet(packet: dict) -> dict:
    """
    Full pipeline: JSON scan packet → GeoJSON FeatureCollection.

    packet keys:
      plyBase64   – base64-encoded ASCII PLY
      latitude, longitude, altitude, heading, accuracy, timestamp
    """
    # Decode PLY
    ply_bytes = base64.b64decode(packet["plyBase64"])
    ply_text  = ply_bytes.decode("utf-8")

    # Parse vertices
    vertices = parse_ply_vertices(ply_text)
    print(f"  → {len(vertices):,} vertices parsed from PLY")

    # Georeferenz
    geo_points = arkit_to_wgs84(
        vertices    = vertices,
        anchor_lat  = packet["latitude"],
        anchor_lon  = packet["longitude"],
        anchor_alt  = packet["altitude"],
        heading_deg = packet.get("heading", 0.0),
    )

    scan_id = f"scan_{int(packet.get('timestamp', 0))}"
    return to_geojson(geo_points, scan_id=scan_id)


# ─── CLI usage ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import sys, json

    if len(sys.argv) < 2:
        print("Usage: python georef.py <scan_packet.json>")
        sys.exit(1)

    with open(sys.argv[1]) as f:
        packet = json.load(f)

    result = process_scan_packet(packet)
    out_path = Path(sys.argv[1]).with_suffix(".geojson")
    with open(out_path, "w") as f:
        json.dump(result, f, indent=2)

    print(f"GeoJSON saved to: {out_path}")
    print(f"Total points: {len(result['features']):,}")
