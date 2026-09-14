import SwiftUI
import XCTest
@testable import Pilot_Notes

@MainActor
final class NoteEditorTests: XCTestCase {
    func testWritingRegionFocusZoomsToPageWidth() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousWindow = scene.keyWindow
        let window = UIWindow(windowScene: scene)
        var isEditing = false
        let pdfURL = try XCTUnwrap(NoteLayout.vatsimFlightCard.pdfURL)
        let canvas = NoteCanvasView(template: NoteTemplateView(
            layout: .vatsimFlightCard,
            pdfURL: pdfURL,
            fieldValues: [:],
            writingRegionValues: [:],
            logoData: nil,
            onFieldChange: { _, _ in },
            onWritingRegionChange: { _, _ in },
            onPickLogo: {},
            onDropLogo: { _ in },
            isEditing: Binding(get: { isEditing }, set: { isEditing = $0 })
        ))
        let controller = UIViewController()
        controller.view = canvas
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            window.endEditing(true)
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
        }

        try await Task.sleep(for: .milliseconds(100))
        canvas.layoutIfNeeded()
        let textView = try XCTUnwrap(descendants(of: canvas).compactMap { $0 as? UITextView }.first)
        let page = try XCTUnwrap(CGPDFDocument(pdfURL as CFURL)?.page(at: 1))
        let availableWidth = canvas.bounds.inset(by: canvas.safeAreaInsets)
            .insetBy(dx: 12, dy: 12).width
        let expectedScale = availableWidth / page.getBoxRect(.mediaBox).width

        canvas.scrollView.setZoomScale(2.5, animated: false)
        XCTAssertTrue(textView.becomeFirstResponder())
        try await Task.sleep(for: .milliseconds(500))

        XCTAssertTrue(textView.isFirstResponder)
        XCTAssertTrue(isEditing)
        XCTAssertEqual(canvas.scrollView.zoomScale, expectedScale, accuracy: 0.01)
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}
