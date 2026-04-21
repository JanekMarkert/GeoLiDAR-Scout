# 🛰 GeoLiDAR Scout

> iPhone 14 Pro LiDAR-Punktwolken georeferenziert auf einer interaktiven Webkarte.

**Live Demo:** [https://DEIN-USERNAME.github.io/GeoLiDAR-Scout/frontend/](https://DEIN-USERNAME.github.io/GeoLiDAR-Scout/frontend/)

---

## Was ist das?

GeoLiDAR Scout verbindet das iPhone als mobilen Geodaten-Sensor mit einer Webkarte.
Die iOS-App scannt die Umgebung mit ARKit LiDAR, taggt die Punktwolke mit GPS und sendet sie an ein Python-Backend. Das Backend georeferenziert die Wolke in WGS84 – danach erscheint sie an ihrer echten Position auf der Erde, direkt im Browser.

```
iPhone 14 Pro
  └─ ARKit LiDAR Scan (.ply)
  └─ GPS-Anker (CoreLocation)
       │
       ▼
Python Backend (FastAPI + Open3D)
  └─ Koordinatentransformation ARKit → WGS84
  └─ GeoJSON Export
       │
       ▼
Web Frontend (deck.gl + Mapbox)
  └─ 3D Punktwolke auf interaktiver Karte
  └─ GitHub Pages Live-Demo
```

---

## Repo-Struktur

```
GeoLiDAR-Scout/
├── ios-app/                    ← Swift · ARKit · CoreLocation
│   └── Sources/GeoLiDARScout/
│       ├── ARLiDARManager.swift
│       ├── LocationManager.swift
│       ├── ScanExporter.swift
│       └── ContentView.swift
├── backend/                    ← Python · FastAPI
│   ├── georef.py               Georeferenzierungslogik
│   ├── api.py                  REST-API
│   └── requirements.txt
├── frontend/                   ← HTML · deck.gl · Mapbox GL JS
│   └── index.html              Live-Demo (GitHub Pages)
├── example-scans/              ← Fertige GeoJSON-Scans für Demo
│   ├── bht_campus.geojson
│   └── treppe.geojson
└── README.md
```

---

## Setup

### 1. iOS App

Voraussetzungen: Xcode 15+, iPhone 14 Pro (LiDAR erforderlich)

1. Xcode öffnen → *Open a project or file* → `ios-app/` wählen
2. Signing: *Targets → GeoLiDARScout → Signing & Capabilities → Team* setzen (Free Account reicht)
3. iPhone per USB verbinden, als Zielgerät auswählen
4. `⌘ R` zum Starten

In `ScanExporter.swift` die `baseURL` auf deine Backend-IP anpassen (s.u.).

### 2. Python Backend

```bash
cd backend
pip install -r requirements.txt
uvicorn api:app --reload --host 0.0.0.0 --port 8000
```

iPhone und Mac müssen im selben WLAN sein.
IP des Macs herausfinden: `ifconfig | grep "inet 192"`

### 3. Frontend (Live Demo)

1. In `frontend/index.html` deinen Mapbox-Token eintragen (kostenlos auf mapbox.com)
2. GitHub Pages aktivieren: *Settings → Pages → Source: main branch → /frontend*
3. Demo-URL: `https://DEIN-USERNAME.github.io/GeoLiDAR-Scout/frontend/`

Die Demo läuft auch offline mit den Beispiel-Scans aus `example-scans/`.

---

## GitHub auf der Kommandozeile einrichten

```bash
# Im GeoLiDAR-Scout Ordner:
git init
git add .
git commit -m "Initial commit: GeoLiDAR Scout"
git branch -M main
git remote add origin https://github.com/DEIN-USERNAME/GeoLiDAR-Scout.git
git push -u origin main
```

---

## Technologie-Stack

| Schicht | Technologie |
|---------|-------------|
| iOS App | Swift 5.9, ARKit (Scene Reconstruction), CoreLocation, SwiftUI |
| Backend | Python 3.11, FastAPI, Open3D, NumPy |
| Frontend | deck.gl 9, Mapbox GL JS 3, GitHub Pages |
| Format | ASCII PLY (Punktwolke), GeoJSON (georeferenziert) |

---

## Kurs

Mobile Geoanwendungen · SoSe 2026 · Prof. Dr. Roland Wagner · BHT Berlin  
Autor: Carl Janek Markert
