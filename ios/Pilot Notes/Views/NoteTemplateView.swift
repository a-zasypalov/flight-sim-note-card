import PDFKit
import SwiftUI

struct NoteTemplateView: View {
    let layout: NoteLayout
    let pdfURL: URL
    let fieldValues: [NoteLayoutField.ID: String]
    let writingRegionValues: [NoteLayoutRegion.ID: String]
    let logoData: Data?
    let onFieldChange: (NoteLayoutField.ID, String) -> Void
    let onWritingRegionChange: (NoteLayoutRegion.ID, String) -> Void
    let onPickLogo: () -> Void
    let onDropLogo: (UIImage) -> Void
    let onEditingChange: (Bool) -> Void

    var body: some View {
        PDFNoteTemplateView(
            layout: layout,
            pdfURL: pdfURL,
            fieldValues: fieldValues,
            writingRegionValues: writingRegionValues,
            logoData: logoData,
            onFieldChange: onFieldChange,
            onWritingRegionChange: onWritingRegionChange,
            onPickLogo: onPickLogo,
            onDropLogo: onDropLogo,
            onEditingChange: onEditingChange
        )
    }
}

private struct PDFNoteTemplateView: UIViewRepresentable {
    let layout: NoteLayout
    let pdfURL: URL
    let fieldValues: [NoteLayoutField.ID: String]
    let writingRegionValues: [NoteLayoutRegion.ID: String]
    let logoData: Data?
    let onFieldChange: (NoteLayoutField.ID, String) -> Void
    let onWritingRegionChange: (NoteLayoutRegion.ID, String) -> Void
    let onPickLogo: () -> Void
    let onDropLogo: (UIImage) -> Void
    let onEditingChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = NotePDFView()
        pdfView.displayBox = .mediaBox
        pdfView.displayMode = .singlePage
        pdfView.pageOverlayViewProvider = context.coordinator
        pdfView.document = PDFDocument(url: pdfURL)
        pdfView.autoScales = true
        context.coordinator.observeZoomGesture(in: pdfView)
        context.coordinator.observeKeyboard()
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        context.coordinator.update(self)
    }

    static func dismantleUIView(_ pdfView: PDFView, coordinator: Coordinator) {
        coordinator.stopObservingZoomGesture()
        coordinator.stopObservingKeyboard()
    }

    final class Coordinator: NSObject, PDFPageOverlayViewProvider {
        private var parent: PDFNoteTemplateView
        private weak var pdfView: PDFView?
        private weak var pinchGestureRecognizer: UIPinchGestureRecognizer?
        private var overlayView: NoteEditorOverlayView?
        private var keyboardOverlap: CGFloat = 0
        private var isEditing = false
        private var isFocusUpdateScheduled = false

        init(_ parent: PDFNoteTemplateView) {
            self.parent = parent
        }

        func observeZoomGesture(in pdfView: PDFView) {
            self.pdfView = pdfView
            guard
                let pinchGestureRecognizer = scrollView(in: pdfView)?.pinchGestureRecognizer,
                pinchGestureRecognizer !== self.pinchGestureRecognizer
            else { return }

            stopObservingZoomGesture()
            self.pinchGestureRecognizer = pinchGestureRecognizer
            pinchGestureRecognizer.addTarget(self, action: #selector(zoomGestureChanged(_:)))
        }

        func stopObservingZoomGesture() {
            pinchGestureRecognizer?.removeTarget(self, action: #selector(zoomGestureChanged(_:)))
            pinchGestureRecognizer = nil
        }

        func observeKeyboard() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardFrameChanged(_:)),
                name: UIResponder.keyboardWillChangeFrameNotification,
                object: nil
            )
        }

        func stopObservingKeyboard() {
            NotificationCenter.default.removeObserver(
                self,
                name: UIResponder.keyboardWillChangeFrameNotification,
                object: nil
            )
        }

        func update(_ parent: PDFNoteTemplateView) {
            self.parent = parent
            overlayView?.update(
                fieldValues: parent.fieldValues,
                writingRegionValues: parent.writingRegionValues,
                logoData: parent.logoData,
                onFieldChange: parent.onFieldChange,
                onWritingRegionChange: parent.onWritingRegionChange,
                onPickLogo: parent.onPickLogo,
                onDropLogo: parent.onDropLogo
            )
        }

        func pdfView(_ pdfView: PDFView, overlayViewFor page: PDFPage) -> UIView? {
            observeZoomGesture(in: pdfView)
            pdfView.documentView?.subviews.forEach { $0.isUserInteractionEnabled = true }
            let overlayView = NoteEditorOverlayView(
                layout: parent.layout,
                pageBounds: page.bounds(for: .mediaBox),
                fieldValues: parent.fieldValues,
                writingRegionValues: parent.writingRegionValues,
                logoData: parent.logoData,
                onFieldChange: parent.onFieldChange,
                onWritingRegionChange: parent.onWritingRegionChange,
                onPickLogo: parent.onPickLogo,
                onDropLogo: parent.onDropLogo,
                onFocus: { [weak self] view in
                    self?.reveal(view, animated: true)
                },
                onFocusChange: { [weak self] in
                    self?.scheduleFocusUpdate()
                }
            )
            self.overlayView = overlayView
            updateContentScale(for: pdfView)
            return overlayView
        }

        @objc private func zoomGestureChanged(_ gesture: UIPinchGestureRecognizer) {
            guard [.ended, .cancelled, .failed].contains(gesture.state) else { return }
            guard let pdfView else { return }
            updateContentScale(for: pdfView)
        }

        @objc private func keyboardFrameChanged(_ notification: Notification) {
            guard
                let pdfView,
                let scrollView = scrollView(in: pdfView),
                let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                    as? CGRect
            else { return }

            let localFrame = pdfView.convert(keyboardFrame, from: nil)
            let overlap = localFrame.intersects(pdfView.bounds)
                ? max(0, pdfView.bounds.maxY - localFrame.minY)
                : 0
            let delta = overlap - keyboardOverlap
            keyboardOverlap = overlap

            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey]
                as? Double ?? 0
            UIView.animate(withDuration: duration, delay: 0, options: .beginFromCurrentState) {
                scrollView.contentInset.top += delta
                scrollView.contentInset.bottom += delta
                scrollView.verticalScrollIndicatorInsets.bottom += delta
            }
        }

        private func scheduleFocusUpdate() {
            guard !isFocusUpdateScheduled else { return }
            isFocusUpdateScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                isFocusUpdateScheduled = false
                let hasFocus = overlayView?.focusedView != nil
                guard hasFocus != isEditing else { return }
                isEditing = hasFocus
                parent.onEditingChange(hasFocus)
                if !hasFocus {
                    zoomToFit()
                }
            }
        }

        private func zoomToFit() {
            guard let pdfView else { return }

            UIView.animate(withDuration: 0.3, delay: 0, options: .beginFromCurrentState) {
                pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
            } completion: { [weak self] _ in
                self?.updateContentScale(for: pdfView)
            }
        }

        private func updateContentScale(for pdfView: PDFView) {
            overlayView?.updateContentScale(
                pdfView.traitCollection.displayScale * pdfView.scaleFactor
            )
        }

        private func reveal(_ view: UIView, animated: Bool) {
            guard let pdfView, let scrollView = scrollView(in: pdfView) else { return }

            DispatchQueue.main.async { [weak view, weak scrollView] in
                guard let view, let scrollView else { return }
                let rect = view.convert(view.bounds, to: scrollView).insetBy(dx: -12, dy: -12)
                scrollView.scrollRectToVisible(rect, animated: animated)
            }
        }

        private func scrollView(in view: UIView) -> UIScrollView? {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
            return view.subviews.lazy.compactMap { self.scrollView(in: $0) }.first
        }
    }
}

