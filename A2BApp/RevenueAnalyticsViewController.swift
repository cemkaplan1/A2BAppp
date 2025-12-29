import Cocoa

final class AnalyticsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    // UI Elements
    private let metricLabel = NSTextField(labelWithString: "Select Metric:")
    private let metricPopup = NSPopUpButton()

    private let dimensionLabel = NSTextField(labelWithString: "Select Dimension:")
    private let dimensionPopup = NSPopUpButton()

    private let topTableLabel = NSTextField(labelWithString: "Top 5 Items")
    private let topScrollView = NSScrollView()
    private let topTableView = NSTableView()

    private let breakdownLabel = NSTextField(labelWithString: "Monthly Breakdown")
    private let breakdownScrollView = NSScrollView()
    private let breakdownTableView = NSTableView()

    // Data Models
    private enum Metric: String, CaseIterable {
        case revenue = "Revenue"
        case profit = "Profit"
    }
    private enum Dimension: String, CaseIterable {
        case product = "By Product"
        case region = "By Region"
    }

    private var selectedMetric: Metric = .revenue {
        didSet { reloadTopData() }
    }
    private var selectedDimension: Dimension = .product {
        didSet { reloadTopData() }
    }

    private var topData: [(key: String, value: Double)] = []
    private var monthlyData: [(month: String, revenue: Double, profit: Double)] = []

    // Dummy data source
    struct AnalyticsData {
        let key: String
        let month: Date
        let revenue: Double
        let profit: Double
        let dimension: Dimension
    }

    private var allData: [AnalyticsData] = []

    // Formatters
    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Analytics"
        preferredContentSize = NSSize(width: 900, height: 700)
        setupUI()
        loadDummyData()
        reloadTopData()
        reloadMonthlyData()
    }

    private func setupUI() {
        // Setup popups
        metricPopup.addItems(withTitles: Metric.allCases.map { $0.rawValue })
        metricPopup.target = self
        metricPopup.action = #selector(metricChanged)
        metricPopup.selectItem(withTitle: selectedMetric.rawValue)

        dimensionPopup.addItems(withTitles: Dimension.allCases.map { $0.rawValue })
        dimensionPopup.target = self
        dimensionPopup.action = #selector(dimensionChanged)
        dimensionPopup.selectItem(withTitle: selectedDimension.rawValue)

        // Setup Top Table columns
        let topKeyColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TopKey"))
        topKeyColumn.title = "Key"
        topKeyColumn.width = 400
        let topValueColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TopValue"))
        topValueColumn.title = "Value"
        topValueColumn.width = 200
        topTableView.addTableColumn(topKeyColumn)
        topTableView.addTableColumn(topValueColumn)
        topTableView.headerView = NSTableHeaderView()
        topTableView.delegate = self
        topTableView.dataSource = self
        topScrollView.documentView = topTableView
        topScrollView.hasVerticalScroller = true
        topScrollView.drawsBackground = true
        topScrollView.backgroundColor = NSColor.textBackgroundColor

        // Setup Breakdown Table columns
        let monthColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Month"))
        monthColumn.title = "Month"
        monthColumn.width = 150

        let revenueColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Revenue"))
        revenueColumn.title = "Revenue"
        revenueColumn.width = 200

        let profitColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Profit"))
        profitColumn.title = "Profit"
        profitColumn.width = 200

        breakdownTableView.addTableColumn(monthColumn)
        breakdownTableView.addTableColumn(revenueColumn)
        breakdownTableView.addTableColumn(profitColumn)
        breakdownTableView.headerView = NSTableHeaderView()
        breakdownTableView.delegate = self
        breakdownTableView.dataSource = self
        breakdownScrollView.documentView = breakdownTableView
        breakdownScrollView.hasVerticalScroller = true
        breakdownScrollView.drawsBackground = true
        breakdownScrollView.backgroundColor = NSColor.textBackgroundColor

        // Layout controls
        metricLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        dimensionLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let metricStack = NSStackView(views: [metricLabel, metricPopup])
        metricStack.orientation = .horizontal
        metricStack.alignment = .centerY
        metricStack.spacing = 8

        let dimensionStack = NSStackView(views: [dimensionLabel, dimensionPopup])
        dimensionStack.orientation = .horizontal
        dimensionStack.alignment = .centerY
        dimensionStack.spacing = 8

        let controlsStack = NSStackView(views: [metricStack, dimensionStack])
        controlsStack.orientation = .horizontal
        controlsStack.alignment = .centerY
        controlsStack.spacing = 20

        // Main vertical stack
        let mainStack = NSStackView(views: [
            controlsStack,
            topTableLabel,
            topScrollView,
            breakdownLabel,
            breakdownScrollView
        ])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),

            topScrollView.heightAnchor.constraint(equalToConstant: 220),
            topScrollView.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            breakdownScrollView.heightAnchor.constraint(equalToConstant: 360),
            breakdownScrollView.widthAnchor.constraint(equalTo: mainStack.widthAnchor)
        ])
    }

    private func loadDummyData() {
        // Generate dummy data for last 6 months, two dimensions for each month
        let calendar = Calendar.current
        let now = Date()
        allData.removeAll()

        for monthOffset in 0..<6 {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: now) else { continue }
            for dimension in Dimension.allCases {
                let key = dimension == .product ? "Product \(monthOffset + 1)" : "Region \(monthOffset + 1)"
                let revenue = Double.random(in: 5000...20000)
                let profit = revenue * Double.random(in: 0.1...0.5)
                allData.append(AnalyticsData(key: key, month: monthDate, revenue: revenue, profit: profit, dimension: dimension))
            }
        }
    }

    @objc private func metricChanged() {
        if let selected = metricPopup.titleOfSelectedItem, let metric = Metric(rawValue: selected) {
            selectedMetric = metric
        }
    }

    @objc private func dimensionChanged() {
        if let selected = dimensionPopup.titleOfSelectedItem, let dimension = Dimension(rawValue: selected) {
            selectedDimension = dimension
        }
    }

    private func reloadTopData() {
        // Aggregate by selected dimension key
        var aggregation: [String: Double] = [:]
        for data in allData where data.dimension == selectedDimension {
            let val: Double
            switch selectedMetric {
            case .revenue: val = data.revenue
            case .profit: val = data.profit
            }
            aggregation[data.key, default: 0] += val
        }
        // Sort descending and take top 5
        let sorted = aggregation.sorted { $0.value > $1.value }.prefix(5)
        topData = Array(sorted)
        topTableView.reloadData()
    }

    private func reloadMonthlyData() {
        // Aggregate monthly totals for revenue and profit (regardless of dimension)
        var monthAggregation: [Date: (revenue: Double, profit: Double)] = [:]
        let calendar = Calendar.current

        for data in allData {
            let comps = calendar.dateComponents([.year, .month], from: data.month)
            guard let monthDate = calendar.date(from: comps) else { continue }
            var agg = monthAggregation[monthDate] ?? (0, 0)
            agg.revenue += data.revenue
            agg.profit += data.profit
            monthAggregation[monthDate] = agg
        }

        // Sort months ascending
        let sortedMonths = monthAggregation.keys.sorted()
        monthlyData = sortedMonths.map { month in
            let values = monthAggregation[month]!
            return (monthFormatter.string(from: month), values.revenue, values.profit)
        }
        breakdownTableView.reloadData()
    }

    // MARK: - NSTableViewDataSource & Delegate
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == topTableView {
            return topData.count
        } else if tableView == breakdownTableView {
            return monthlyData.count
        }
        return 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn else { return nil }
        let cell = NSTableCellView()
        let textField = NSTextField(labelWithString: "")
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 1
        textField.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        if tableView == topTableView {
            let rowData = topData[row]
            switch column.identifier.rawValue {
            case "TopKey": textField.stringValue = rowData.key
            case "TopValue": textField.stringValue = currencyFormatter.string(from: NSNumber(value: rowData.value)) ?? "$0.00"
            default: break
            }
        } else if tableView == breakdownTableView {
            let rowData = monthlyData[row]
            switch column.identifier.rawValue {
            case "Month": textField.stringValue = rowData.month
            case "Revenue": textField.stringValue = currencyFormatter.string(from: NSNumber(value: rowData.revenue)) ?? "$0.00"
            case "Profit": textField.stringValue = currencyFormatter.string(from: NSNumber(value: rowData.profit)) ?? "$0.00"
            default: break
            }
        }

        return cell
    }
}
