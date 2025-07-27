import UIKit
import Charts

class AnalyticsViewController: UIViewController {
    @IBOutlet weak var barChartView: BarChartView!
    @IBOutlet weak var pieChartView: PieChartView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadAnalyticsData()
    }
    
    private func setupUI() {
        title = "Analytics"
        barChartView.noDataText = "Loading analytics..."
        pieChartView.noDataText = "Loading analytics..."
    }
    
    private func loadAnalyticsData() {
        // In a real app, this would fetch from your API
        // For demo purposes, we'll simulate data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.setupBarChart()
            self.setupPieChart()
        }
    }
    
    private func setupBarChart() {
        let devices = ["Device 1", "Device 2", "Device 3", "Device 4", "Device 5"]
        let usageData = [25.0, 40.0, 30.0, 50.0, 20.0]
        
        var dataEntries: [BarChartDataEntry] = []
        for i in 0..<devices.count {
            let entry = BarChartDataEntry(x: Double(i), y: usageData[i])
            dataEntries.append(entry)
        }
        
        let chartDataSet = BarChartDataSet(entries: dataEntries, label: "Usage Hours")
        chartDataSet.colors = ChartColorTemplates.material()
        let chartData = BarChartData(dataSet: chartDataSet)
        
        barChartView.data = chartData
        barChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: devices)
        barChartView.xAxis.granularity = 1
        barChartView.xAxis.labelPosition = .bottom
        barChartView.chartDescription?.text = "Device Usage"
    }
    
    private func setupPieChart() {
        let deviceTypes = ["iOS", "Android", "Web", "Other"]
        let deviceCounts = [45.0, 30.0, 20.0, 5.0]
        
        var dataEntries: [PieChartDataEntry] = []
        for i in 0..<deviceTypes.count {
            let entry = PieChartDataEntry(value: deviceCounts[i], label: deviceTypes[i])
            dataEntries.append(entry)
        }
        
        let chartDataSet = PieChartDataSet(entries: dataEntries, label: "Device Distribution")
        chartDataSet.colors = ChartColorTemplates.pastel()
        
        let chartData = PieChartData(dataSet: chartDataSet)
        pieChartView.data = chartData
        pieChartView.chartDescription?.text = "Device Distribution"
    }
}
