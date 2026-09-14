import SwiftUI

struct NoteTemplateView: UIViewRepresentable {
    let layout: NoteLayout
    let pdfURL: URL
    let fieldValues: [NoteLayoutField.ID: String]
    let writingRegionValues: [NoteLayoutRegion.ID: String]
    let logoData: Data?
    let onFieldChange: (NoteLayoutField.ID, String) -> Void
    let onWritingRegionChange: (NoteLayoutRegion.ID, String) -> Void
    let onPickLogo: () -> Void
    let onDropLogo: (UIImage) -> Void
    @Binding var isEditing: Bool

    func makeUIView(context: Context) -> NoteCanvasView {
        NoteCanvasView(template: self)
    }

    func updateUIView(_ view: NoteCanvasView, context: Context) {
        view.update(self)
    }
}

final class NoteCanvasView: UIView, UIScrollViewDelegate {
    let scrollView = UIScrollView()
    private let pageView = UIView()
    private var overlayView: NoteEditorOverlayView!
    private var template: NoteTemplateView
    private var hasEditingSession = false
    private var fittedSize = CGSize.zero

    init(template: NoteTemplateView) {
        self.template = template
        super.init(frame: .zero)
        backgroundColor = .secondarySystemBackground

        scrollView.delegate = self
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.keyboardDismissMode = .none
        scrollView.delaysContentTouches = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor)
        ])

        guard let document = CGPDFDocument(template.pdfURL as CFURL),
              let page = document.page(at: 1) else { return }
        pageView.bounds = CGRect(origin: .zero, size: page.getBoxRect(.mediaBox).size)
        pageView.frame.origin = .zero
        pageView.addSubview(NotePDFBackgroundView(page: page))
        scrollView.addSubview(pageView)
        scrollView.contentSize = pageView.bounds.size

        overlayView = NoteEditorOverlayView(
            layout: template.layout,
            pageBounds: pageView.bounds,
            fieldValues: template.fieldValues,
            writingRegionValues: template.writingRegionValues,
            logoData: template.logoData,
            onFieldChange: template.onFieldChange,
            onWritingRegionChange: template.onWritingRegionChange,
            onPickLogo: template.onPickLogo,
            onDropLogo: template.onDropLogo,
            onFocus: { [weak self] fitsWidth in
                guard let self else { return }
                hasEditingSession = true
                self.template.isEditing = true
                if fitsWidth {
                    if scrollView.zoomScale > widthFitScale {
                        scrollView.setZoomScale(widthFitScale, animated: true)
                    }
                    scrollView.maximumZoomScale = widthFitScale
                } else {
                    scrollView.maximumZoomScale = max(4, fitScale * 6)
                }
            },
            onDone: { [weak self] in self?.template.isEditing = false }
        )
        pageView.addSubview(overlayView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(_ template: NoteTemplateView) {
        self.template = template
        if hasEditingSession && !template.isEditing {
            hasEditingSession = false
            endEditing(true)
            scrollView.setZoomScale(fitScale, animated: true)
        }
        overlayView?.update(
            fieldValues: template.fieldValues,
            writingRegionValues: template.writingRegionValues,
            logoData: template.logoData,
            onFieldChange: template.onFieldChange,
            onWritingRegionChange: template.onWritingRegionChange,
            onPickLogo: template.onPickLogo,
            onDropLogo: template.onDropLogo
        )
    }

    private var fitScale: CGFloat {
        guard pageView.bounds.width > 0, pageView.bounds.height > 0 else { return 1 }
        let available = bounds.inset(by: safeAreaInsets).insetBy(dx: 12, dy: 12)
        return min(available.width / pageView.bounds.width, available.height / pageView.bounds.height)
    }

    private var widthFitScale: CGFloat {
        guard pageView.bounds.width > 0 else { return 1 }
        return bounds.inset(by: safeAreaInsets).insetBy(dx: 12, dy: 12).width
            / pageView.bounds.width
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0, overlayView != nil else { return }
        if fittedSize != bounds.size {
            let initialLayout = fittedSize == .zero
            fittedSize = bounds.size
            scrollView.minimumZoomScale = fitScale * 0.8
            scrollView.maximumZoomScale = max(4, fitScale * 6)
            if initialLayout {
                scrollView.zoomScale = fitScale
                overlayView.updateContentScale(traitCollection.displayScale * scrollView.zoomScale)
            }
        }
        centerPage()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        pageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerPage()
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        overlayView?.updateContentScale(traitCollection.displayScale * scale)
    }

    private func centerPage() {
        let horizontal = max(12, (scrollView.bounds.width - scrollView.contentSize.width) / 2)
        let vertical = max(12, (scrollView.bounds.height - scrollView.contentSize.height) / 2)
        let insets = UIEdgeInsets(
            top: vertical, left: horizontal, bottom: vertical, right: horizontal
        )
        if scrollView.contentInset != insets {
            scrollView.contentInset = insets
        }
    }
}

private final class NotePDFBackgroundView: UIView {
    private let page: CGPDFPage

    override class var layerClass: AnyClass { CATiledLayer.self }

