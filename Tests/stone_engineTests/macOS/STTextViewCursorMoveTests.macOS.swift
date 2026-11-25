/*
STTextViewCursorMoveTests.macOS.swift

矢印キーで行をまたいでカーソルを動かすときのテスト。

行を続けて移るあいだは、最初の位置（目標位置）に一番近いところへ移る。
途中に短い行があっても、次の長い行では元の位置に戻る。
目標位置は行の移動のあいだだけ覚えておき、クリックや入力、行に沿った移動で
カーソルが動いたら忘れる。縦組みでは左右の矢印が行の移動になる。
そのための矢印キーの読み替えは AppKit が行い、エンジンは受け取った命令を論理的な向きとして扱う。
*/

#if os(macOS)
import XCTest
@testable import stone_engine

@MainActor
final class STTextViewCursorMoveTests: XCTestCase {

    // 1 行目と 3 行目は 10 文字、間の 2 行目は 3 文字。改行で区切るので折り返しに左右されない
    private let text = "あいうえおかきくけこ\nさしす\nたちつてとなにぬねの"

    private func makeTextView(direction: STDirection) -> STTextView {
        let textView = STTextView(frame: CGRect(x: 0, y: 0, width: 600, height: 600))
        textView.label.context.fontManager.refresh()
        textView.direction = direction
        textView.text = text
        layout(textView)
        return textView
    }

    private func layout(_ textView: STTextView) {
        textView.needsLayout = true
        textView.layoutSubtreeIfNeeded()
    }

    /// line 行目の col 文字目の手前のキャレット位置。
    private func index(_ textView: STTextView, line: Int, col: Int) -> Int {
        return textView.label.context.runIndexes(line: line)!.lowerBound + col
    }

    private func click(_ textView: STTextView, at index: Int) {
        textView.selectedTextRange = STTextRange(range: index ..< index)
        layout(textView)
    }

    // 移動の命令は論理的な向き。moveDown は次の行、moveLeft は 1 文字戻る。
    // 縦組みで矢印キーをこの向きへ読み替えるのは AppKit の仕事（testArrowKeysInVertical 参照）
    private func nextLine(_ textView: STTextView, select: Bool = false) {
        if select { textView.moveDownAndModifySelection(nil) } else { textView.moveDown(nil) }
        layout(textView)
    }

    private func prevLine(_ textView: STTextView, select: Bool = false) {
        if select { textView.moveUpAndModifySelection(nil) } else { textView.moveUp(nil) }
        layout(textView)
    }

    private func backwardSelecting(_ textView: STTextView) {
        textView.moveLeftAndModifySelection(nil)
        layout(textView)
    }

    private let directions: [STDirection] = [.lrTb, .tbRl]

    //--------------------------------------------------------------//
    // MARK: - Goal
    //--------------------------------------------------------------//

    /// 短い行を通っても、次の長い行では元の位置に戻ること。
    func testGoalSurvivesShortLine() {
        for direction in directions {
            let textView = makeTextView(direction: direction)
            click(textView, at: index(textView, line: 0, col: 7))

            nextLine(textView)
            XCTAssertEqual(textView.selectedSTTextRange.range, 14 ..< 14, "[\(direction)] 短い行では行末（改行の手前）に来る")

            nextLine(textView)
            XCTAssertEqual(textView.selectedSTTextRange.range.lowerBound, index(textView, line: 2, col: 7), "[\(direction)] 長い行で元の位置に戻らない")

            prevLine(textView)
            prevLine(textView)
            XCTAssertEqual(textView.selectedSTTextRange.range.lowerBound, index(textView, line: 0, col: 7), "[\(direction)] 戻ったときに元の位置に戻らない")
        }
    }

    /// クリックしたら、前の行移動の目標位置を忘れること。
    func testGoalIsForgottenAfterClick() {
        for direction in directions {
            let textView = makeTextView(direction: direction)
            click(textView, at: index(textView, line: 0, col: 7))
            nextLine(textView)

            click(textView, at: index(textView, line: 0, col: 2))
            nextLine(textView)
            nextLine(textView)

            XCTAssertEqual(textView.selectedSTTextRange.range.lowerBound, index(textView, line: 2, col: 2), "[\(direction)] クリックする前の目標位置に飛んだ")
        }
    }

    /// 文書の末尾まで行で移ったあとでも、別の場所からの行移動がその場所から始まること。
    func testGoalIsForgottenAfterReachingTheEnd() {
        for direction in directions {
            let textView = makeTextView(direction: direction)
            click(textView, at: index(textView, line: 2, col: 3))
            nextLine(textView)
            XCTAssertEqual(textView.selectedSTTextRange.range.lowerBound, text.count, "[\(direction)] 最後の行からは末尾に来る")

            click(textView, at: index(textView, line: 0, col: 5))
            nextLine(textView)
            nextLine(textView)

            XCTAssertEqual(textView.selectedSTTextRange.range.lowerBound, index(textView, line: 2, col: 5), "[\(direction)] 末尾の位置を目標にしたまま")
        }
    }

    /// 入力したら、前の行移動の目標位置を忘れること。
    func testGoalIsForgottenAfterTyping() {
        for direction in directions {
            let textView = makeTextView(direction: direction)
            click(textView, at: index(textView, line: 0, col: 7))
            nextLine(textView)
            nextLine(textView)

            click(textView, at: index(textView, line: 0, col: 1))
            textView.insertText("X", replacementRange: NSRange(location: NSNotFound, length: 0))
            layout(textView)
            nextLine(textView)
            nextLine(textView)

            XCTAssertEqual(textView.selectedSTTextRange.range.lowerBound, index(textView, line: 2, col: 2), "[\(direction)] 入力する前の目標位置に飛んだ")
        }
    }

