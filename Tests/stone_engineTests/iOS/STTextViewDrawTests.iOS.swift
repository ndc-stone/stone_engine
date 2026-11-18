/*
STTextViewDrawTests.iOS.swift

STTextView のスクロール位置合わせ、全置換、描画の省略のテスト。
*/

#if os(iOS)
import XCTest
@testable import stone_engine

@MainActor
final class STTextViewDrawTests: XCTestCase {

    private let fontSize: CGFloat = 17
    private let lineHeightScale: CGFloat = 1.625
    private var lineHeight: CGFloat { fontSize * lineHeightScale }

    /// 表示範囲が行送りの 12 倍になる、長い本文の STTextView を作る。
    private func makeTextView(direction: STDirection) -> STTextView {
        let textView = STTextView(frame: .zero)
        textView.label.context.fontManager.refresh()
        textView.direction = direction
        textView.fontSize = fontSize
        textView.lineHeightScale = lineHeightScale
        switch direction {
        case .lrTb: textView.frame = CGRect(x: 0, y: 0, width: 360, height: lineHeight * 12)
        case .tbRl: textView.frame = CGRect(x: 0, y: 0, width: lineHeight * 12, height: 360)
        }
        textView.text = String(repeating: "吾輩は猫である。名前はまだ無い。ABC 123\n", count: 300)
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        return textView
    }

    /// 表示範囲に一部だけ入っている行の番号を返す。
    private func partiallyVisibleLines(_ textView: STTextView, contentOffset: CGPoint) -> Set<Int> {
        let visible = CGRect(origin: contentOffset, size: textView.bounds.size)
        let origin = textView.label.frame.origin
        var lines = Set<Int>()
        for run in textView.label.context.runs where !run.isNewline {
            let frame = run.frame.offsetBy(dx: origin.x, dy: origin.y)
            let isPartial: Bool
            switch textView.direction {
            case .lrTb:
                isPartial = frame.maxY > visible.minY + 0.5 && frame.minY < visible.maxY - 0.5
                    && (frame.minY < visible.minY - 0.5 || frame.maxY > visible.maxY + 0.5)
            case .tbRl:
                isPartial = frame.maxX > visible.minX + 0.5 && frame.minX < visible.maxX - 0.5
                    && (frame.minX < visible.minX - 0.5 || frame.maxX > visible.maxX + 0.5)
            }
            if isPartial { lines.insert(run.line) }
        }
        return lines
    }

    //--------------------------------------------------------------//
    // MARK: - Scroll position
    //--------------------------------------------------------------//

    func testVerticalEdgeLinesAreFullyVisible() {
        let textView = makeTextView(direction: .tbRl)
        let maxX = textView.contentSize.width + textView.contentInset.right - textView.bounds.width

        for step in 0 ... 40 {
            let x = -textView.contentInset.left + (maxX + textView.contentInset.left) * CGFloat(step) / 40
            let adjusted = textView.adjustedContentOffset(targetContentOffset: CGPoint(x: x, y: 0))

            XCTAssertEqual(partiallyVisibleLines(textView, contentOffset: adjusted), [], "target x: \(x)")
        }
    }

    func testVerticalRightInsetSnapsBackToStart() {
        let textView = makeTextView(direction: .tbRl)
        let target = CGPoint(x: textView.contentSize.width + textView.contentInset.right - textView.bounds.width, y: 0)

        let adjusted = textView.adjustedContentOffset(targetContentOffset: target)

        XCTAssertEqual(adjusted.x, textView.label.frame.maxX - textView.bounds.width, accuracy: 0.001)
    }

    //--------------------------------------------------------------//
    // MARK: - Replace
    //--------------------------------------------------------------//

    func testReplaceAllIncludesRangeAtEndOfText() {
        let textView = STTextView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        textView.label.context.fontManager.refresh()
        textView.text = "猫と猫"

        textView.replaceAll([STTextRange(range: 0 ..< 1), STTextRange(range: 2 ..< 3)], withText: "犬")

        XCTAssertEqual(textView.text, "犬と犬")
    }

    //--------------------------------------------------------------//
    // MARK: - Layout cache
    //--------------------------------------------------------------//

