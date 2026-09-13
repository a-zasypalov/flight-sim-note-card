import PDFKit
import SwiftUI

struct NoteTemplateView: UIViewRepresentable {
    let layout: NoteLayout
    let pdfURL: URL
    let fieldValues: [NoteLayoutField.ID: String]
    let logoData: Data?
    let onFieldChange: (NoteLayoutField.ID, String) -> Void
    let onPickLogo: () -> Void
    let onDropLogo: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayBox = .mediaBox
        pdfView.displayMode = .singlePage
        pdfView.pageOverlayViewProvider = context.coordinator
        pdfView.document = PDFDocument(url: pdfURL)
        pdfView.autoScales = true
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        context.coordinator.update(self)
    }

    final class Coordinator: NSObject, PDFPageOverlayViewProvider {
        private var parent: NoteTemplateView
        private var overlayView: NoteEditorOverlayView?

        init(_ parent: NoteTemplateView) {
            self.parent = parent
        }

        func update(_ parent: NoteTemplateView) {
            self.parent = parent
            overlayView?.update(
                fieldValues: parent.fieldValues,
                logoData: parent.logoData,
                onFieldChange: parent.onFieldChange,
                onPickLogo: parent.onPickLogo,
                onDropLogo: parent.onDropLogo
            )
        }

        func pdfView(_ pdfView: PDFView, overlayViewFor page: PDFPage) -> UIView? {
            let overlayView = NoteEditorOverlayView(
                layout: parent.layout,
                pageBounds: page.bounds(for: .mediaBox),
                fieldValues: parent.fieldValues,
                logoData: parent.logoData,
                onFieldChange: parent.onFieldChange,
                onPickLogo: parent.onPickLogo,
                onDropLogo: parent.onDropLogo
            )
            self.overlayView = overlayView
            return overlayView
        }
    }
}

private final class NoteEditorOverlayView: UIView, UITextFieldDelegate {
    private let layout: NoteLayout
    private var fieldViews: [UITextField] = []
    private var logoView: LogoDropView?
    private var onFieldChange: (NoteLayoutField.ID, String) -> Void

