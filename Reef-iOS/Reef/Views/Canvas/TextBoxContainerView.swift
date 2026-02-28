//
//  TextBoxContainerView.swift
//  Reef
//
//  Overlay view that manages positioned text boxes on a canvas page
//

import UIKit

class TextBoxContainerView: UIView {

    /// Whether the text box tool is currently active
    var isTextBoxToolActive: Bool = false {
        didSet {
            isUserInteractionEnabled = isTextBoxToolActive
            if !isTextBoxToolActive {
                deselectAll()
            }
        }
    }

    /// Current font size for new text boxes
    var currentFontSize: CGFloat = 16

    /// Current text color for new text boxes
    var currentTextColor: UIColor = .black

    /// All text box data for this page
    private(set) var textBoxes: [TextBoxData] = []

    /// Maps text box IDs to their ReefTextBoxView instances
    private var textViewMap: [UUID: ReefTextBoxView] = [:]

    /// Currently selected text box ID (selected but not editing)
    private var selectedBoxID: UUID?

    /// Callback for save debouncing
    var onTextBoxesChanged: (() -> Void)?

    /// Debounce task
    private var saveTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false // Disabled until text tool is selected

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)

        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTapGesture)

        // Single tap waits for double tap to fail
        tapGesture.require(toFail: doubleTapGesture)
    }

    // MARK: - Selection

    private func select(_ boxID: UUID) {
        deselectAll()
        selectedBoxID = boxID
        if let textView = textViewMap[boxID] {
            textView.showSelectionBorder()
            textView.deleteButton.isHidden = false
        }
    }

    private func deselectAll() {
        // End any editing
        for (_, textView) in textViewMap {
            textView.resignFirstResponder()
            textView.hideSelectionBorder()
            textView.deleteButton.isHidden = true
            textView.isEditable = false
        }
        selectedBoxID = nil
    }

    private func deleteTextBox(_ boxID: UUID) {
        guard let textView = textViewMap[boxID] else { return }
        textBoxes.removeAll { $0.id == boxID }
        textViewMap.removeValue(forKey: boxID)
        textView.removeFromSuperview()
        if selectedBoxID == boxID { selectedBoxID = nil }
        debounceSave()
    }

    // MARK: - Tap Handling

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard isTextBoxToolActive else { return }
        let point = gesture.location(in: self)

        // Check if tapped on an existing text box
        if let tapped = hitTextBox(at: point) {
            select(tapped)
            return
        }

        // Tapped empty area — deselect if something is selected, else create new
        if selectedBoxID != nil {
            deselectAll()
        } else {
            createTextBox(at: point)
        }
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard isTextBoxToolActive else { return }
        let point = gesture.location(in: self)

        // Double tap on text box → enter edit mode
        if let tapped = hitTextBox(at: point), let textView = textViewMap[tapped] {
            select(tapped)
            textView.isEditable = true
            textView.becomeFirstResponder()
        }
    }

    private func hitTextBox(at point: CGPoint) -> UUID? {
        // Iterate in reverse so topmost view gets priority
        for (id, textView) in textViewMap.reversed() {
            // Use a slightly expanded hit area for easier tapping
            let hitFrame = textView.frame.insetBy(dx: -8, dy: -8)
            if hitFrame.contains(point) {
                return id
            }
        }
        return nil
    }

    // MARK: - Create

    private func createTextBox(at point: CGPoint) {
        let defaultWidth: CGFloat = 200
        let data = TextBoxData(
            x: point.x - defaultWidth / 2,
            y: point.y,
            width: defaultWidth,
            text: "",
            fontSize: currentFontSize,
            colorHex: TextBoxData.hexFromUIColor(currentTextColor)
        )

        textBoxes.append(data)
        let textView = makeTextView(for: data)
        textViewMap[data.id] = textView
        addSubview(textView)

        // Select and enter edit mode for new text box
        select(data.id)
        textView.isEditable = true
        textView.becomeFirstResponder()
    }

    // MARK: - Text View Factory

    private func makeTextView(for data: TextBoxData) -> ReefTextBoxView {
        let textView = ReefTextBoxView()
        textView.textBoxID = data.id
        textView.text = data.text
        textView.font = UIFont.systemFont(ofSize: data.fontSize)
        textView.textColor = data.uiColor
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.isEditable = false // Not editable until double-tapped
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        textView.delegate = self
        textView.layer.cornerRadius = 4

        // Position and size
        textView.frame = CGRect(x: data.x, y: data.y, width: data.width, height: 30)
        textView.sizeToFit()
        textView.frame.size.width = max(data.width, textView.frame.width)

        // Delete button — hidden by default
        textView.deleteButton.addTarget(self, action: #selector(handleDeleteButton(_:)), for: .touchUpInside)
        textView.deleteButton.isHidden = true

        // Pan gesture for moving (only works on selected boxes)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        textView.addGestureRecognizer(panGesture)

        return textView
    }

    // MARK: - Delete Button

    @objc private func handleDeleteButton(_ sender: UIButton) {
        guard let textView = sender.superview as? ReefTextBoxView,
              let boxID = textView.textBoxID else { return }
        deleteTextBox(boxID)
    }

    // MARK: - Move Gesture

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let textView = gesture.view as? ReefTextBoxView,
              let boxID = textView.textBoxID else { return }

        // Must be selected to move
        guard selectedBoxID == boxID else { return }

        switch gesture.state {
        case .began:
            // End editing if moving
            textView.resignFirstResponder()
            textView.isEditable = false
        case .changed:
            let translation = gesture.translation(in: self)
            textView.center = CGPoint(
                x: textView.center.x + translation.x,
                y: textView.center.y + translation.y
            )
            gesture.setTranslation(.zero, in: self)
        case .ended:
            // Update stored position
            if let index = textBoxes.firstIndex(where: { $0.id == boxID }) {
                textBoxes[index].x = textView.frame.origin.x
                textBoxes[index].y = textView.frame.origin.y
            }
            debounceSave()
        default:
            break
        }
    }

    // MARK: - Load / Save

    func loadTextBoxes(_ boxes: [TextBoxData]) {
        // Remove existing text views
        for (_, textView) in textViewMap {
            textView.removeFromSuperview()
        }
        textViewMap.removeAll()
        textBoxes = boxes

        // Recreate text views
        for data in boxes {
            let textView = makeTextView(for: data)
            textViewMap[data.id] = textView
            addSubview(textView)
        }
    }

    private func debounceSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if !Task.isCancelled {
                self.onTextBoxesChanged?()
            }
        }
    }

    // MARK: - Export

    /// Renders all text boxes into a CGContext for PDF export
    func renderTextBoxes(in context: CGContext, scale: CGFloat) {
        for data in textBoxes where !data.text.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: data.fontSize),
                .foregroundColor: data.uiColor
            ]
            let attrString = NSAttributedString(string: data.text, attributes: attributes)
            let drawRect = CGRect(x: data.x * scale, y: data.y * scale, width: data.width * scale, height: CGFloat.greatestFiniteMagnitude)

            UIGraphicsPushContext(context)
            attrString.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            UIGraphicsPopContext()
        }
    }
}

