import ARKit
import CoreLocation
import simd

/// Manages the ARKit session and captures LiDAR mesh geometry.
class ARLiDARManager: NSObject, ObservableObject {

    let session = ARSession()

    // Published so the UI can react
    @Published var meshAnchors: [ARMeshAnchor] = []
    @Published var isScanning = false

    override init() {
        super.init()
        session.delegate = self
    }

    // MARK: - Session control

    func startScanning() {
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            print("⚠️ LiDAR Scene Reconstruction not supported on this device.")
            return
        }
        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .mesh
        config.environmentTexturing = .automatic
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        isScanning = true
    }

    func stopScanning() {
        session.pause()
        isScanning = false
    }

    // MARK: - PLY Export

    /// Exports all current mesh anchors as a single ASCII PLY string.
    /// The vertex coordinates are in ARKit's local coordinate system (metres).
    func exportPLY() -> String {
        var allVertices: [SIMD3<Float>] = []

        for anchor in meshAnchors {
            let transform = anchor.transform
            let geometry = anchor.geometry
            let src = geometry.vertices

            // Walk the raw buffer
            src.buffer.contents().withMemoryRebound(
                to: SIMD3<Float>.self,
                capacity: src.count
            ) { ptr in
                for i in 0 ..< src.count {
                    // Transform from anchor-local → ARKit world space
                    let local = SIMD4<Float>(ptr[i].x, ptr[i].y, ptr[i].z, 1)
                    let world = transform * local
                    allVertices.append(SIMD3<Float>(world.x, world.y, world.z))
                }
            }
        }

        var ply = """
        ply
        format ascii 1.0
        comment GeoLiDAR Scout export
        element vertex \(allVertices.count)
        property float x
        property float y
        property float z
        end_header\n
        """

        for v in allVertices {
            ply += "\(v.x) \(v.y) \(v.z)\n"
        }
        return ply
    }
}

// MARK: - ARSessionDelegate

extension ARLiDARManager: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let meshes = anchors.compactMap { $0 as? ARMeshAnchor }
        DispatchQueue.main.async {
            self.meshAnchors.append(contentsOf: meshes)
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let updated = anchors.compactMap { $0 as? ARMeshAnchor }
        DispatchQueue.main.async {
            for anchor in updated {
                if let idx = self.meshAnchors.firstIndex(where: { $0.identifier == anchor.identifier }) {
                    self.meshAnchors[idx] = anchor
                }
            }
        }
    }
}