private final class NotePDFView: PDFView {
    private let minimumScaleRatio: CGFloat = 0.8

    override func layoutSubviews() {
        super.layoutSubviews()
        let minimumScale = scaleFactorForSizeToFit * minimumScaleRatio
        guard minimumScale > 0 else { return }

        if abs(minScaleFactor - minimumScale) > 0.001 {
            minScaleFactor = minimumScale
        }
        if scaleFactor < minimumScale {
            scaleFactor = minimumScale
        }
    }
}

private final class NoteEditorOverlayView: UIView, UITextFieldDelegate, UITextViewDelegate {
    private let layout: NoteLayout
    private let pageBounds: CGRect
    private var fieldViews: [UITextField] = []
    private var writingRegionViews: [UITextView] = []
    private var logoView: LogoDropView?
    private var onFieldChange: (NoteLayoutField.ID, String) -> Void
    private var onWritingRegionChange: (NoteLayoutRegion.ID, String) -> Void
    private let onFocus: (UIView) -> Void
    private let onFocusChange: () -> Void
    private var currentContentScale: CGFloat = 1
    private var isContentScaleUpdateScheduled = false

    init(
        layout: NoteLayout,
        pageBounds: CGRect,
        fieldValues: [NoteLayoutField.ID: String],
        writingRegionValues: [NoteLayoutRegion.ID: String],
        logoData: Data?,
        onFieldChange: @escaping (NoteLayoutField.ID, String) -> Void,
        onWritingRegionChange: @escaping (NoteLayoutRegion.ID, String) -> Void,
        onPickLogo: @escaping () -> Void,
        onDropLogo: @escaping (UIImage) -> Void,
        onFocus: @escaping (UIView) -> Void,
        onFocusChange: @escaping () -> Void
    ) {
        self.layout = layout
        self.pageBounds = pageBounds
        self.onFieldChange = onFieldChange
        self.onWritingRegionChange = onWritingRegionChange
        self.onFocus = onFocus
        self.onFocusChange = onFocusChange
        super.init(frame: pageBounds)
        backgroundColor = .clear

        for (index, region) in layout.writingRegions.enumerated() {
            let textView = UITextView(frame: layout.pageRect(for: region.frame, in: pageBounds))
            textView.tag = index
            setWritingText(writingRegionValues[region.id] ?? "", in: textView, for: region)
            textView.backgroundColor = .clear
            textView.isScrollEnabled = false
            textView.autocorrectionType = .no
            textView.spellCheckingType = .no
            textView.smartDashesType = .no
            textView.smartQuotesType = .no
            textView.keyboardType = .asciiCapable
            textView.accessibilityLabel = region.label
            textView.delegate = self
            writingRegionViews.append(textView)
            addSubview(textView)
        }

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

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for subview in subviews.reversed() {
            let convertedPoint = subview.convert(point, from: self)
            if let hitView = subview.hitTest(convertedPoint, with: event) {
                return hitView
            }
        }
        return nil
    }

