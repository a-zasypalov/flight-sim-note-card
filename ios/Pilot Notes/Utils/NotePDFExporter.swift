import CoreGraphics
import SwiftUI
import UniformTypeIdentifiers

struct NotePDFDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw NotePDFExportError.invalidDocument
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum NotePDFExporter {
    static func document(for note: Note, layout: NoteLayout) throws -> NotePDFDocument {
        guard
            let pdfURL = layout.pdfURL,
            let source = CGPDFDocument(pdfURL as CFURL),
            let page = source.page(at: 1)
        else {
            throw NotePDFExportError.invalidDocument
        }

        let sourceBounds = page.getBoxRect(.mediaBox)
        let pageBounds = CGRect(origin: .zero, size: sourceBounds.size)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let data = renderer.pdfData { context in
            context.beginPage()

            let graphicsContext = context.cgContext
            graphicsContext.saveGState()
            graphicsContext.translateBy(x: 0, y: pageBounds.height)
            graphicsContext.scaleBy(x: 1, y: -1)
            graphicsContext.translateBy(x: -sourceBounds.minX, y: -sourceBounds.minY)
            graphicsContext.drawPDFPage(page)
            graphicsContext.restoreGState()

            drawLogo(note.content.logoData, layout: layout, pageBounds: pageBounds)
            drawWritingRegions(note.content.writingRegionValues, layout: layout, pageBounds: pageBounds)
            drawFields(note.content.fieldValues, layout: layout, pageBounds: pageBounds)
        }

        return NotePDFDocument(data: data)
    }

    private static func drawLogo(_ data: Data?, layout: NoteLayout, pageBounds: CGRect) {
        guard let logoFrame = layout.logoFrame else { return }
        let frame = layout.pageRect(for: logoFrame, in: pageBounds)
        UIColor.white.setFill()
        UIRectFill(frame)

        guard let data, let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
            return
        }

        let scale = min(frame.width / image.size.width, frame.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let imageFrame = CGRect(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        image.draw(in: imageFrame)
    }

    private static func drawWritingRegions(
        _ values: [NoteLayoutRegion.ID: String],
        layout: NoteLayout,
        pageBounds: CGRect
    ) {
        let scale = pageBounds.height / CGFloat(layout.pageSize.height)

        for region in layout.writingRegions {
            guard let value = values[region.id], !value.isEmpty else { continue }
            let fontSize = CGFloat(region.fontSize ?? 8.5)
            let font = UIFont(name: "Courier", size: fontSize)
                ?? UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            let lineHeight = CGFloat(region.baselineSpacing) * scale
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            paragraph.minimumLineHeight = lineHeight
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(white: 0.16, alpha: 1),
                .paragraphStyle: paragraph
            ]
            let regionFrame = layout.pageRect(for: region.frame, in: pageBounds)
            let top = regionFrame.minY
                + CGFloat(region.firstBaselineOffset) * scale
                - lineHeight
                - font.descender
            let frame = CGRect(
                x: regionFrame.minX + scale,
                y: top,
                width: regionFrame.width - 2 * scale,
                height: regionFrame.maxY - top
            )
            (value as NSString).draw(in: frame, withAttributes: attributes)
        }
    }

    private static func drawFields(
        _ values: [NoteLayoutField.ID: String],
        layout: NoteLayout,
        pageBounds: CGRect
    ) {
        for field in layout.fields {
            guard let value = values[field.id], !value.isEmpty else { continue }
            let frame = layout.pageRect(for: field.valueFrame, in: pageBounds)
            let fontSize = CGFloat(field.fontSize ?? 7.4)

            if field.format == .frequency {
                drawFrequency(value, in: frame, fontSize: fontSize)
            } else {
                draw(value, in: frame, alignment: field.alignment.textAlignment, fontSize: fontSize)
            }
        }
    }

    private static func drawFrequency(_ value: String, in frame: CGRect, fontSize: CGFloat) {
        let digits = String(value.filter(\.isNumber).prefix(6))
        let splitIndex = digits.index(digits.startIndex, offsetBy: min(3, digits.count))
        let left = String(digits[..<splitIndex])
        let right = String(digits[splitIndex...])
        let gap: CGFloat = 1.5

        draw(
            left,
            in: CGRect(x: frame.minX, y: frame.minY, width: frame.width / 2 - gap, height: frame.height),
            alignment: .right,
            fontSize: fontSize
        )
        draw(
            right,
            in: CGRect(x: frame.midX + gap, y: frame.minY, width: frame.width / 2 - gap, height: frame.height),
            alignment: .left,
            fontSize: fontSize
        )
    }

    private static func draw(
        _ value: String,
        in frame: CGRect,
        alignment: NSTextAlignment,
        fontSize: CGFloat
    ) {
        guard !value.isEmpty else { return }
        let font = fittedFont(for: value, width: frame.width, size: fontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byClipping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(white: 0.16, alpha: 1),
            .paragraphStyle: paragraph
        ]
        let lineFrame = CGRect(
            x: frame.minX,
            y: frame.maxY - font.lineHeight,
            width: frame.width,
            height: font.lineHeight
        )
        (value as NSString).draw(in: lineFrame, withAttributes: attributes)
    }

    private static func fittedFont(for value: String, width: CGFloat, size: CGFloat) -> UIFont {
        let font = UIFont(name: "Courier", size: size) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
        let measuredWidth = (value as NSString).size(withAttributes: [.font: font]).width
        guard measuredWidth > width, measuredWidth > 0 else { return font }
        let fittedSize = max(5, size * width / measuredWidth)
        return UIFont(name: "Courier", size: fittedSize)
            ?? .monospacedSystemFont(ofSize: fittedSize, weight: .regular)
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

enum NotePDFExportError: LocalizedError {
    case invalidDocument

    var errorDescription: String? {
        "The PDF template could not be exported."
    }
}
