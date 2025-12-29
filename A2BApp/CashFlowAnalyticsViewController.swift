import Cocoa

final class CashFlowAnalyticsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    enum Scale: Int {
        case month = 0
        case week = 1

        var title: String {
            switch self {
            case .month: return "Month"
            case .week: return "Week"
            }
        }
    }

    struct PeriodData {
        let periodKey: String
        let displayString: String
        let inflows: Double
        let outflows: Double
        let net: Double
        let gspr: Double
        let commission: Double
        let cosp: Double
        let year: Int
    }

    // MARK: - UI Elements

    private let yearPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let scalePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let inflowsLabel = NSTextField(labelWithString: "Inflows")
    private let outflowsLabel = NSTextField(labelWithString: "Outflows")
    private let netLabel = NSTextField(labelWithString: "Net")
    private let gsprLabel = NSTextField(labelWithString: "GSPR")
    private let commissionLabel = NSTextField(labelWithString: "Commission")
    private let cospLabel = NSTextField(labelWithString: "COSP")

    private let tableView = NSTableView(frame: .zero)
    private let scrollView = NSScrollView(frame: .zero)

    // MARK: - Data

    private var periodsData: [PeriodData] = []
    private var years: [Int] = []

    private var selectedYear: Int? {
        didSet {
            reloadData()
        }
    }
    private var selectedScale: Scale = .month {
        didSet {
            reloadData()
        }
    }

    private let dateFormatterMonth: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "MMM yyyy"
        return df
    }()

    private let calendarISO = Calendar(identifier: .iso8601)

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupNotifications()

        loadYears()
        selectedYear = years.max()
        populateYearPopup()
        populateScalePopup()
        reloadData()
        autosizeColumns()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.title = "Cash Flow Analytics"
        if let window = view.window {
            let size = NSSize(width: 900, height: 600)
            window.setContentSize(size)
            window.minSize = size
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // Configure labels
        let labelsStack = NSStackView(views: [
            NSTextField(labelWithString: "Year:"),
            yearPopup,
            NSTextField(labelWithString: "Scale:"),
            scalePopup
        ])
        labelsStack.orientation = .horizontal
        labelsStack.distribution = .fill
        labelsStack.alignment = .centerY
        labelsStack.spacing = 10
        labelsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(labelsStack)

        // Setup tableView inside scrollView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        view.addSubview(scrollView)

        // Setup tableView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.selectionHighlightStyle = .regular
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.allowsColumnResizing = true
        tableView.allowsColumnReordering = false
        tableView.allowsColumnSelection = false
        tableView.allowsMultipleSelection = false
        tableView.headerView = NSTableHeaderView(frame: NSRect(x: 0, y: 0, width: 0, height: 25))

        // Remove all columns if any (avoid duplicates on repeated setup)
        while tableView.tableColumns.count > 0 {
            tableView.removeTableColumn(tableView.tableColumns[0])
        }

        addTableColumns()

        // Add constraints
        NSLayoutConstraint.activate([
            labelsStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 15),
            labelsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            labelsStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -15),

            scrollView.topAnchor.constraint(equalTo: labelsStack.bottomAnchor, constant: 15),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -15),

            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 400)
        ])

        yearPopup.target = self
        yearPopup.action = #selector(yearPopupChanged)
        scalePopup.target = self
        scalePopup.action = #selector(scalePopupChanged)
    }

    private func addTableColumns() {
        // Columns in order: Period, Inflows, Outflows, Net, GSPR, Commission, COSP

        let columnsInfo: [(id: NSUserInterfaceItemIdentifier, title: String, alignment: NSTextAlignment)] = [
            (NSUserInterfaceItemIdentifier("period"), "Period", .left),
            (NSUserInterfaceItemIdentifier("inflows"), "Inflows", .right),
            (NSUserInterfaceItemIdentifier("outflows"), "Outflows", .right),
            (NSUserInterfaceItemIdentifier("net"), "Net", .right),
            (NSUserInterfaceItemIdentifier("gspr"), "GSPR", .right),
            (NSUserInterfaceItemIdentifier("commission"), "Commission", .right),
            (NSUserInterfaceItemIdentifier("cosp"), "COSP", .right)
        ]

        for info in columnsInfo {
            let col = NSTableColumn(identifier: info.id)
            col.title = info.title
            let cell = NSTextFieldCell()
            cell.alignment = info.alignment
            cell.isBordered = false
            cell.backgroundColor = .clear
            cell.isEditable = false
            col.dataCell = cell
            tableView.addTableColumn(col)
        }
    }

    // MARK: - Notifications

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(servicesOrSalesUpdated), name: .servicesUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(servicesOrSalesUpdated), name: .salesUpdated, object: nil)
    }

    @objc private func servicesOrSalesUpdated() {
        loadYears()
        if let sel = selectedYear, years.contains(sel) == false {
            selectedYear = years.max()
            populateYearPopup()
        } else {
            reloadData()
        }
    }

    // MARK: - Data Loading and Processing

    private func loadYears() {
        // Load services from ServiceStore.load()
        let services = ServiceStore.load()

        var yearSet = Set<Int>()

        for s in services {
            if let gsprDate = s.gsprDueDate {
                let y = Calendar.current.component(.year, from: gsprDate)
                yearSet.insert(y)
            }
            if let commDate = s.commDueDate {
                let y = Calendar.current.component(.year, from: commDate)
                yearSet.insert(y)
            }
            if let cospDate = s.cospDueDate {
                let y = Calendar.current.component(.year, from: cospDate)
                yearSet.insert(y)
            }
        }

        years = Array(yearSet).sorted()
    }

    private func populateYearPopup() {
        yearPopup.removeAllItems()
        for y in years {
            yearPopup.addItem(withTitle: String(y))
        }
        if let selected = selectedYear {
            yearPopup.selectItem(withTitle: String(selected))
        }
    }

    private func populateScalePopup() {
        scalePopup.removeAllItems()
        scalePopup.addItems(withTitles: [Scale.month.title, Scale.week.title])
        scalePopup.selectItem(at: selectedScale.rawValue)
    }

    private func reloadData() {
        guard let selYear = selectedYear else {
            periodsData = []
            tableView.reloadData()
            return
        }

        let services = ServiceStore.load()

        // Group by period key depending on scale, filtering by year

        // groups: [periodKey: [PeriodData]]
        // We must accumulate amounts per periodKey

        var grouping: [String: (year: Int, displayString: String, gspr: Double, commission: Double, cosp: Double)] = [:]

        for s in services {
            // GSPR
            if let gsprDate = s.gsprDueDate {
                let (year, periodKey, display) = periodInfo(for: gsprDate, scale: selectedScale)
                if year == selYear {
                    let gsprAmount = parseAmount(s.grossSalesPriceReceivable)
                    let key = periodKey
                    let old = grouping[key] ?? (year, display, 0, 0, 0)
                    grouping[key] = (year, display, old.gspr + gsprAmount, old.commission, old.cosp)
                }
            }

            // Commission
            if let commDate = s.commDueDate {
                let (year, periodKey, display) = periodInfo(for: commDate, scale: selectedScale)
                if year == selYear {
                    let grossSalesCommissionableAmount = parseAmount(s.grossSalesCommissionable)
                    let commissionPercentAmount = parseAmount(s.commissionPercent)
                    let commissionAmount = grossSalesCommissionableAmount * (commissionPercentAmount / 100.0)
                    let key = periodKey
                    let old = grouping[key] ?? (year, display, 0, 0, 0)
                    grouping[key] = (year, display, old.gspr, old.commission + commissionAmount, old.cosp)
                }
            }

            // COSP
            if let cospDate = s.cospDueDate {
                let (year, periodKey, display) = periodInfo(for: cospDate, scale: selectedScale)
                if year == selYear {
                    let cospAmount = parseAmount(s.costOfSalesPayable)
                    let key = periodKey
                    let old = grouping[key] ?? (year, display, 0, 0, 0)
                    grouping[key] = (year, display, old.gspr, old.commission, old.cosp + cospAmount)
                }
            }
        }

        var results: [PeriodData] = []
        for (key, val) in grouping {
            let inflows = val.gspr + val.commission
            let outflows = val.cosp
            let net = inflows - outflows
            let pd = PeriodData(periodKey: key, displayString: val.displayString, inflows: inflows, outflows: outflows, net: net, gspr: val.gspr, commission: val.commission, cosp: val.cosp, year: val.year)
            results.append(pd)
        }

        // Sort results by periodKey ascending
        results.sort { $0.periodKey < $1.periodKey }

        periodsData = results
        tableView.reloadData()
        autosizeColumns()
    }

    private func periodInfo(for date: Date, scale: Scale) -> (year: Int, periodKey: String, displayString: String) {
        switch scale {
        case .month:
            // year and month components
            let comps = Calendar.current.dateComponents([.year, .month], from: date)
            guard let year = comps.year, let month = comps.month else {
                return (0, "", "")
            }
            let dateKeyComponents = DateComponents(year: year, month: month, day: 1)
            let periodDate = Calendar.current.date(from: dateKeyComponents)!
            let display = dateFormatterMonth.string(from: periodDate)
            // periodKey: "yyyy-MM" zero padded month
            let periodKey = String(format: "%04d-%02d", year, month)
            return (year, periodKey, display)

        case .week:
            // ISO 8601 week of year and year for week of year
            let comps = calendarISO.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            guard let y = comps.yearForWeekOfYear, let w = comps.weekOfYear else {
                return (0, "", "")
            }
            let periodKey = String(format: "%04d-W%02d", y, w)
            let display = periodKey
            return (y, periodKey, display)
        }
    }

    // MARK: - Actions

    @objc private func yearPopupChanged(_ sender: NSPopUpButton) {
        if let title = sender.selectedItem?.title, let yearInt = Int(title) {
            selectedYear = yearInt
        }
    }

    @objc private func scalePopupChanged(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        if let scale = Scale(rawValue: idx) {
            selectedScale = scale
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return periodsData.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < periodsData.count, let identifier = tableColumn?.identifier else { return nil }

        let data = periodsData[row]

        let textField: NSTextField
        if let v = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField {
            textField = v
        } else {
            textField = NSTextField(labelWithString: "")
            textField.identifier = identifier
            textField.lineBreakMode = .byTruncatingTail
        }

        switch identifier.rawValue {
        case "period":
            textField.stringValue = data.displayString
            textField.alignment = .left
        case "inflows":
            textField.stringValue = formattedCurrency(data.inflows)
            textField.alignment = .right
        case "outflows":
            textField.stringValue = formattedCurrency(data.outflows)
            textField.alignment = .right
        case "net":
            textField.stringValue = formattedCurrency(data.net)
            textField.alignment = .right
        case "gspr":
            textField.stringValue = formattedCurrency(data.gspr)
            textField.alignment = .right
        case "commission":
            textField.stringValue = formattedCurrency(data.commission)
            textField.alignment = .right
        case "cosp":
            textField.stringValue = formattedCurrency(data.cosp)
            textField.alignment = .right
        default:
            textField.stringValue = ""
        }

        return textField
    }

    // MARK: - Helpers

    private func parseAmount(_ str: String?) -> Double {
        guard let str = str else { return 0 }
        let filtered = str.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if let number = formatter.number(from: filtered) {
            return number.doubleValue
        }
        // Try Double init fallback
        return Double(filtered) ?? 0
    }

    private func formattedCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    private func autosizeColumns() {
        // Similar to RevenueAnalyticsViewController autosizeColumns helper
        for column in tableView.tableColumns {
            var maxWidth: CGFloat = 50.0 // min width

            // Measure header
            let headerString = column.title as NSString
            let headerAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)]
            let headerSize = headerString.size(withAttributes: headerAttributes)
            maxWidth = max(maxWidth, headerSize.width + 20) // add margin

            // Measure rows
            for row in 0..<periodsData.count {
                let cellString: NSString
                switch column.identifier.rawValue {
                case "period":
                    cellString = periodsData[row].displayString as NSString
                case "inflows":
                    cellString = formattedCurrency(periodsData[row].inflows) as NSString
                case "outflows":
                    cellString = formattedCurrency(periodsData[row].outflows) as NSString
                case "net":
                    cellString = formattedCurrency(periodsData[row].net) as NSString
                case "gspr":
                    cellString = formattedCurrency(periodsData[row].gspr) as NSString
                case "commission":
                    cellString = formattedCurrency(periodsData[row].commission) as NSString
                case "cosp":
                    cellString = formattedCurrency(periodsData[row].cosp) as NSString
                default:
                    cellString = "" as NSString
                }
                let size = cellString.size(withAttributes: headerAttributes)
                maxWidth = max(maxWidth, size.width + 20)
            }

            column.minWidth = maxWidth
            column.width = maxWidth
        }
    }
}

// MARK: - Service and ServiceStore Definitions (Mocks for Compile)

fileprivate extension Notification.Name {
    static let servicesUpdated = Notification.Name("servicesUpdated")
    static let salesUpdated = Notification.Name("salesUpdated")
}

// These are mocked for completeness; in real use these would be your application's models and storage

struct Service {
    let grossSalesPriceReceivable: String?
    let grossSalesCommissionable: String?
    let commissionPercent: String?
    let costOfSalesPayable: String?

    let gsprDueDate: Date?
    let commDueDate: Date?
    let cospDueDate: Date?

    // cleared flags ignored as requirement states include all services regardless
}

struct ServiceStore {
    static func load() -> [Service] {
        // Return empty array or sample data if needed
        return []
    }
}
