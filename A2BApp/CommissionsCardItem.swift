import Cocoa

final class CommissionsCardItem: NSCollectionViewItem {
    // UI
    private let container = NSView()
    private let titleLabel = NSTextField(labelWithString: "Commissions Receivable")
    private let amountLabel = NSTextField(labelWithString: "-")
    private let dateLabel = NSTextField(labelWithString: "-")
    private let agentLabel = NSTextField(labelWithString: "-")
    private let receivedCheckbox = NSButton(checkboxWithTitle: "Received", target: nil, action: nil)
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

        [titleLabel, amountLabel, dateLabel, agentLabel].forEach { label in
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
        }
        titleLabel.font = .boldSystemFont(ofSize: 13)
        amountLabel.font = .boldSystemFont(ofSize: 15)

        receivedCheckbox.target = self
        receivedCheckbox.action = #selector(toggleReceived)
        openButton.target = self
        openButton.action = #selector(openTapped)

        let grid = NSGridView(views: [
            [titleLabel, NSView()],
            [amountLabel, dateLabel],
            [agentLabel, receivedCheckbox],
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
        agentLabel.stringValue = agentOrCounterparty
        receivedCheckbox.state = isChecked ? .on : .off
    }

    @objc private func toggleReceived() {
        guard let svc = service else { return }
        onToggle?(svc, receivedCheckbox.state == .on)
    }

    @objc private func openTapped() {
        guard let svc = service else { return }
        onOpen?(svc)
    }
}
