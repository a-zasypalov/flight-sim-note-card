import SwiftUI
import XCTest
@testable import Pilot_Notes

@MainActor
final class NoteEditorTests: XCTestCase {
    func testZoomedTypingReturnAndFocusHandoff() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousWindow = scene.keyWindow
        let window = UIWindow(windowScene: scene)
        var isEditing = false
        var values: [String: String] = [:]
        let pdfURL = try XCTUnwrap(NoteLayout.vatsimFlightCard.pdfURL)
        func configuration() -> NoteTemplateView {
            NoteTemplateView(
                layout: .vatsimFlightCard, pdfURL: pdfURL,
                fieldValues: [:], writingRegionValues: values, logoData: nil,
                onFieldChange: { _, _ in },
                onWritingRegionChange: { values[$0] = $1 },
                onPickLogo: {}, onDropLogo: { _ in },
                isEditing: Binding(get: { isEditing }, set: { isEditing = $0 })
            )
        }
        let canvas = NoteCanvasView(template: configuration())
        let controller = UIViewController()
        controller.view = canvas
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            window.endEditing(true)
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
        }
        try await Task.sleep(for: .milliseconds(300))
        canvas.layoutIfNeeded()

        let regions = descendants(of: canvas).compactMap { $0 as? UITextView }
        let first = try XCTUnwrap(regions.first { $0.accessibilityLabel == "Pushback and departure taxi" })
        let second = try XCTUnwrap(regions.first { $0.accessibilityLabel == "In-flight notes" })
        let scrollView = canvas.scrollView
        let fittedScale = scrollView.zoomScale
        let editingScale: CGFloat = 2.5
        scrollView.setZoomScale(editingScale, animated: false)
        XCTAssertTrue(first.becomeFirstResponder())
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertTrue(isEditing)

        var observedOffsets: [CGFloat] = []
        let observation = scrollView.observe(\.contentOffset, options: [.new]) { view, _ in
            observedOffsets.append(view.contentOffset.x)
        }
        var lastOffset = scrollView.contentOffset.x
        for letter in "Test text test text test text test text test text" {
            first.insertText(String(letter))
            canvas.update(configuration())
            try await Task.sleep(for: .milliseconds(40))
            XCTAssertTrue(first.isFirstResponder)
            XCTAssertEqual(scrollView.zoomScale, editingScale, accuracy: 0.001)
            XCTAssertGreaterThanOrEqual(scrollView.contentOffset.x, lastOffset - 0.5)
            lastOffset = scrollView.contentOffset.x
            assertCaretVisible(first, in: scrollView)
        }
        observation.invalidate()
        for (previous, next) in zip(observedOffsets, observedOffsets.dropFirst()) {
            XCTAssertGreaterThanOrEqual(next, previous - 0.5, "Typing must not scroll right and then snap back")
        }
        let beforeReturn = first.caretRect(for: first.endOfDocument)
        first.insertText("\n")
        try await Task.sleep(for: .milliseconds(150))
        let afterReturn = first.caretRect(for: first.endOfDocument)
        let font = try XCTUnwrap(first.typingAttributes[.font] as? UIFont)
        XCTAssertEqual(afterReturn.height, font.lineHeight, accuracy: 0.5)
        XCTAssertEqual(afterReturn.height, beforeReturn.height, accuracy: 0.5)
        XCTAssertGreaterThan(afterReturn.minY, beforeReturn.minY)
        XCTAssertLessThan(scrollView.contentOffset.x, lastOffset)
        assertCaretVisible(first, in: scrollView)
        let restingOffset = scrollView.contentOffset
        first.insertText("Next line")
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(scrollView.contentOffset.x, restingOffset.x, accuracy: 0.5)
        XCTAssertEqual(scrollView.contentOffset.y, restingOffset.y, accuracy: 0.5)

        XCTAssertTrue(second.becomeFirstResponder())
        second.insertText("In flight")
        second.resignFirstResponder()
        try await Task.sleep(for: .milliseconds(350))
        XCTAssertTrue(isEditing, "A temporary responder gap must not end the editing session")
        XCTAssertEqual(scrollView.zoomScale, editingScale, accuracy: 0.001)
        XCTAssertTrue(first.becomeFirstResponder())
        first.insertText(" again")
        canvas.update(configuration())
        try await Task.sleep(for: .milliseconds(350))
        XCTAssertEqual(scrollView.zoomScale, editingScale, accuracy: 0.001)
        XCTAssertEqual(values["pushbackTaxi"], first.text)
        XCTAssertEqual(values["inFlight"], "In flight")
        assertCaretVisible(first, in: scrollView)

        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: canvas.bounds).image { _ in
            canvas.drawHierarchy(in: canvas.bounds, afterScreenUpdates: true)
        })
        attachment.name = "Zoomed multiline editor after switching fields"
        attachment.lifetime = .keepAlways
        add(attachment)

        first.selectedRange = NSRange(location: 0, length: (first.text as NSString).length)
        first.insertText("HEAD\nTAIL")
        try await Task.sleep(for: .milliseconds(100))
        first.undoManager?.removeAllActions()
        first.selectedRange = NSRange(location: 0, length: 4)
        let emoji = "👨‍👩‍👧‍👦"
        first.insertText(String(repeating: emoji, count: 500))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(first.text.hasSuffix("\nTAIL"))
        XCTAssertTrue(first.text.dropLast(5).allSatisfy { $0 == Character(emoji) })
        XCTAssertLessThan(first.text.count, 500)
        XCTAssertTrue(first.undoManager?.canUndo == true)
        first.undoManager?.undo()
        XCTAssertEqual(first.text, "HEAD\nTAIL")

        isEditing = false
        canvas.update(configuration())
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertFalse(first.isFirstResponder)
        XCTAssertEqual(scrollView.zoomScale, fittedScale, accuracy: 0.01)
    }

    private func assertCaretVisible(_ textView: UITextView, in scrollView: UIScrollView) {
        let caret = textView.convert(textView.caretRect(for: textView.endOfDocument), to: scrollView)
        XCTAssertTrue(scrollView.bounds.contains(caret.insetBy(dx: -12, dy: -8)))
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}