    //--------------------------------------------------------------//
    // MARK: - Selection
    //--------------------------------------------------------------//

    /// 選択の前の端を動かしているときは、前の端の位置を目標にすること。
    func testGoalComesFromTheMovingEnd() {
        for direction in directions {
            let textView = makeTextView(direction: direction)
            let anchor = index(textView, line: 2, col: 5)
            click(textView, at: anchor)

            backwardSelecting(textView)
            prevLine(textView, select: true)
            prevLine(textView, select: true)

            XCTAssertEqual(
                textView.selectedSTTextRange.range, index(textView, line: 0, col: 4) ..< anchor,
                "[\(direction)] 動いていない後ろの端を目標にした"
            )
        }
    }

    /// 選択の動く端が起点をまたいでも、起点が保たれること。
    func testMovingEndCrossesTheAnchor() {
        for direction in directions {
            let textView = makeTextView(direction: direction)
            let anchor = index(textView, line: 2, col: 4)
            click(textView, at: anchor)

            prevLine(textView, select: true)
            prevLine(textView, select: true)
            XCTAssertEqual(textView.selectedSTTextRange.range, index(textView, line: 0, col: 4) ..< anchor, "[\(direction)]")

            nextLine(textView, select: true)
            nextLine(textView, select: true)
            XCTAssertEqual(textView.selectedSTTextRange.range, anchor ..< anchor, "[\(direction)] 起点に戻らない")

            nextLine(textView, select: true)
            XCTAssertEqual(textView.selectedSTTextRange.range, anchor ..< text.count, "[\(direction)] 起点をまたいだあとの選択が崩れた")
        }
    }

    //--------------------------------------------------------------//
    // MARK: - End of line
    //--------------------------------------------------------------//

    /// 改行で終わる行の行末は、改行の手前であること。
    func testEndOfLineStopsBeforeNewline() {
        for direction in directions {
            let textView = makeTextView(direction: direction)

            click(textView, at: index(textView, line: 0, col: 3))
            textView.moveToEndOfLine(nil)
            XCTAssertEqual(textView.selectedSTTextRange.range, 10 ..< 10, "[\(direction)] 次の行の先頭に行った")

            click(textView, at: index(textView, line: 1, col: 1))
            textView.moveToEndOfLine(nil)
            XCTAssertEqual(textView.selectedSTTextRange.range, 14 ..< 14, "[\(direction)] 次の行の先頭に行った")

            // 最後の行は改行で終わらないので、本文の末尾
            click(textView, at: index(textView, line: 2, col: 3))
            textView.moveToEndOfLine(nil)
            XCTAssertEqual(textView.selectedSTTextRange.range, text.count ..< text.count, "[\(direction)]")
        }
    }

    //--------------------------------------------------------------//
    // MARK: - Arrow keys
    //--------------------------------------------------------------//

    private func pressArrow(_ textView: STTextView, keyCode: UInt16, function: Int) throws {
        let characters = String(Character(UnicodeScalar(function)!))
        let event = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [.function, .numericPad], timestamp: 0,
            windowNumber: textView.window?.windowNumber ?? 0, context: nil,
            characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode
        ))
        textView.keyDown(with: event)
        layout(textView)
    }

    /// 縦組みで矢印キーが画面の向きどおりに動くこと。
    /// 上下は 1 文字戻る・進む、左は次の行（左の列）、右は前の行（右の列）。
    func testArrowKeysInVertical() throws {
        let textView = makeTextView(direction: .tbRl)
        let window = NSWindow(contentRect: textView.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = textView
        window.makeFirstResponder(textView)
        layout(textView)

        let start = index(textView, line: 1, col: 2)
        let cases: [(String, UInt16, Int, Int)] = [
            ("上", 126, NSUpArrowFunctionKey, start - 1),
            ("下", 125, NSDownArrowFunctionKey, start + 1),
            ("左", 123, NSLeftArrowFunctionKey, index(textView, line: 2, col: 2)),
            ("右", 124, NSRightArrowFunctionKey, index(textView, line: 0, col: 2)),
        ]
        for (name, keyCode, function, expected) in cases {
            click(textView, at: start)
            try pressArrow(textView, keyCode: keyCode, function: function)
            XCTAssertEqual(textView.selectedSTTextRange.range.lowerBound, expected, "縦組みで\(name)矢印の移動先が違う")
        }
    }

    /// 横組みで矢印キーが画面の向きどおりに動くこと。
    func testArrowKeysInHorizontal() throws {
        let textView = makeTextView(direction: .lrTb)
        let window = NSWindow(contentRect: textView.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = textView
        window.makeFirstResponder(textView)
        layout(textView)

        let start = index(textView, line: 1, col: 2)
        let cases: [(String, UInt16, Int, Int)] = [
            ("左", 123, NSLeftArrowFunctionKey, start - 1),
            ("右", 124, NSRightArrowFunctionKey, start + 1),
            ("上", 126, NSUpArrowFunctionKey, index(textView, line: 0, col: 2)),
            ("下", 125, NSDownArrowFunctionKey, index(textView, line: 2, col: 2)),
        ]
        for (name, keyCode, function, expected) in cases {
            click(textView, at: start)
            try pressArrow(textView, keyCode: keyCode, function: function)
            XCTAssertEqual(textView.selectedSTTextRange.range.lowerBound, expected, "横組みで\(name)矢印の移動先が違う")
        }
    }
}
#endif
