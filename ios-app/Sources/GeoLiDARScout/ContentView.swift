import SwiftUI
import RealityKit
import ARKit

struct ContentView: View {

    @StateObject private var lidar    = ARLiDARManager()
    @StateObject private var location = LocationManager()

    @State private var statusMessage  = "Bereit zum Scannen"
    @State private var isUploading    = false
    @State private var uploadResult   = ""

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── AR View ──────────────────────────────────────────────────────
            ARViewContainer(arManager: lidar)
                .ignoresSafeArea()

            // ── HUD ──────────────────────────────────────────────────────────
            VStack(spacing: 12) {

                // GPS status badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(location.location != nil ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    Text(location.location != nil
                         ? String(format: "GPS  %.5f, %.5f",
                                  location.location!.coordinate.latitude,
                                  location.location!.coordinate.longitude)
                         : "GPS wird gesucht …")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(Color.black.opacity(0.55))
                .cornerRadius(10)

                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.55))
                    .cornerRadius(8)

                if !uploadResult.isEmpty {
                    Text(uploadResult)
                        .font(.caption2)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .padding(8)
                        .background(Color.black.opacity(0.55))
                        .cornerRadius(8)
                }

                // ── Buttons ──────────────────────────────────────────────────
                HStack(spacing: 16) {
                    Button(action: toggleScan) {
                        Label(lidar.isScanning ? "Stop" : "Scan starten",
                              systemImage: lidar.isScanning ? "stop.circle.fill" : "camera.fill")
                            .font(.headline)
                            .padding()
                            .background(lidar.isScanning ? Color.red : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    Button(action: exportScan) {
                        Label(isUploading ? "Sendet …" : "Exportieren",
                              systemImage: "arrow.up.circle.fill")
                            .font(.headline)
                            .padding()
                            .background(Color.green.opacity(isUploading ? 0.5 : 1))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(isUploading || lidar.meshAnchors.isEmpty)
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Actions

    private func toggleScan() {
        if lidar.isScanning {
            lidar.stopScanning()
            let count = lidar.meshAnchors.count
            statusMessage = "Scan gestoppt – \(count) Mesh-Anchor(s) erfasst"
        } else {
            lidar.meshAnchors.removeAll()
            uploadResult = ""
            lidar.startScanning()
            statusMessage = "Scanne … bewege das iPhone langsam"
        }
    }

    private func exportScan() {
        guard !lidar.meshAnchors.isEmpty else { return }

        isUploading    = true
        statusMessage  = "Exportiere PLY …"

        DispatchQueue.global(qos: .userInitiated).async {
            let ply    = lidar.exportPLY()
            let anchor = location.anchorDict()

            guard let packet = ScanExporter.buildPacket(plyString: ply, anchor: anchor) else {
                DispatchQueue.main.async {
                    statusMessage = "Fehler: GPS nicht verfügbar"
                    isUploading   = false
                }
                return
            }

            // Try upload, fall back to local save
            ScanExporter.upload(packet: packet) { result in
                DispatchQueue.main.async {
                    isUploading = false
                    switch result {
                    case .success(let url):
                        statusMessage = "✓ Hochgeladen!"
                        uploadResult  = url.absoluteString
                    case .failure:
                        // Fallback: save locally and show share sheet
                        if let localURL = try? ScanExporter.saveLocally(packet: packet) {
                            statusMessage = "Gespeichert lokal (kein Server)"
                            uploadResult  = localURL.path
                        }
                    }
                }
            }
        }
    }
}

// MARK: - ARViewContainer (UIViewRepresentable)

struct ARViewContainer: UIViewRepresentable {
    let arManager: ARLiDARManager

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session = arManager.session

        // Visualise the mesh in debug mode during development
        arView.debugOptions = [.showSceneUnderstanding]
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
