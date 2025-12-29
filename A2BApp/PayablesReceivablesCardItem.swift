import Cocoa

/// Represents a single payable/receivable entry derived from a Service.
/// `kind` determines whether it's a GSPR receivable or COSP payable.
struct PRItem: Equatable, Hashable {
    enum Kind { case receivableGSPR, payableCOSP }
    let kind: Kind
    let service: Service
    let dueDate: Date
    let amountText: String
    let clientFirstName: String
    let clientLastName: String
    let serviceType: String
    let notes: String
}

final class PayablesReceivablesCardItem: NSCollectionViewItem {
    // UI
    private let titleLabel = NSTextField(labelWithString: "-") // e.g. Receivable / Payable
    private let dueDateLabel = NSTextField(labelWithString: "-")
    private let amountLabel = NSTextField(labelWithString: "-")
    private let clientLabel = NSTextField(labelWithString: "-")
    private let serviceTypeLabel = NSTextField(labelWithString: "-")
    private let notesLabel = NSTextField(labelWithString: "-")

    private let actionButton: NSButton = {
        let b = NSButton(title: "Open", target: nil, action: nil)
        b.bezelStyle = .rounded
        b.controlSize = .mini
        b.font = .systemFont(ofSize: 13)
        return b
    }()

    private let markButton: NSButton = {
        let b = NSButton(title: "Mark", target: nil, action: nil)
        b.bezelStyle = .rounded
        b.controlSize = .mini
        b.font = .systemFont(ofSize: 13)
        b.contentTintColor = .systemGreen
        let greenTitle = NSAttributedString(string: "Mark", attributes: [.foregroundColor: NSColor.systemGreen])
        b.attributedTitle = greenTitle
        return b
    }()

    // Model
    private(set) var item: PRItem?

    // Callbacks
    var onOpen: ((PRItem) -> Void)?
    var onClear: ((PRItem) -> Void)?

    override func loadView() { self.view = NSView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.6).cgColor
        view.layer?.cornerRadius = 10
        view.layer?.borderWidth = 2
        view.layer?.borderColor = NSColor.white.cgColor

        [titleLabel, dueDateLabel, amountLabel, clientLabel, serviceTypeLabel, notesLabel].forEach { l in
            l.lineBreakMode = .byTruncatingTail
            l.maximumNumberOfLines = 1
            l.font = .systemFont(ofSize: 13)
        }
        titleLabel.font = .boldSystemFont(ofSize: 13)
        amountLabel.font = .boldSystemFont(ofSize: 13)

        actionButton.target = self
        actionButton.action = #selector(openTapped)
        markButton.target = self
        markButton.action = #selector(markTapped)

        // Layout: two rows (info) + actions on the right
        let top = NSStackView(views: [titleLabel, dueDateLabel, amountLabel])
        top.orientation = .horizontal
        top.alignment = .centerY
        top.spacing = 6

        let mid = NSStackView(views: [clientLabel, serviceTypeLabel, notesLabel])
        mid.orientation = .horizontal
        mid.alignment = .centerY
        mid.spacing = 6

        let left = NSStackView(views: [top, mid])
        left.orientation = .vertical
        left.spacing = 2

        let right = NSStackView(views: [markButton, actionButton])
        right.orientation = .vertical
        right.alignment = .trailing
        right.spacing = 4

        let hstack = NSStackView(views: [left, right])
        hstack.orientation = .horizontal
        hstack.alignment = .centerY
        hstack.spacing = 8
        hstack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(hstack)
        NSLayoutConstraint.activate([
            hstack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            hstack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            hstack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        let height = view.heightAnchor.constraint(equalToConstant: 60)
        height.priority = .defaultHigh
        height.isActive = true
    }

    func configure(with item: PRItem) {
        self.item = item
        switch item.kind {
        case .receivableGSPR:
            titleLabel.stringValue = "Receivable (GSPR)"
        case .payableCOSP:
            titleLabel.stringValue = "Payable (COSP)"
        }
        dueDateLabel.stringValue = DateFormatter.localizedString(from: item.dueDate, dateStyle: .short, timeStyle: .none)
        amountLabel.stringValue = item.amountText
        clientLabel.stringValue = "Client: \(item.clientFirstName) \(item.clientLastName)"
        serviceTypeLabel.stringValue = "Type: \(item.serviceType)"
        notesLabel.stringValue = "Notes: \(item.notes)"
    }

    @objc private func openTapped() {
        guard let item = item else { return }
        onOpen?(item)
    }

    @objc private func markTapped() {
        guard let item = item else { return }
        let alert = NSAlert()
        alert.messageText = "Clear Record?"
        alert.informativeText = "This will remove the card from the list."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "Cancel")
        if let window = self.view.window {
            alert.beginSheetModal(for: window) { [weak self] response in
                guard let self = self else { return }
                if response == .alertFirstButtonReturn { self.onClear?(item) }
            }
        } else {
            if alert.runModal() == .alertFirstButtonReturn { onClear?(item) }
        }
    }
}
