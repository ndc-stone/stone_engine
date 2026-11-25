/*
STTextViewVerticalGrowthTests.macOS.swift

縦組みで行が増えるときの表示の検証。

横組みでは、本文は上に留まり、改行するとカーソルが下へ進む。縦組みも同じく、
本文は右に留まり、改行するとカーソルが左へ進まなければならない。
以前は、本文が画面の幅に満たないと文書が左に寄り、改行するたびに
それまでの行が右へ押し出されて、カーソルは左端に留まっていた。
*/

#if os(macOS)
import XCTest
@testable import stone_engine

@MainActor
final class STTextViewVerticalGrowthTests: XCTestCase {

    private let fontSize: CGFloat = 16

    private func makeTextView(text: String, visibleLines: Int = 6) -> STTextView {
        let textView = STTextView(frame: CGRect(x: 0, y: 0, width: fontSize * CGFloat(visibleLines), height: fontSize * 10))
        textView.fontSize = fontSize
        textView.direction = .tbRl
        textView.text = text
        let window = NSWindow(contentRect: textView.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = textView
        window.makeFirstResponder(textView)
        textView.layoutSubtreeIfNeeded()
        textView.selectedSTTextRange = STTextRange(range: text.count ..< text.count)
        textView.layoutSubtreeIfNeeded()
        return textView
    }

    private func type(_ textView: STTextView, _ string: String) {
        textView.insertText(string, replacementRange: NSRange(location: NSNotFound, length: 0))
        textView.layoutSubtreeIfNeeded()
    }

    /// カーソルの位置。テキストビューの座標で返す。
    private func cursorInView(_ textView: STTextView) -> CGRect {
        textView.convert(textView.cursorView.frame, from: textView.textDocumentView)
    }

    /// 最初の文字の位置。テキストビューの座標で返す。
    private func firstCharacterInView(_ textView: STTextView) -> CGRect {
        textView.convert(textView.label.context.runs[0].frame, from: textView.label)
    }

    /// 短い本文は右端から始まること。
    func testShortTextStartsAtRightEdge() {
        let textView = makeTextView(text: "あいう\nかきく")
        let first = firstCharacterInView(textView)

        XCTAssertGreaterThan(first.midX, textView.bounds.width - fontSize, "本文が右端から始まっていない（最初の文字 \(first)）")
    }

    /// 改行すると、本文は動かず、カーソルが左の行へ進むこと。
    func testNewlineMovesCursorLeftAndKeepsText() {
        let textView = makeTextView(text: "あいう\nかきく\nさしす")

        for _ in 0 ..< 2 {
            let firstBefore = firstCharacterInView(textView)
            let cursorBefore = cursorInView(textView)

            type(textView, "\n")

            XCTAssertEqual(firstCharacterInView(textView).minX, firstBefore.minX, accuracy: 0.5, "改行で本文が動いた")
            XCTAssertEqual(cursorInView(textView).minX, cursorBefore.minX - fontSize, accuracy: 0.5, "改行でカーソルが左の行へ進まない")

            // 空行のカーソルと、そこに文字を入れたあとのカーソルは同じ行にあること
            let cursorOnEmptyLine = cursorInView(textView)
            type(textView, "た")
            XCTAssertEqual(cursorInView(textView).minX, cursorOnEmptyLine.minX, accuracy: 0.5, "空行のカーソルが行からずれている")
        }
    }

    /// 画面に収まらなくなったら、横組みで下へ送るのと同じく、新しい行が見えるところまで送ること。
    func testNewlineKeepsCursorVisibleWhenTextOverflows() {
        let textView = makeTextView(text: "あいう\nかきく\nさしす")

        for _ in 0 ..< 10 {
            type(textView, "\n")
            let cursor = cursorInView(textView)
            XCTAssertGreaterThanOrEqual(cursor.minX, -0.5, "カーソルが画面の左へはみ出した")
            XCTAssertLessThanOrEqual(cursor.maxX, textView.bounds.width + 0.5, "カーソルが画面の右へはみ出した")
        }
    }

    /// 途中までスクロールしているとき、後ろで行が増えても見えている本文は動かないこと。
    func testGrowingDoesNotShiftScrolledText() {
        let text = (0 ..< 20).map { _ in "あいうえお" }.joined(separator: "\n")
        let textView = makeTextView(text: text)

        // 先頭近くを表示する
        textView.selectedSTTextRange = STTextRange(range: 0 ..< 0)
        textView.scrollCursorToVisible()
        textView.layoutSubtreeIfNeeded()
        let firstBefore = firstCharacterInView(textView)

        // 画面の外、末尾に行を足す
        textView.label.text = text + "\nかきくけこ"
        textView.label.needsLayout = true
        textView.needsLayout = true
        textView.layoutSubtreeIfNeeded()

        XCTAssertEqual(firstCharacterInView(textView).minX, firstBefore.minX, accuracy: 0.5, "末尾に行が増えて、見えている本文が動いた")
    }
}
#endif
