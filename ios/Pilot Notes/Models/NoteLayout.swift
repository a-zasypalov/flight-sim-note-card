import CoreGraphics
import Foundation

struct NoteLayout: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let revision: Int
    let name: String
    let pdfResource: String
    let pageSize: LayoutSize
    let cardFrame: LayoutRect
    let logoFrame: LayoutRect?
    let fields: [NoteLayoutField]
    let writingRegions: [NoteLayoutRegion]

    static let vatsimFlightCard = load("vatsim-flight-card-a5-v1")
    static let available = [vatsimFlightCard]

    var pdfURL: URL? {
        Self.resourceURL(named: pdfResource, extension: "pdf")
    }

    func pageRect(for rect: LayoutRect, in bounds: CGRect) -> CGRect {
        let widthScale = bounds.width / CGFloat(pageSize.width)
        let heightScale = bounds.height / CGFloat(pageSize.height)
        let x = CGFloat(cardFrame.x + rect.x) * widthScale
        let bottom = CGFloat(cardFrame.y + rect.y) * heightScale

        return CGRect(
            x: bounds.minX + x,
            y: bounds.maxY - bottom - CGFloat(rect.height) * heightScale,
            width: CGFloat(rect.width) * widthScale,
            height: CGFloat(rect.height) * heightScale
        )
    }

    private static func load(_ resource: String) -> NoteLayout {
        guard let url = resourceURL(named: resource, extension: "json") else {
            fatalError("Missing layout resource: \(resource).json")
        }

        do {
            return try JSONDecoder().decode(NoteLayout.self, from: Data(contentsOf: url))
        } catch {
            fatalError("Invalid layout resource: \(resource).json (\(error))")
        }
    }

    private static func resourceURL(named name: String, extension fileExtension: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "Layouts")
            ?? Bundle.main.url(forResource: name, withExtension: fileExtension)
    }
}

struct NoteLayoutField: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let label: String
    let frame: LayoutRect
    let alignment: LayoutTextAlignment
    let fontSize: Double?
    let format: NoteFieldFormat?

    var valueFrame: LayoutRect {
        LayoutRect(
            x: frame.x + 1,
            y: frame.y + 1.8,
            width: frame.width - 2,
            height: frame.height - 4
        )
    }
}

struct NoteLayoutRegion: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let label: String
    let frame: LayoutRect
}

struct LayoutSize: Codable, Hashable, Sendable {
    let width: Double
    let height: Double
}

struct LayoutRect: Codable, Hashable, Sendable {
    // Millimetres from the card's bottom-left corner.
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

enum LayoutTextAlignment: String, Codable, Hashable, Sendable {
    case leading
    case center
    case trailing
}

enum NoteFieldFormat: String, Codable, Hashable, Sendable {
    case frequency
}
