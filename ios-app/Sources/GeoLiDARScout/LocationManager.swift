import CoreLocation
import Combine

/// Wraps CLLocationManager and publishes the best available GPS fix.
class LocationManager: NSObject, ObservableObject {

    private let manager = CLLocationManager()

    @Published var location: CLLocation?
    @Published var heading: CLHeading?      // compass bearing → used for georef rotation
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    /// Returns a snapshot dict suitable for embedding in the PLY export packet.
    func anchorDict() -> [String: Double] {
        guard let loc = location else { return [:] }
        return [
            "latitude":  loc.coordinate.latitude,
            "longitude": loc.coordinate.longitude,
            "altitude":  loc.altitude,
            "accuracy":  loc.horizontalAccuracy,
            "heading":   heading?.trueHeading ?? 0.0,
            "timestamp": loc.timestamp.timeIntervalSince1970
        ]
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
    }
}
