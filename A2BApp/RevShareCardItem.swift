import Cocoa

final class RevShareCardItem: NSCollectionViewItem {
    // UI
    private let titleLabel = NSTextField(labelWithString: "Revenue Share Payable")
    private let amountLabel = NSTextField(labelWithString: "-")
    private let dateLabel = NSTextField(labelWithString: "-")
    private let counterpartyLabel = NSTextField(labelWithString: "-")
    private let paidCheckbox = NSButton(checkboxWithTitle: "Paid", target: nil, action: nil)
    private let openButton: NSButton = {
        let b = NSButton(title: "Open", target: nil, action: nil)
        b.bezelStyle = .rounded
        return b
    }()

    // Callbacks
    var onToggle: ((Service, Bool) -> Void)?
    var onOpen: ((Service) -> Void)?

    private(set) var service: Service?

    override func loadView() {
        self.view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.6).cgColor
        view.layer?.cornerRadius = 10
        view.layer?.borderWidth = 1
        view.layer?.borderColor = NSColor.separatorColor.cgColor

        [titleLabel, amountLabel, dateLabel, counterpartyLabel].forEach { label in
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
        }
        titleLabel.font = .boldSystemFont(ofSize: 13)
        amountLabel.font = .boldSystemFont(ofSize: 15)

        paidCheckbox.target = self
        paidCheckbox.action = #selector(togglePaid)
        openButton.target = self
        openButton.action = #selector(openTapped)

        let grid = NSGridView(views: [
            [titleLabel, NSView()],
            [amountLabel, dateLabel],
            [counterpartyLabel, paidCheckbox],
            [openButton, NSView()]
        ])
        grid.rowSpacing = 6
        grid.columnSpacing = 12

        grid.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            grid.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            grid.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            grid.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
        ])
    }

    func configure(with service: Service, amountText: String, dateText: String, agentOrCounterparty: String, isChecked: Bool) {
        self.service = service
        amountLabel.stringValue = amountText
        dateLabel.stringValue = dateText
        counterpartyLabel.stringValue = agentOrCounterparty
        paidCheckbox.state = isChecked ? .on : .off
    }

    @objc private func togglePaid() {
        guard let svc = service else { return }
        onToggle?(svc, paidCheckbox.state == .on)
    }

    @objc private func openTapped() {
        guard let svc = service else { return }
        onOpen?(svc)
    }
}
