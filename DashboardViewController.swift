import UIKit
import MapKit
import Charts

class DashboardViewController: UIViewController {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var batteryLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var lineChartView: LineChartView!
    
    private let socketManager = SocketManager(socketURL: URL(string: "http://localhost:3000")!, config: [.log(true), .compress])
    private var socket: SocketIOClient!
    private var deviceId: String = ""
    private var speedDataEntries: [ChartDataEntry] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSocket()
        setupChart()
        deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }
    
    private func setupUI() {
        title = "Swift Tracker Dashboard"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Start",
            style: .plain,
            target: self,
            action: #selector(toggleTracking)
        )
        
        mapView.delegate = self
        mapView.showsUserLocation = true
        
        speedLabel.text = "0 km/h"
        batteryLabel.text = "100%"
        statusLabel.text = "Inactive"
        statusLabel.textColor = .systemRed
    }
    
    private func setupSocket() {
        socket = socketManager.defaultSocket
        
        socket.on(clientEvent: .connect) { data, ack in
            print("Dashboard connected to socket")
            self.socket.emit("joinDevice", self.deviceId)
        }
        
        socket.on("liveUpdate") { data, ack in
            guard let trackingData = data.first as? [String: Any],
                  let locationData = trackingData["location"] as? [String: Double],
                  let lat = locationData["lat"],
                  let lng = locationData["lng"],
                  let speed = trackingData["speed"] as? Double,
                  let battery = trackingData["battery"] as? Double else { return }
            
            DispatchQueue.main.async {
                self.updateUI(with: lat, lng: lng, speed: speed, battery: battery)
                self.updateMap(with: lat, lng: lng)
                self.updateChart(with: speed)
            }
        }
        
        socket.connect()
    }
    
    private func setupChart() {
        lineChartView.noDataText = "No data available"
        lineChartView.chartDescription?.text = "Speed Over Time"
        lineChartView.dragEnabled = true
        lineChartView.setScaleEnabled(true)
        lineChartView.pinchZoomEnabled = false
    }
    
    @objc private func toggleTracking() {
        if TrackingManager.shared.isTracking {
            TrackingManager.shared.stopTracking()
            navigationItem.rightBarButtonItem?.title = "Start"
            statusLabel.text = "Inactive"
            statusLabel.textColor = .systemRed
        } else {
            TrackingManager.shared.startTracking()
            navigationItem.rightBarButtonItem?.title = "Stop"
            statusLabel.text = "Active"
            statusLabel.textColor = .systemGreen
        }
    }
    
    private func updateUI(with lat: Double, lng: Double, speed: Double, battery: Double) {
        let speedKmh = speed * 3.6 // Convert m/s to km/h
        speedLabel.text = String(format: "%.1f km/h", speedKmh)
        batteryLabel.text = String(format: "%.0f%%", battery * 100)
    }
    
    private func updateMap(with lat: Double, lng: Double) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapView.setRegion(region, animated: true)
        
        // Add annotation
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "Current Location"
        mapView.addAnnotation(annotation)
    }
    
    private func updateChart(with speed: Double) {
        let speedKmh = speed * 3.6
        let entry = ChartDataEntry(x: Double(speedDataEntries.count), y: speedKmh)
        speedDataEntries.append(entry)
        
        let dataSet = LineChartDataSet(entries: speedDataEntries, label: "Speed (km/h)")
        dataSet.colors = [NSUIColor.systemBlue]
        dataSet.circleColors = [NSUIColor.systemBlue]
        dataSet.lineWidth = 2
        dataSet.circleRadius = 4
        dataSet.drawValuesEnabled = false
        
        let data = LineChartData(dataSet: dataSet)
        lineChartView.data = data
        lineChartView.notifyDataSetChanged()
    }
}

extension DashboardViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is MKPointAnnotation else { return nil }
        
        let identifier = "Annotation"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
        } else {
            annotationView?.annotation = annotation
        }
        
        return annotationView
    }
}
