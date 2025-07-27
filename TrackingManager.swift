import Foundation
import CoreLocation
import SocketIO

class TrackingManager: NSObject, CLLocationManagerDelegate {
    static let shared = TrackingManager()
    
    private let locationManager = CLLocationManager()
    private let socketManager = SocketManager(socketURL: URL(string: "http://localhost:3000")!, config: [.log(true), .compress])
    private var socket: SocketIOClient!
    
    private var deviceId: String = ""
    private var isTracking = false
    
    override init() {
        super.init()
        setupLocationManager()
        setupSocket()
        generateDeviceId()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
    }
    
    private func setupSocket() {
        socket = socketManager.defaultSocket
        setupSocketHandlers()
    }
    
    private func setupSocketHandlers() {
        socket.on(clientEvent: .connect) { data, ack in
            print("Socket connected")
            self.socket.emit("joinDevice", self.deviceId)
        }
        
        socket.on(clientEvent: .disconnect) { data, ack in
            print("Socket disconnected")
        }
    }
    
    private func generateDeviceId() {
        deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }
    
    func startTracking() {
        let status = CLLocationManager.authorizationStatus()
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
            socket.connect()
            isTracking = true
        }
    }
    
    func stopTracking() {
        locationManager.stopUpdatingLocation()
        socket.disconnect()
        isTracking = false
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, isTracking else { return }
        
        let trackingData: [String: Any] = [
            "deviceId": deviceId,
            "location": [
                "lat": location.coordinate.latitude,
                "lng": location.coordinate.longitude
            ],
            "speed": location.speed,
            "battery": UIDevice.current.batteryLevel,
            "status": "active"
        ]
        
        socket.emit("trackingData", trackingData)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            startTracking()
        }
    }
}
