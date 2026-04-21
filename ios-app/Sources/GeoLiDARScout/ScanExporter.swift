import Foundation
import ARKit

/// Bundles the PLY point cloud + GPS anchor into a single JSON packet
/// ready for upload to the Python backend.
struct ScanPacket: Codable {
    let plyBase64: String       // Base64-encoded ASCII PLY
    let latitude:  Double
    let longitude: Double
    let altitude:  Double
    let heading:   Double       // true north bearing in degrees
    let accuracy:  Double
    let timestamp: Double
    let deviceModel: String
}

class ScanExporter {

    static func buildPacket(plyString: String,
                            anchor: [String: Double]) -> ScanPacket? {
        guard
            let lat  = anchor["latitude"],
            let lon  = anchor["longitude"],
            let alt  = anchor["altitude"],
            let hdg  = anchor["heading"],
            let acc  = anchor["accuracy"],
            let ts   = anchor["timestamp"],
            let data = plyString.data(using: .utf8)
        else { return nil }

        return ScanPacket(
            plyBase64:   data.base64EncodedString(),
            latitude:    lat,
            longitude:   lon,
            altitude:    alt,
            heading:     hdg,
            accuracy:    acc,
            timestamp:   ts,
            deviceModel: UIDevice.current.model
        )
    }

    // MARK: - Upload to backend

    /// POSTs the scan packet to the local Python backend.
    /// Change `baseURL` to your deployed server URL for production.
    static func upload(packet: ScanPacket,
                       baseURL: String = "http://localhost:8000",
                       completion: @escaping (Result<URL, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/scan") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(packet)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let path = json["geojson_url"],
                  let resultURL = URL(string: path)
            else {
                completion(.failure(NSError(domain: "ScanExporter", code: -1)))
                return
            }
            completion(.success(resultURL))
        }.resume()
    }

    // MARK: - Local save (fallback / AirDrop)

    static func saveLocally(packet: ScanPacket) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(packet)

        let fileName = "scan_\(Int(packet.timestamp)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url)
        return url
    }
}