    var focusedView: UIView? {
        fieldViews.first(where: \.isFirstResponder)
            ?? writingRegionViews.first(where: \.isFirstResponder)
    }

    func update(
        fieldValues: [NoteLayoutField.ID: String],
        writingRegionValues: [NoteLayoutRegion.ID: String],
        logoData: Data?,
        onFieldChange: @escaping (NoteLayoutField.ID, String) -> Void,
        onWritingRegionChange: @escaping (NoteLayoutRegion.ID, String) -> Void,
        onPickLogo: @escaping () -> Void,
        onDropLogo: @escaping (UIImage) -> Void
    ) {
        self.onFieldChange = onFieldChange
        self.onWritingRegionChange = onWritingRegionChange
        var textChanged = false

        for (index, textField) in fieldViews.enumerated() where !textField.isFirstResponder {
            let field = layout.fields[index]
            let text = displayed(fieldValues[field.id] ?? "", for: field)
            if textField.text != text {
                textField.text = text
                textChanged = true
            }
        }

        for (index, textView) in writingRegionViews.enumerated() where !textView.isFirstResponder {
            let region = layout.writingRegions[index]
            let text = writingRegionValues[region.id] ?? ""
            if textView.text != text {
                setWritingText(text, in: textView, for: region)
                textChanged = true
            }
        }

        logoView?.onTap = onPickLogo
        logoView?.onDrop = onDropLogo
        logoView?.setImage(data: logoData)

        if textChanged {
            scheduleContentScaleUpdate()
        }
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

    func textViewDidChange(_ textView: UITextView) {
        onWritingRegionChange(layout.writingRegions[textView.tag].id, textView.text)
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        scheduleContentScaleUpdate()
        onFocusChange()
        onFocus(textField)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        scheduleContentScaleUpdate()
        onFocusChange()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        scheduleContentScaleUpdate()
        onFocusChange()
        onFocus(textView)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        scheduleContentScaleUpdate()
        onFocusChange()
    }

    private func setWritingText(
        _ value: String,
        in textView: UITextView,
        for region: NoteLayoutRegion
    ) {
        let scale = pageBounds.height / CGFloat(layout.pageSize.height)
        let fontSize = CGFloat(region.fontSize ?? 8.5)
        let font = UIFont(name: "Courier", size: fontSize)
            ?? UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = max(0, CGFloat(region.baselineSpacing) * scale - font.lineHeight)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(white: 0.16, alpha: 1),
            .paragraphStyle: paragraph
        ]

        textView.textContainerInset = UIEdgeInsets(
            top: max(0, CGFloat(region.firstBaselineOffset) * scale - font.ascender),
            left: scale,
            bottom: 0,
            right: scale
        )
        textView.textContainer.lineFragmentPadding = 0
        textView.attributedText = NSAttributedString(string: value, attributes: attributes)
        textView.typingAttributes = attributes
    }

    func updateContentScale(_ scale: CGFloat) {
        currentContentScale = scale
        for view in fieldViews {
            updateContentScale(scale, in: view)
        }
        for view in writingRegionViews {
            updateContentScale(scale, in: view)
        }
    }

    private func updateContentScale(_ scale: CGFloat, in view: UIView) {
        view.contentScaleFactor = scale
        view.layer.contentsScale = scale
        view.setNeedsDisplay()
        view.subviews.forEach { updateContentScale(scale, in: $0) }
    }

    private func scheduleContentScaleUpdate() {
        guard !isContentScaleUpdateScheduled else { return }
        isContentScaleUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            isContentScaleUpdateScheduled = false
            updateContentScale(currentContentScale)
        }
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
        return "\(value[..<splitIndex]) \(value[splitIndex...])"
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
