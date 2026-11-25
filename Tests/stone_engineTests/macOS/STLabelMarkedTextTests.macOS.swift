/*
STLabelMarkedTextTests.macOS.swift

変換中の文字に引く線の位置のテスト。

線は文字の外に引く。横組みでは文字の下、縦組みでは文字の左。
原稿用紙の枡目は文字の枠に重ねて描かれるので、線が枠の内側に入ると
枡目と重なり、横組みと縦組みで見え方も変わってしまう。
*/

#if os(macOS)
import XCTest
@testable import stone_engine

@MainActor
final class STLabelMarkedTextTests: XCTestCase {

    private func makeTextView(direction: STDirection) -> STTextView {
        let textView = STTextView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        textView.label.context.fontManager.refresh()
        textView.direction = direction
        textView.isFixedWidth = true
        // 行間を空ける。線は文字の外、行と行の間に引かれるので、間がないと描く場所がない
        textView.lineHeightScale = 1.5
        textView.text = "あいうえお"
        let window = NSWindow(contentRect: textView.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = textView
        window.makeFirstResponder(textView)
        layout(textView)
        return textView
    }

    private func layout(_ textView: STTextView) {
        textView.needsLayout = true
        textView.layoutSubtreeIfNeeded()
    }

    private func render(_ label: STLabel) throws -> NSBitmapImageRep {
        let rep = try XCTUnwrap(label.bitmapImageRepForCachingDisplay(in: label.bounds), "ビットマップを用意できない")
        label.cacheDisplay(in: label.bounds, to: rep)
        return rep
    }

    /// 2 枚の画像で色の違う画素を囲む矩形。ラベルの座標（左上原点）で返す。
    private func differenceBounds(_ a: NSBitmapImageRep, _ b: NSBitmapImageRep, in label: STLabel) -> CGRect? {
        let scale = CGFloat(a.pixelsWide) / label.bounds.width
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for y in 0 ..< a.pixelsHigh {
            for x in 0 ..< a.pixelsWide {
                guard let ca = a.colorAt(x: x, y: y), let cb = b.colorAt(x: x, y: y) else { continue }
                guard abs(ca.alphaComponent - cb.alphaComponent) > 0.2 else { continue }
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

    /// 変換中の線だけを取り出す。変換中と、確定したあと（文字は同じで線がない）を描き比べる。
    private func markedLineBounds(_ textView: STTextView) throws -> CGRect? {
        textView.setMarkedText("あいう", selectedRange: NSRange(location: 3, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        layout(textView)
        let marked = try render(textView.label)

        textView.unmarkText()
        layout(textView)
        let unmarked = try render(textView.label)

        return differenceBounds(marked, unmarked, in: textView.label)
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

        // 枡目は行の先頭の枠に合わせて描かれる。文字の枠がそれと揃っていること
        XCTAssertEqual(chars.minX, context.firstRunFrame(line: context.runs[5].line).minX, accuracy: 0.5, "文字の枠が枡目とずれている")

        XCTAssertLessThanOrEqual(line.maxX, chars.minX + 0.5, "線が文字の枠の内側に入った（線 \(line)、文字 \(chars)）")
    }

    private func click(_ textView: STTextView, at index: Int) {
        textView.selectedTextRange = STTextRange(range: index ..< index)
        layout(textView)
    }
}
#endif