    func testScrollDoesNotLayoutOrRedrawLabel() {
        for direction in [STDirection.lrTb, .tbRl] {
            let textView = makeTextView(direction: direction)
            let label: STLabel = textView.label
            label.layer.displayIfNeeded()
            let layoutVersion = label.context.layoutVersion

            for step in 1 ... 10 {
                let distance = CGFloat(step) * 50
                switch direction {
                case .lrTb: textView.contentOffset = CGPoint(x: 0, y: distance)
                case .tbRl: textView.contentOffset = CGPoint(x: textView.contentSize.width - textView.bounds.width - distance, y: 0)
                }
                textView.setNeedsLayout()
                textView.layoutIfNeeded()
            }

            XCTAssertEqual(label.context.layoutVersion, layoutVersion, "\(direction)")
            XCTAssertFalse(label.layer.needsDisplay(), "\(direction)")
        }
    }

    /// 描画サイズを字数で切り詰めるラベル。
    private final class LimitedLabel: STLabel {
        override func renderSize(forBounds size: CGSize) -> CGSize {
            return CGSize(width: min(357, size.width), height: size.height)
        }
    }

    func testRenderSizeForBoundsIsUsedForLayoutCache() {
        let label = LimitedLabel(frame: CGRect(x: 0, y: 0, width: 360, height: 800))
        label.context.fontManager.refresh()
        label.fontSize = fontSize
        label.text = String(repeating: "吾輩は猫である。", count: 100)
        label.layoutIfNeeded()
        let layoutVersion = label.context.layoutVersion

        for _ in 0 ..< 5 {
            _ = label.layoutThatFits(CGSize(width: 360, height: 0))
            label.setNeedsLayout()
            label.layoutIfNeeded()
        }

        XCTAssertEqual(label.context.layoutVersion, layoutVersion)
    }

    //--------------------------------------------------------------//
    // MARK: - Draw data
    //--------------------------------------------------------------//

    func testSelectionChangeRebuildsDrawBuckets() {
        let textView = makeTextView(direction: .tbRl)
        let label: STLabel = textView.label
        XCTAssertFalse(label.drawBuckets.contains { $0.isSelected })

        textView.selectedTextRange = STTextRange(range: 0 ..< 5)
        textView.layoutIfNeeded()

        XCTAssertEqual(label.drawBuckets.filter { $0.isSelected }.map { $0.glyphs.count }.reduce(0, +), 5)
    }

    func testAppearanceChangeRedraws() {
        let textView = makeTextView(direction: .tbRl)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 800, height: 800))
        window.addSubview(textView)
        window.overrideUserInterfaceStyle = .light
        window.layoutIfNeeded()
        textView.label.layer.displayIfNeeded()

        window.overrideUserInterfaceStyle = .dark
        window.layoutIfNeeded()

        XCTAssertTrue(textView.label.layer.needsDisplay())
    }

    //--------------------------------------------------------------//
    // MARK: - Culling
    //--------------------------------------------------------------//

    private func render(_ label: STLabel, rect: CGRect) throws -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: rect.size))
            context.cgContext.translateBy(x: -rect.minX, y: -rect.minY)
            context.cgContext.clip(to: rect)
            label.draw(rect)
        }
        return try XCTUnwrap(image.cgImage)
    }

    private func pixels(_ image: CGImage) throws -> [UInt8] {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try XCTUnwrap(CGContext(
            data: &data, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return data
    }

    func testDrawingRectMatchesCroppedLargerDrawing() throws {
        for direction in [STDirection.lrTb, .tbRl] {
            let label: STLabel = makeTextView(direction: direction).label
            let rect = CGRect(x: 101.5, y: 87.5, width: 128, height: 128)
            let large = rect.insetBy(dx: -64, dy: -64)

            let small = try render(label, rect: rect)
            let cropped = try XCTUnwrap(render(label, rect: large).cropping(
                to: CGRect(x: 128, y: 128, width: small.width, height: small.height)
            ))

            let smallPixels = try pixels(small)
            XCTAssertTrue(smallPixels.contains { $0 < 200 }, "\(direction): nothing drawn")
            XCTAssertEqual(smallPixels, try pixels(cropped), "\(direction)")
        }
    }
}
#endif