    init(page: CGPDFPage) {
        self.page = page
        super.init(frame: CGRect(origin: .zero, size: page.getBoxRect(.mediaBox).size))
        backgroundColor = .white
        isUserInteractionEnabled = false
        let tiles = layer as! CATiledLayer
        tiles.levelsOfDetail = 4
        tiles.levelsOfDetailBias = 4
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setFillColor(UIColor.white.cgColor)
        context.fill(rect)
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        let sourceBounds = page.getBoxRect(.mediaBox)
        context.translateBy(x: -sourceBounds.minX, y: -sourceBounds.minY)
        context.drawPDFPage(page)
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
    private let onFocus: (Bool) -> Void
    private let onDone: () -> Void

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
        onFocus: @escaping (Bool) -> Void,
        onDone: @escaping () -> Void
    ) {
        self.layout = layout
        self.pageBounds = pageBounds
        self.onFieldChange = onFieldChange
        self.onWritingRegionChange = onWritingRegionChange
        self.onFocus = onFocus
        self.onDone = onDone
        super.init(frame: pageBounds)
        backgroundColor = .clear

        for (index, region) in layout.writingRegions.enumerated() {
            let textView = WritingTextView(
                frame: layout.pageRect(for: region.frame, in: pageBounds)
            )
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

        for (index, textField) in fieldViews.enumerated() where !textField.isFirstResponder {
            let field = layout.fields[index]
            let text = displayed(fieldValues[field.id] ?? "", for: field)
            if textField.text != text {
                textField.text = text
            }
        }

        for (index, textView) in writingRegionViews.enumerated() where !textView.isFirstResponder {
            let region = layout.writingRegions[index]
            let text = writingRegionValues[region.id] ?? ""
            if textView.text != text {
                setWritingText(text, in: textView, for: region)
            }
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

    func textViewDidChange(_ textView: UITextView) {
        onWritingRegionChange(layout.writingRegions[textView.tag].id, textView.text)
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        onFocus(false)
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        onFocus(true)
    }

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        guard let replacement = WritingRegionTextLimiter.fittingReplacement(
            text,
            in: textView,
            replacing: range
        ) else { return false }
        guard replacement != text else { return true }
        guard range.length > 0 || !replacement.isEmpty else { return false }

        guard let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
              let end = textView.position(from: start, offset: range.length),
              let selection = textView.textRange(from: start, to: end) else { return false }
        textView.replace(selection, withText: replacement)
        textViewDidChange(textView)
        return false
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
        let lineHeight = CGFloat(region.baselineSpacing) * scale
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(white: 0.16, alpha: 1),
            .paragraphStyle: paragraph
        ]

        textView.textContainerInset = UIEdgeInsets(
            top: max(0, CGFloat(region.firstBaselineOffset) * scale - lineHeight - font.descender),
            left: scale,
            bottom: 0,
            right: scale
        )
        textView.textContainer.lineFragmentPadding = 0
        textView.attributedText = NSAttributedString(string: value, attributes: attributes)
        textView.typingAttributes = attributes
    }

    func updateContentScale(_ scale: CGFloat) {
        for view in fieldViews {
            view.contentScaleFactor = scale
        }
        for view in writingRegionViews {
            view.contentScaleFactor = scale
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
            onDone()
        }
        return true
    }
}

private final class WritingTextView: UITextView {
    override func caretRect(for position: UITextPosition) -> CGRect {
        var rect = super.caretRect(for: position)
        guard
            let font = typingAttributes[.font] as? UIFont,
            rect.height > font.lineHeight
        else { return rect }
        rect.origin.y = rect.maxY - font.lineHeight
        rect.size.height = font.lineHeight
        return rect
    }
}

enum WritingRegionTextLimiter {
    static func fittingReplacement(
        _ replacement: String,
        in textView: UITextView,
        replacing range: NSRange
    ) -> String? {
        let current = textView.text ?? ""
        guard let stringRange = Range(range, in: current) else { return nil }

        func candidate(_ prefix: Substring) -> String {
            current.replacingCharacters(in: stringRange, with: prefix)
        }

        guard !replacement.isEmpty else { return replacement }
        guard !fits(candidate(replacement[...]), in: textView) else { return replacement }
        guard fits(candidate(replacement[..<replacement.startIndex]), in: textView) else {
            return ""
        }

        let boundaries = Array(replacement.indices) + [replacement.endIndex]
        var lowerBound = 0
        var upperBound = boundaries.count - 1
        while lowerBound < upperBound {
            let index = (lowerBound + upperBound + 1) / 2
            if fits(candidate(replacement[..<boundaries[index]]), in: textView) {
                lowerBound = index
            } else {
                upperBound = index - 1
            }
        }
        return String(replacement[..<boundaries[lowerBound]])
    }

    private static func fits(_ text: String, in textView: UITextView) -> Bool {
        let storage = NSTextStorage(
            attributedString: NSAttributedString(
                string: text,
                attributes: textView.typingAttributes
            )
        )
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(
            size: textView.bounds.inset(by: textView.textContainerInset).size
        )
        container.lineBreakMode = textView.textContainer.lineBreakMode
        container.lineFragmentPadding = textView.textContainer.lineFragmentPadding
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: container)

        let visibleGlyphs = layoutManager.glyphRange(for: container)
        guard NSMaxRange(visibleGlyphs) == layoutManager.numberOfGlyphs else { return false }
        return text.last?.isNewline != true
            || (!layoutManager.extraLineFragmentRect.isEmpty
                && layoutManager.extraLineFragmentRect.maxY <= container.size.height)
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
