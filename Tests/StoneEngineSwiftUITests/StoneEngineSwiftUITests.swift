/*
StoneEngineSwiftUITests.swift

SwiftUI ラッパーのテスト。実際に SwiftUI のビュー階層へ載せて確かめる。
*/

import SwiftUI
import XCTest
import stone_engine
@testable import StoneEngineSwiftUI

#if os(iOS)
private typealias PlatformView = UIView
#else
private typealias PlatformView = NSView
#endif

@MainActor
private final class EditorModel: ObservableObject {
    @Published var text: String
    @Published var direction: STDirection

    init(text: String, direction: STDirection) {
        self.text = text
        self.direction = direction
    }
}

private struct EditorHost: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        STTextEditor(text: $model.text, direction: model.direction, fontSize: 16, lineHeightScale: 1.5)
            .frame(width: 300, height: 300)
    }
}

@MainActor
final class StoneEngineSwiftUITests: XCTestCase {

    private var retained = [AnyObject]()

    override func tearDown() async throws {
        await MainActor.run { retained.removeAll() }
        try await super.tearDown()
    }

    private func host<Content: View>(_ content: Content) -> PlatformView {
        let frame = CGRect(x: 0, y: 0, width: 400, height: 400)
        #if os(iOS)
        let controller = UIHostingController(rootView: content)
        let window = UIWindow(frame: frame)
        window.rootViewController = controller
        window.isHidden = false
        retained += [controller, window]
        return controller.view
        #else
        let view = NSHostingView(rootView: content)
        view.frame = frame
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        retained += [window]
        return view
        #endif
    }

    private func settle(_ view: PlatformView) {
        for _ in 0 ..< 3 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            #if os(iOS)
            view.setNeedsLayout()
            view.layoutIfNeeded()
            #else
            view.needsLayout = true
            view.layoutSubtreeIfNeeded()
            #endif
        }
    }

    private func find<T: PlatformView>(_ type: T.Type, in view: PlatformView) -> T? {
        if let view = view as? T { return view }
        for subview in view.subviews {
            if let found = find(type, in: subview) { return found }
        }
        return nil
    }

    private func makeEditor(text: String, direction: STDirection = .lrTb) throws -> (EditorModel, STTextView, PlatformView) {
        let model = EditorModel(text: text, direction: direction)
        let root = host(EditorHost(model: model))
        settle(root)
        return (model, try XCTUnwrap(find(STTextView.self, in: root)), root)
    }

    //--------------------------------------------------------------//
    // MARK: - Label
    //--------------------------------------------------------------//

    func testLabelReceivesValues() throws {
        let root = host(STLabelView("吾輩は猫である", direction: .tbRl, fontSize: 20, lineHeightScale: 2))
        settle(root)

        let label = try XCTUnwrap(find(STLabel.self, in: root))
        XCTAssertEqual(label.text, "吾輩は猫である")
        XCTAssertEqual(label.direction, .tbRl)
        XCTAssertEqual(label.fontSize, 20)
        XCTAssertEqual(label.lineHeightScale, 2)
    }

    func testLabelSizeWrapsLinesInProposedLength() {
        let label = STLabel(frame: .zero)
        label.fontSize = 10
        label.lineHeightScale = 2
        label.text = String(repeating: "あ", count: 10)

        let horizontal = STLabelView.fittingSize(of: label, proposal: ProposedViewSize(width: 50, height: nil))
        XCTAssertLessThanOrEqual(horizontal.width, 51)
        XCTAssertEqual(horizontal.height, 40, accuracy: 10)

        label.direction = .tbRl
        let vertical = STLabelView.fittingSize(of: label, proposal: ProposedViewSize(width: nil, height: 50))
        XCTAssertLessThanOrEqual(vertical.height, 51)
        XCTAssertEqual(vertical.width, 40, accuracy: 10)
    }

    //--------------------------------------------------------------//
    // MARK: - Editor
    //--------------------------------------------------------------//

    func testEditorShowsInitialText() throws {
        let (_, textView, _) = try makeEditor(text: "吾輩は猫である")

        XCTAssertEqual(textView.text, "吾輩は猫である")
        XCTAssertEqual(textView.fontSize, 16)
        XCTAssertEqual(textView.lineHeightScale, 1.5)
    }

    func testBindingChangeUpdatesTextView() throws {
        let (model, textView, root) = try makeEditor(text: "猫")

        model.text = "犬"
        settle(root)

        XCTAssertEqual(textView.text, "犬")
    }

    func testTextViewChangeUpdatesBinding() throws {
        let (model, textView, root) = try makeEditor(text: "猫")

        textView.text = "犬"
        settle(root)

        XCTAssertEqual(model.text, "犬")
        XCTAssertEqual(textView.text, "犬")
    }

    func testBindingDoesNotOverwriteTextBeingComposed() throws {
        let (model, textView, root) = try makeEditor(text: "猫")
        textView.markedRanges = [(0 ..< 1, true)]

        model.text = "犬"
        settle(root)

        XCTAssertEqual(textView.text, "猫")
    }

    func testSelectionStaysInShorterText() throws {
        let (model, textView, root) = try makeEditor(text: "吾輩は猫である")
        textView.selectedSTTextRange = STTextRange(range: 5 ..< 7)

        model.text = "猫"
        settle(root)

        XCTAssertLessThanOrEqual(textView.selectedSTTextRange.range.upperBound, 1)
    }

    func testVerticalEditorStartsAtRightEdge() throws {
        let text = String(repeating: "吾輩は猫である。名前はまだ無い。\n", count: 200)
        let (_, textView, _) = try makeEditor(text: text, direction: .tbRl)

        #if os(iOS)
        XCTAssertEqual(textView.contentOffset.x + textView.bounds.width, textView.label.frame.maxX, accuracy: 1)
        #else
        XCTAssertEqual(textView.documentVisibleRect.maxX, textView.textDocumentView.frame.maxX, accuracy: 1)
        #endif
    }

    func testEditorSizeIsWholeLines() throws {
        let lineHeight: CGFloat = 24
        let proposal = ProposedViewSize(width: 300, height: 310)

        XCTAssertEqual(STTextEditor.wholeLineSize(proposal: proposal, direction: .tbRl, lineHeight: lineHeight),
                       CGSize(width: 288, height: 310))
        XCTAssertEqual(STTextEditor.wholeLineSize(proposal: proposal, direction: .lrTb, lineHeight: lineHeight),
                       CGSize(width: 300, height: 288))
    }
}
