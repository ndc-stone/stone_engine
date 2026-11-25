/*
STTiledViewTests.iOS.swift

iOS の STLabel のタイル描画の検証。

STLabel はタイル（CATiledLayer）に描く。タイルは別のスレッドで後から描かれ、
描き終わるまでは前に描いたものが出ている。縦組みでは行が左に増え、文字は右端から
並べるので、行が増えるたびにラベルの中の座標で全部の文字が動く。タイルが
ラベルと同じ座標だと、描き直しが終わるまでの数フレーム、前のタイルが 1 行ずれて
見える（改行するとちらつく）。

そこでタイルは、ラベルに重ねた別のビュー（tiledContentView）が持ち、縦組みでは
右端を基準にした座標で描く。行が増えても、すでに描いた文字のタイル上の位置は
変わらない。ラベル自身の座標はそのままなので、ほかの座標の変換は変わらない。
*/

#if os(iOS)
import XCTest
@testable import stone_engine

@MainActor
final class STTiledViewTests: STLabelRenderTestCase {

    private let fontSize: CGFloat = 16

    /// ラベルの中の文字が、タイルのどこに描かれるか。
    private func frameInTiles(_ label: STLabel, run index: Int) -> CGRect {
        label.convert(label.context.runs[index].frame, to: label.tiledContentView)
    }

    /// 縦組みのテキストビュー。画面の幅を超える行数を持つ。
    private func makeTextView(direction: STDirection) -> STTextView {
        let textView = STTextView(frame: .zero)
        textView.label.context.fontManager.refresh()
        textView.direction = direction
        textView.fontSize = fontSize
        switch direction {
        case .lrTb: textView.frame = CGRect(x: 0, y: 0, width: 360, height: fontSize * 12)
        case .tbRl: textView.frame = CGRect(x: 0, y: 0, width: fontSize * 12, height: 360)
        }
        textView.text = (0 ..< 30).map { _ in "吾輩は猫である" }.joined(separator: "\n")
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        return textView
    }

    //--------------------------------------------------------------//
    // MARK: - Anchoring
    //--------------------------------------------------------------//

    /// 縦組みで行が増えても、すでにある文字のタイル上の位置が変わらないこと。
    func testTilesKeepCharactersWhenVerticalTextGrows() {
        for text in ["あいう", (0 ..< 30).map { _ in "吾輩は猫である" }.joined(separator: "\n")] {
            let label = makeLabel(text: text, size: CGSize(width: fontSize * 3, height: 200), direction: .tbRl, fontSize: fontSize)
            let before = frameInTiles(label, run: 0)
            let beforeInLabel = label.context.runs[0].frame

            // 行を足し、ラベルを本文の幅に合わせる（STTextView がするのと同じ）
            label.text = text + "\nかきく"
            let width = label.layoutThatFits(CGSize(width: 0, height: 200)).width
            label.frame.size.width = width
            label.setNeedsLayout()
            label.layoutIfNeeded()

            XCTAssertNotEqual(label.context.runs[0].frame.minX, beforeInLabel.minX, "前提: ラベルの中では文字が動く")
            XCTAssertEqual(frameInTiles(label, run: 0), before, "行が増えて、タイル上の文字の位置が変わった")
        }
    }

    /// 横組みは、タイルとラベルの座標が同じであること。
    func testTilesShareLabelCoordinatesInHorizontal() {
        let label = makeLabel(text: "あいう\nかきく", direction: .lrTb, fontSize: fontSize)

        XCTAssertEqual(label.tiledContentView.bounds, label.bounds)
        XCTAssertEqual(frameInTiles(label, run: 0), label.context.runs[0].frame)
    }

    /// 縦組みから横組みに戻したら、タイルの座標もラベルと同じに戻ること。
    func testSwitchingBackToHorizontal() {
        let label = makeLabel(text: "あいう\nかきく", direction: .tbRl, fontSize: fontSize)
        label.direction = .lrTb
        label.setNeedsLayout()
        label.layoutIfNeeded()

        XCTAssertEqual(label.tiledContentView.bounds, label.bounds)
    }