    init(
        layout: NoteLayout,
        pageBounds: CGRect,
        fieldValues: [NoteLayoutField.ID: String],
        logoData: Data?,
        onFieldChange: @escaping (NoteLayoutField.ID, String) -> Void,
        onPickLogo: @escaping () -> Void,
        onDropLogo: @escaping (UIImage) -> Void
    ) {
        self.layout = layout
        self.onFieldChange = onFieldChange
        super.init(frame: pageBounds)
        backgroundColor = .clear

        for (index, field) in layout.fields.enumerated() {
            let fieldFrame = layout.pageRect(for: field.frame, in: pageBounds)
            let valueFrame = layout.pageRect(for: field.valueFrame, in: pageBounds)
            let textField = CardTextField(
                frame: fieldFrame,
                textInsets: UIEdgeInsets(
                    top: valueFrame.minY - fieldFrame.minY,
                    left: valueFrame.minX - fieldFrame.minX,
                    bottom: fieldFrame.maxY - valueFrame.maxY,
                    right: fieldFrame.maxX - valueFrame.maxX
                )
            )
            textField.tag = index
            textField.text = displayed(fieldValues[field.id] ?? "", for: field)
            textField.font = UIFont(name: "Courier", size: CGFloat(field.fontSize ?? 7.4))
            textField.textColor = UIColor(white: 0.16, alpha: 1)
            textField.textAlignment = field.alignment.textAlignment
            textField.contentVerticalAlignment = .bottom
            textField.adjustsFontSizeToFitWidth = true
            textField.minimumFontSize = 5
            textField.borderStyle = .none
            textField.backgroundColor = .clear
            textField.autocapitalizationType = .allCharacters
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            textField.smartDashesType = .no
            textField.smartQuotesType = .no
            textField.keyboardType = field.format == .frequency ? .numbersAndPunctuation : .asciiCapable
            textField.returnKeyType = index == layout.fields.indices.last ? .done : .next
            textField.accessibilityLabel = field.label
            textField.delegate = self
            textField.addTarget(self, action: #selector(fieldChanged(_:)), for: .editingChanged)
            fieldViews.append(textField)
            addSubview(textField)
        }

        if let logoFrame = layout.logoFrame {
            let logoView = LogoDropView(frame: layout.pageRect(for: logoFrame, in: pageBounds))
            logoView.onTap = onPickLogo
            logoView.onDrop = onDropLogo
            logoView.setImage(data: logoData)
            self.logoView = logoView
            addSubview(logoView)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        fieldValues: [NoteLayoutField.ID: String],
        logoData: Data?,
        onFieldChange: @escaping (NoteLayoutField.ID, String) -> Void,
        onPickLogo: @escaping () -> Void,
        onDropLogo: @escaping (UIImage) -> Void
    ) {
        self.onFieldChange = onFieldChange

        for (index, textField) in fieldViews.enumerated() where !textField.isFirstResponder {
            let field = layout.fields[index]
            textField.text = displayed(fieldValues[field.id] ?? "", for: field)
        }

        logoView?.onTap = onPickLogo
        logoView?.onDrop = onDropLogo
        logoView?.setImage(data: logoData)
    }

    @objc private func fieldChanged(_ textField: UITextField) {
        let field = layout.fields[textField.tag]
        let value = normalized(textField.text ?? "", for: field)
        let displayedValue = displayed(value, for: field)
        if textField.text != displayedValue {
            textField.text = displayedValue
        }
        onFieldChange(field.id, value)
    }

    private func normalized(_ value: String, for field: NoteLayoutField) -> String {
        if field.format == .frequency {
            return String(value.filter(\.isNumber).prefix(6))
        }
        return value.uppercased()
    }

    private func displayed(_ value: String, for field: NoteLayoutField) -> String {
        guard field.format == .frequency, value.count > 3 else { return value }
        let splitIndex = value.index(value.startIndex, offsetBy: 3)
        return "\(value[..<splitIndex]).\(value[splitIndex...])"
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let nextIndex = textField.tag + 1
        if fieldViews.indices.contains(nextIndex) {
            fieldViews[nextIndex].becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}

private final class CardTextField: UITextField {
    private let textInsets: UIEdgeInsets

    init(frame: CGRect, textInsets: UIEdgeInsets) {
        self.textInsets = textInsets
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: textInsets)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: textInsets)
    }
}

private final class LogoDropView: UIControl, UIDropInteractionDelegate {
    var onTap: () -> Void = {}
    var onDrop: (UIImage) -> Void = { _ in }

    private let imageView = UIImageView()
    private let hintLabel = UILabel()
    private let borderLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        isAccessibilityElement = true
        accessibilityTraits = .button

        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)

        hintLabel.text = "Add logo"
        hintLabel.font = .systemFont(ofSize: 6, weight: .semibold)
        hintLabel.textColor = .secondaryLabel
        hintLabel.textAlignment = .center
        addSubview(hintLabel)

        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.7).cgColor
        borderLayer.lineDashPattern = [3, 2]
        borderLayer.lineWidth = 1
        layer.addSublayer(borderLayer)

        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        addInteraction(UIDropInteraction(delegate: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds.insetBy(dx: 2, dy: 1)
        hintLabel.frame = bounds
        borderLayer.frame = bounds
        borderLayer.path = UIBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            cornerRadius: 3
        ).cgPath
    }

    func setImage(data: Data?) {
        imageView.image = data.flatMap(UIImage.init(data:))
        let hasImage = imageView.image != nil
        hintLabel.isHidden = hasImage
        borderLayer.isHidden = hasImage
        accessibilityLabel = hasImage ? "Replace logo" : "Add logo"
    }

    @objc private func tapped() {
        onTap()
    }

    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        session.canLoadObjects(ofClass: UIImage.self)
    }

    func dropInteraction(
        _ interaction: UIDropInteraction,
        sessionDidUpdate session: UIDropSession
    ) -> UIDropProposal {
        UIDropProposal(operation: .copy)
    }

    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        session.loadObjects(ofClass: UIImage.self) { [weak self] objects in
            guard let image = objects.first as? UIImage else { return }
            self?.onDrop(image)
        }
    }
}

private extension LayoutTextAlignment {
    var textAlignment: NSTextAlignment {
        switch self {
        case .leading: .left
        case .center: .center
        case .trailing: .right
        }
    }
}
