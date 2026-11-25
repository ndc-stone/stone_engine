/*
STLabelMarkedTextTests.iOS.swift

変換中の文字に引く線の位置のテスト。macOS 版（STLabelMarkedTextTests.macOS.swift）と同じ。

線は文字の外に引く。横組みでは文字の下、縦組みでは文字の左。
原稿用紙の枡目は文字の枠に重ねて描かれるので、線が枠の内側に入ると
枡目と重なり、横組みと縦組みで見え方も変わってしまう。
*/

#if os(iOS)
import XCTest
@testable import stone_engine

@MainActor
final class STLabelMarkedTextTests: XCTestCase {

    private let scale: CGFloat = 2

    private func makeTextView(direction: STDirection) -> STTextView {
        let textView = STTextView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        textView.label.context.fontManager.refresh()
        textView.direction = direction
        textView.isFixedWidth = true
        // 行間を空ける。線は文字の外、行と行の間に引かれるので、間がないと描く場所がない
        textView.lineHeightScale = 1.5
        textView.text = "あいうえお"
        layout(textView)
        return textView
    }

    private func layout(_ textView: STTextView) {
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
    }

    private func render(_ label: STLabel) throws -> [UInt8] {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let bounds = label.bounds
        let image = UIGraphicsImageRenderer(size: bounds.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: bounds.size))
            label.draw(bounds)
        }
        let cgImage = try XCTUnwrap(image.cgImage)

        var data = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
        let context = try XCTUnwrap(CGContext(
            data: &data, width: cgImage.width, height: cgImage.height, bitsPerComponent: 8, bytesPerRow: cgImage.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        return data
    }

    /// 変換中の線だけを取り出す。変換中と、確定したあと（文字は同じで線がない）を描き比べ、
    /// 色の違う画素を囲む矩形をラベルの座標（左上原点）で返す。
    private func markedLineBounds(_ textView: STTextView) throws -> CGRect? {
        textView.setAttributedMarkedText(NSAttributedString(string: "あいう"), selectedRange: NSRange(location: 3, length: 0))
        layout(textView)
        let marked = try render(textView.label)

        textView.unmarkText()
        layout(textView)
        let unmarked = try render(textView.label)

        let width = Int(textView.label.bounds.width * scale)
        let height = Int(textView.label.bounds.height * scale)
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for y in 0 ..< height {
            for x in 0 ..< width {
                let i = (y * width + x) * 4
                guard abs(Int(marked[i]) - Int(unmarked[i])) > 50 else { continue }
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return nil }
        return CGRect(
            x: CGFloat(minX) / scale, y: CGFloat(minY) / scale,
            width: CGFloat(maxX - minX + 1) / scale, height: CGFloat(maxY - minY + 1) / scale
        )
    }

    private func click(_ textView: STTextView, at index: Int) {
        textView.selectedTextRange = STTextRange(range: index ..< index)
        layout(textView)
    }

    /// 横組みでは、線が文字の枠の下、枠の外にあること。
    func testMarkedLineIsBelowCharactersInHorizontal() throws {
        let textView = makeTextView(direction: .lrTb)
        click(textView, at: 5)
        let line = try XCTUnwrap(try markedLineBounds(textView), "変換中の線が描かれていない")
        let frames = (5 ..< 8).map { textView.label.context.runs[$0].frame }
        let chars = frames.dropFirst().reduce(frames[0]) { $0.union($1) }

        XCTAssertGreaterThanOrEqual(line.minY, chars.maxY - 0.5, "線が文字の枠の内側に入った（線 \(line)、文字 \(chars)）")
    }

    /// 縦組みでは、線が文字の枠の左、枠の外にあること。
    func testMarkedLineIsLeftOfCharactersInVertical() throws {
        let textView = makeTextView(direction: .tbRl)
        click(textView, at: 5)
        let line = try XCTUnwrap(try markedLineBounds(textView), "変換中の線が描かれていない")
        let context = textView.label.context
        let frames = (5 ..< 8).map { context.runs[$0].frame }
        let chars = frames.dropFirst().reduce(frames[0]) { $0.union($1) }

        XCTAssertLessThanOrEqual(line.maxX, chars.minX + 0.5, "線が文字の枠の内側に入った（線 \(line)、文字 \(chars)）")
    }
}
#endif