    /// 縦組みのテキストビューで改行しても、画面の上でもタイルの上でも、文字が動かないこと。
    func testNewlineInVerticalTextView() {
        let textView = makeTextView(direction: .tbRl)
        let label: STLabel = textView.label
        let end = textView.text?.count ?? 0
        textView.selectedTextRange = STTextRange(range: end ..< end)
        textView.setNeedsLayout()
        textView.layoutIfNeeded()

        // 見えている最後の行の最初の文字
        let index = label.context.runs.lastIndex { $0.line == label.context.lineCount - 2 && !$0.isNewline }!
        let onScreen = textView.convert(label.context.runs[index].frame, from: label).offsetBy(dx: -textView.contentOffset.x, dy: 0)
        let inTiles = frameInTiles(label, run: index)

        textView.insertText("\n")
        textView.setNeedsLayout()
        textView.layoutIfNeeded()

        let onScreenAfter = textView.convert(label.context.runs[index].frame, from: label).offsetBy(dx: -textView.contentOffset.x, dy: 0)
        XCTAssertEqual(frameInTiles(label, run: index), inTiles, "改行で、タイル上の文字の位置が変わった")
        XCTAssertEqual(onScreenAfter.minY, onScreen.minY, accuracy: 0.5)
        XCTAssertLessThanOrEqual(onScreenAfter.maxX, textView.bounds.width + 0.5, "改行で文字が画面の外へ出た")
    }

    /// 文字の、テキストビューの見えている範囲での位置。
    private func frameOnScreen(_ textView: STTextView, run index: Int) -> CGRect {
        let label: STLabel = textView.label
        return textView.convert(label.context.runs[index].frame, from: label).offsetBy(dx: -textView.contentOffset.x, dy: -textView.contentOffset.y)
    }

    private func typeNewline(_ textView: STTextView) {
        let end = textView.text?.count ?? 0
        textView.selectedTextRange = STTextRange(range: end ..< end)
        textView.insertText("\n")
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
    }

    /// 本文がテキストビューより狭いとき、改行しても文字が動かず、本文は右端に寄ったままであること。
    func testNewlineInVerticalTextNarrowerThanView() {
        let textView = STTextView(frame: CGRect(x: 0, y: 0, width: 400, height: 200))
        textView.label.context.fontManager.refresh()
        textView.direction = .tbRl
        textView.fontSize = fontSize
        textView.text = "あいう\nかきく"
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        let before = frameOnScreen(textView, run: 0)

        typeNewline(textView)

        XCTAssertEqual(frameOnScreen(textView, run: 0), before, "改行で文字が動いた")
        XCTAssertGreaterThan(before.maxX, textView.bounds.width - fontSize * 2, "本文が右端に寄っていない")
    }

    /// テキストビューを本文の幅に合わせて広げるとき（アプリがそうしている）、広げる前の
    /// 1 回目のレイアウトでも文字が動かないこと。動くと、広げるまでの間だけ 1 行ずれて見える。
    func testNewlineInVerticalTextViewSizedToText() {
        let textView = STTextView(frame: CGRect(x: 0, y: 0, width: 400, height: 200))
        textView.label.context.fontManager.refresh()
        textView.direction = .tbRl
        textView.fontSize = fontSize
        textView.text = "あいう\nかきく"
        func sizeToText() {
            textView.frame.size.width = textView.contentSize.width + textView.contentInset.left + textView.contentInset.right
            textView.setNeedsLayout()
            textView.layoutIfNeeded()
        }
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        sizeToText()
        sizeToText()
        let before = frameOnScreen(textView, run: 0)

        // 改行した直後。テキストビューはまだ広げていない
        typeNewline(textView)
        XCTAssertEqual(frameOnScreen(textView, run: 0).minX, before.minX, accuracy: 0.5, "広げる前に文字が動いた")

        // 広げたあとは、右端からの位置が同じ
        let fromRight = textView.bounds.width - before.maxX
        sizeToText()
        XCTAssertEqual(textView.bounds.width - frameOnScreen(textView, run: 0).maxX, fromRight, accuracy: 0.5, "広げたあと、右端からの位置が変わった")
    }

    //--------------------------------------------------------------//
    // MARK: - Drawing
    //--------------------------------------------------------------//

