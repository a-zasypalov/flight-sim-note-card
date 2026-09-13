import Foundation

struct NoteLayout: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let revision: Int
    let name: String
    let pdfResource: String
    let pageSize: LayoutSize
    let cardFrame: LayoutRect
    let fields: [NoteLayoutField]
    let writingRegions: [NoteLayoutRegion]

    static let vatsimFlightCard = load("vatsim-flight-card-a5-v1")
    static let available = [vatsimFlightCard]

    var pdfURL: URL? {
        Self.resourceURL(named: pdfResource, extension: "pdf")
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