// MARK: - UITextViewDelegate

extension TextBoxContainerView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        guard let reefTextView = textView as? ReefTextBoxView,
              let boxID = reefTextView.textBoxID else { return }

        // Auto-resize height
        let fixedWidth = textView.frame.size.width
        let newSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        textView.frame.size.height = max(newSize.height, 30)

        // Update stored text
        if let index = textBoxes.firstIndex(where: { $0.id == boxID }) {
            textBoxes[index].text = textView.text
        }

        debounceSave()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        guard let reefTextView = textView as? ReefTextBoxView else { return }
        reefTextView.showEditingBorder()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        guard let reefTextView = textView as? ReefTextBoxView,
              let boxID = reefTextView.textBoxID else { return }

        textView.isEditable = false

        // If still selected, show selection border; otherwise hide
        if selectedBoxID == boxID {
            reefTextView.showSelectionBorder()
        } else {
            reefTextView.hideSelectionBorder()
        }

        // Remove empty text boxes
        if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            deleteTextBox(boxID)
        }
    }
}

// MARK: - Custom UITextView Subclass

class ReefTextBoxView: UITextView {
    var textBoxID: UUID?

    /// Delete button (X) shown when selected
    let deleteButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        button.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.systemRed
        button.layer.cornerRadius = 11
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupDeleteButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDeleteButton()
    }

    private func setupDeleteButton() {
        addSubview(deleteButton)
        NSLayoutConstraint.activate([
            deleteButton.widthAnchor.constraint(equalToConstant: 22),
            deleteButton.heightAnchor.constraint(equalToConstant: 22),
            deleteButton.topAnchor.constraint(equalTo: topAnchor, constant: -8),
            deleteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 8)
        ])
    }

    func showSelectionBorder() {
        layer.borderWidth = 1.5
        layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.6).cgColor
        setDashedBorder(true)
    }

    func showEditingBorder() {
        // Solid blue border during editing
        layer.sublayers?.removeAll(where: { $0.name == "dashedBorder" })
        layer.borderWidth = 1.5
        layer.borderColor = UIColor.systemBlue.cgColor
    }

    func hideSelectionBorder() {
        layer.borderWidth = 0
        layer.sublayers?.removeAll(where: { $0.name == "dashedBorder" })
    }

    private func setDashedBorder(_ show: Bool) {
        layer.sublayers?.removeAll(where: { $0.name == "dashedBorder" })
        guard show else { return }

        let dashedLayer = CAShapeLayer()
        dashedLayer.name = "dashedBorder"
        dashedLayer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.6).cgColor
        dashedLayer.fillColor = nil
        dashedLayer.lineDashPattern = [4, 3]
        dashedLayer.lineWidth = 1.5
        dashedLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: 4).cgPath
        dashedLayer.frame = bounds
        layer.addSublayer(dashedLayer)
        // Hide the solid border since we're using dashed
        layer.borderWidth = 0
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Update dashed border frame if visible
        if let dashedLayer = layer.sublayers?.first(where: { $0.name == "dashedBorder" }) as? CAShapeLayer {
            dashedLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: 4).cgPath
            dashedLayer.frame = bounds
        }
    }

    override var clipsToBounds: Bool {
        get { false }
        set { super.clipsToBounds = false }
    }
}