    /// タイルに描いたものが、ラベルに直接描いたものと同じ場所に出ること。
    func testTilesDrawWhatTheLabelDraws() throws {
        for direction in [STDirection.lrTb, .tbRl] {
            let label = makeLabel(text: "あいう\nかきく\nさしす", size: CGSize(width: 160, height: 160), direction: direction, fontSize: fontSize)
            let direct = try render(label)

            // タイルのビューを、ラベルと同じ範囲で描く
            let content = label.tiledContentView
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            format.opaque = false
            let image = UIGraphicsImageRenderer(bounds: label.bounds, format: format).image { context in
                let cgContext = context.cgContext
                cgContext.translateBy(x: 0, y: label.bounds.height)
                cgContext.scaleBy(x: 1, y: -1)
                // ラベルの座標の原点は、タイルの座標では bounds.origin にあたる
                cgContext.translateBy(x: -content.bounds.minX, y: -content.bounds.minY)
                content.draw(content.bounds)
            }
            let tiled = try XCTUnwrap(STTestBitmap.from(cgImage: try XCTUnwrap(image.cgImage), scale: 2))

            XCTAssertLessThan(tiled.differenceRatio(from: direct).ratio, 0.001, "\(direction)")
        }
    }

    //--------------------------------------------------------------//
    // MARK: - Overlay
    //--------------------------------------------------------------//

    /// 矩形がいくつかの矩形で覆われているかの判定。
    func testRectsCover() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertTrue(STTiledContentView.rects([CGRect(x: -10, y: -10, width: 200, height: 200)], cover: rect))
        XCTAssertTrue(STTiledContentView.rects([CGRect(x: 0, y: 0, width: 50, height: 100), CGRect(x: 50, y: 0, width: 50, height: 100)], cover: rect))
        XCTAssertFalse(STTiledContentView.rects([CGRect(x: 0, y: 0, width: 50, height: 100)], cover: rect))
        XCTAssertFalse(STTiledContentView.rects([], cover: rect))
    }

    /// 描き直しを頼むと、見えている範囲にすぐ上かけが出て、タイルが描き終わると外れること。
    func testOverlayCoversVisiblePartUntilTilesAreDrawn() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        let scrollView = UIScrollView(frame: window.bounds)
        window.addSubview(scrollView)
        window.isHidden = false
        defer { window.isHidden = true }

        let label = makeLabel(text: (0 ..< 40).map { _ in "吾輩は猫である" }.joined(separator: "\n"), size: CGSize(width: 300, height: 1000), direction: .lrTb, fontSize: fontSize)
        scrollView.addSubview(label)
        scrollView.contentSize = label.bounds.size
        scrollView.contentOffset = CGPoint(x: 0, y: 200)
        label.layoutIfNeeded()

        label.setNeedsDisplay()
        label.layoutIfNeeded()

        XCTAssertFalse(label.overlayView.isHidden, "上かけが出ていない")
        XCTAssertEqual(label.overlayView.frame, CGRect(x: 0, y: 200, width: 300, height: 300), "上かけが見えている範囲を覆っていない")

        // タイルが描き終わるのを待つ
        let deadline = Date().addingTimeInterval(5)
        while !label.overlayView.isHidden && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(label.overlayView.isHidden, "タイルが描き終わっても上かけが外れない")
    }

    /// 上かけに描くものが、ラベルに直接描いたものと同じであること。
    func testOverlayDrawsWhatTheLabelDraws() throws {
        let label = makeLabel(text: "あいう\nかきく\nさしす", size: CGSize(width: 160, height: 160), direction: .tbRl, fontSize: fontSize)
        let direct = try render(label)

        let overlay = label.overlayView
        overlay.frame = label.bounds
        overlay.bounds = label.bounds
        overlay.fillColor = .clear
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let image = UIGraphicsImageRenderer(bounds: label.bounds, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: label.bounds.height)
            cgContext.scaleBy(x: 1, y: -1)
            overlay.draw(overlay.bounds)
        }
        let drawn = try XCTUnwrap(STTestBitmap.from(cgImage: try XCTUnwrap(image.cgImage), scale: 2))

        XCTAssertLessThan(drawn.differenceRatio(from: direct).ratio, 0.001)
    }

    /// ラベル自身のレイヤーには描かないこと。描くと、長い文書を 1 枚の画像で持ってしまう。
    func testLabelLayerHoldsNoImage() {
        let label = makeLabel(text: "あいう", direction: .tbRl, fontSize: fontSize)
        label.layer.displayIfNeeded()

        XCTAssertNil(label.layer.contents)
        XCTAssertTrue(label.tiledContentView.layer is STTiledLayer)
    }
}
#endif
