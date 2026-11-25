/*
STTextViewKeyCommandTests.macOS.swift

文字や行より大きな単位で動くキー操作のテスト。行の端、段落、単語、ページ、
文書の端への移動と、スクロール、まとめての削除。

縦組みでは AppKit がキーを読み替えて送ってくる（⌘↑ が moveToLeftEndOfLine など）。
画面の向きどおりに動くことは、実際のキーイベントを送って確かめる。
*/

#if os(macOS)
import XCTest
@testable import stone_engine

@MainActor
final class STTextViewKeyCommandTests: XCTestCase {

    // 3 段落。どれも 1 行に収まる
    private let text = "あいうえお\nかきくけこさしすせそ\nたちつてと"

    private func makeTextView(text: String, direction: STDirection, size: CGSize = CGSize(width: 600, height: 600)) -> STTextView {
        let textView = STTextView(frame: CGRect(origin: .zero, size: size))
        textView.label.context.fontManager.refresh()
        textView.direction = direction
        textView.text = text
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

    private func click(_ textView: STTextView, at index: Int) {
        textView.selectedTextRange = STTextRange(range: index ..< index)
        layout(textView)
    }

    private enum Arrow {
        case up, down, left, right

        var keyCode: UInt16 {
            switch self {
            case .up: return 126
            case .down: return 125
            case .left: return 123
            case .right: return 124
            }
        }

        var function: Int {
            switch self {
            case .up: return NSUpArrowFunctionKey
            case .down: return NSDownArrowFunctionKey
            case .left: return NSLeftArrowFunctionKey
            case .right: return NSRightArrowFunctionKey
            }
        }
    }

    private func press(_ textView: STTextView, _ arrow: Arrow, _ modifiers: NSEvent.ModifierFlags) throws {
        let characters = String(Character(UnicodeScalar(arrow.function)!))
        let event = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers.union([.function, .numericPad]), timestamp: 0,
            windowNumber: textView.window?.windowNumber ?? 0, context: nil,
            characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: arrow.keyCode
        ))
        textView.keyDown(with: event)
        layout(textView)
    }

    private func pressControl(_ textView: STTextView, _ character: Character, keyCode: UInt16) throws {
        let control = String(UnicodeScalar(UInt8(character.asciiValue! - 96)))
        let event = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .control, timestamp: 0,
            windowNumber: textView.window?.windowNumber ?? 0, context: nil,
            characters: control, charactersIgnoringModifiers: String(character), isARepeat: false, keyCode: keyCode
        ))
        textView.keyDown(with: event)
        layout(textView)
    }

    private func caret(_ textView: STTextView) -> Int {
        return textView.selectedSTTextRange.range.lowerBound
    }

    //--------------------------------------------------------------//
    // MARK: - Arrow keys with modifiers
    //--------------------------------------------------------------//

    /// 横組みで ⌘・⌥ 付きの矢印が、文書・行・段落の端へ動くこと。
    func testModifiedArrowsInHorizontal() throws {
        let textView = makeTextView(text: text, direction: .lrTb)
        let start = 8 // 2 段落目の「け」の手前

        let cases: [(String, Arrow, NSEvent.ModifierFlags, Int)] = [
            ("⌘↑ 文書の先頭", .up, .command, 0),
            ("⌘↓ 文書の末尾", .down, .command, text.count),
            ("⌘← 行頭", .left, .command, 6),
            ("⌘→ 行末", .right, .command, 16),
            ("⌥↑ 段落の先頭", .up, .option, 6),
            ("⌥↓ 段落の末尾", .down, .option, 16),
        ]
        for (name, arrow, modifiers, expected) in cases {
            click(textView, at: start)
            try press(textView, arrow, modifiers)
            XCTAssertEqual(caret(textView), expected, "横組みの\(name)")
        }
    }

    /// 縦組みで ⌘・⌥ 付きの矢印が、画面の向きどおりに動くこと。
    /// 上下が行（列）の端、右が文書の先頭、左が文書の末尾。
    func testModifiedArrowsInVertical() throws {
        let textView = makeTextView(text: text, direction: .tbRl)
        let start = 8

        let cases: [(String, Arrow, NSEvent.ModifierFlags, Int)] = [
            ("⌘→ 文書の先頭", .right, .command, 0),
            ("⌘← 文書の末尾", .left, .command, text.count),
            ("⌘↑ 行頭（列の上端）", .up, .command, 6),
            ("⌘↓ 行末（列の下端）", .down, .command, 16),
            ("⌥→ 段落の先頭", .right, .option, 6),
            ("⌥← 段落の末尾", .left, .option, 16),
        ]
        for (name, arrow, modifiers, expected) in cases {
            click(textView, at: start)
            try press(textView, arrow, modifiers)
            XCTAssertEqual(caret(textView), expected, "縦組みの\(name)")
        }
    }

    /// ⌘⇧ 付きの矢印で、起点を残したまま端まで選択を広げること。
    func testModifiedArrowsExtendSelection() throws {
        for direction in [STDirection.lrTb, .tbRl] {
            let textView = makeTextView(text: text, direction: direction)
            click(textView, at: 8)

            // 文書の先頭まで
            try press(textView, direction == .lrTb ? .up : .right, [.command, .shift])
            XCTAssertEqual(textView.selectedSTTextRange.range, 0 ..< 8, "[\(direction)] 文書の先頭まで選択")

            // 動いている端（文書の先頭）の行の行末まで
            try press(textView, direction == .lrTb ? .right : .down, [.command, .shift])
            XCTAssertEqual(textView.selectedSTTextRange.range, 5 ..< 8, "[\(direction)] 動いている端の行の行末まで選択")

            // 起点をまたいで反対側へ
            try press(textView, direction == .lrTb ? .down : .left, [.command, .shift])
            XCTAssertEqual(textView.selectedSTTextRange.range, 8 ..< text.count, "[\(direction)] 起点をまたいで文書の末尾まで選択")
        }
    }

    /// ⌥↑ を続けて押すと、前の段落の先頭へ進むこと。
    func testRepeatedParagraphMoves() throws {
        let textView = makeTextView(text: text, direction: .lrTb)
        click(textView, at: 13)

        try press(textView, .up, .option)
        XCTAssertEqual(caret(textView), 6)
        try press(textView, .up, .option)
        XCTAssertEqual(caret(textView), 0)

        try press(textView, .down, .option)
        XCTAssertEqual(caret(textView), 5)
        try press(textView, .down, .option)
        XCTAssertEqual(caret(textView), 16)
    }

    /// Ctrl+A / Ctrl+E で段落の端へ動くこと。
    func testControlKeys() throws {
        let textView = makeTextView(text: text, direction: .tbRl)

        click(textView, at: 8)
        try pressControl(textView, "a", keyCode: 0)
        XCTAssertEqual(caret(textView), 6, "Ctrl+A")

        click(textView, at: 8)
        try pressControl(textView, "e", keyCode: 14)
        XCTAssertEqual(caret(textView), 16, "Ctrl+E")
    }

    //--------------------------------------------------------------//
    // MARK: - Line
    //--------------------------------------------------------------//

    /// 折り返した行の行頭・行末が、段落ではなく見えている行の端であること。
    func testLineEdgesOfWrappedLine() throws {
        let long = String(repeating: "あいうえおかきくけこ", count: 6)
        for direction in [STDirection.lrTb, .tbRl] {
            let size = direction == .lrTb ? CGSize(width: 200, height: 600) : CGSize(width: 600, height: 200)
            let textView = makeTextView(text: long, direction: direction, size: size)
            let context = textView.label.context
            XCTAssertGreaterThan(context.lineCount, 2, "[\(direction)] 前提が崩れた: 折り返していない")

            let line1 = try XCTUnwrap(context.runIndexes(line: 1))
            click(textView, at: line1.lowerBound + 2)
            textView.moveToBeginningOfLine(nil)
            layout(textView)
            XCTAssertEqual(caret(textView), line1.lowerBound, "[\(direction)] 行頭が見えている行の先頭でない")
        }
    }

    //--------------------------------------------------------------//
    // MARK: - Word
    //--------------------------------------------------------------//

    /// 単語の終わりと始まりへ動くこと。空白や句読点は飛ばす。
    func testWordMoves() {
        let textView = makeTextView(text: "The quick, brown fox", direction: .lrTb)

        click(textView, at: 0)
        textView.moveWordForward(nil)
        XCTAssertEqual(caret(textView), 3, "The の終わり")
        textView.moveWordForward(nil)
        XCTAssertEqual(caret(textView), 9, "quick の終わり（読点の手前）")
        textView.moveWordRight(nil)
        XCTAssertEqual(caret(textView), 16, "brown の終わり")

        textView.moveWordBackward(nil)
        XCTAssertEqual(caret(textView), 11, "brown の始まり")
        textView.moveWordLeft(nil)
        XCTAssertEqual(caret(textView), 4, "quick の始まり")
    }

    /// 単語の移動が段落をまたぐこと。
    func testWordMovesAcrossParagraphs() {
        let textView = makeTextView(text: "one\n\ntwo", direction: .lrTb)

        click(textView, at: 3)
        textView.moveWordForward(nil)
        XCTAssertEqual(caret(textView), 8, "次の段落の単語の終わり")

        textView.moveWordBackward(nil)
        textView.moveWordBackward(nil)
        XCTAssertEqual(caret(textView), 0, "前の段落の単語の始まり")
    }

    /// 日本語の文で、1 文字ずつでも一気に末尾でもなく、語の区切りで止まること。
    func testWordMovesInJapanese() {
        let sentence = "吾輩は猫である。名前はまだ無い。"
        let textView = makeTextView(text: sentence, direction: .tbRl)

        click(textView, at: 0)
        var stops = [Int]()
        while caret(textView) < sentence.count && stops.count < sentence.count {
            textView.moveWordForward(nil)
            stops.append(caret(textView))
        }

        XCTAssertEqual(stops.last, sentence.count, "末尾に着かない")
        XCTAssertGreaterThan(stops.count, 2, "語で区切られていない: \(stops)")
        XCTAssertLessThan(stops.count, sentence.count, "1 文字ずつ動いている: \(stops)")
    }

    //--------------------------------------------------------------//
    // MARK: - Page and scroll
    //--------------------------------------------------------------//

    private let longText = (0 ..< 80).map { "第\($0)行のテキスト" }.joined(separator: "\n")

    private func visibleStart(_ textView: STTextView) -> CGFloat {
        // 本文が始まる側の見えている端。横組みは上、縦組みは右
        let visible = textView.documentVisibleRect
        return textView.direction == .lrTb ? visible.minY : -visible.maxX
    }

    /// Page Down でキャレットが 1 ページ先の行へ動き、表示もついてくること。
    func testPageDownMovesCaretAndView() {
        for direction in [STDirection.lrTb, .tbRl] {
            let textView = makeTextView(text: longText, direction: direction, size: CGSize(width: 300, height: 300))
            textView.scrollToBeginningOfDocument(nil)
            click(textView, at: 2)
            let context = textView.label.context
            let startLine = context.line(at: caret(textView))
            let startView = visibleStart(textView)

            textView.pageDown(nil)
            layout(textView)

            let line = context.line(at: caret(textView))
            XCTAssertGreaterThan(line, startLine + 1, "[\(direction)] 1 ページ進まない")
            XCTAssertGreaterThan(visibleStart(textView), startView, "[\(direction)] 表示が進まない")

            textView.pageUp(nil)
            layout(textView)
            XCTAssertEqual(context.line(at: caret(textView)), startLine, "[\(direction)] Page Up で戻らない")
        }
    }

    /// スクロールの命令が、組み方向に合わせて本文の先頭・末尾の側へ動くこと。
    func testScrollCommands() {
        for direction in [STDirection.lrTb, .tbRl] {
            let textView = makeTextView(text: longText, direction: direction, size: CGSize(width: 300, height: 300))
            let caretBefore = textView.selectedSTTextRange.range

            textView.scrollToBeginningOfDocument(nil)
            let top = visibleStart(textView)

            textView.scrollPageDown(nil)
            XCTAssertGreaterThan(visibleStart(textView), top, "[\(direction)] scrollPageDown で末尾の側へ動かない")

            textView.scrollPageUp(nil)
            // 行の境目に寄せるので、行の高さより小さいずれは残りうる
            XCTAssertEqual(visibleStart(textView), top, accuracy: textView.label.context.lineHeight, "[\(direction)] scrollPageUp で戻らない")

            textView.scrollToEndOfDocument(nil)
            let documentRect = textView.contentView.documentRect
            let visible = textView.documentVisibleRect
            switch direction {
            // 余白（contentInsets）のぶん、文書の端より外まで見えてよい
            case .lrTb: XCTAssertGreaterThanOrEqual(visible.maxY, documentRect.maxY - 0.5, "末尾まで動かない")
            case .tbRl: XCTAssertLessThanOrEqual(visible.minX, documentRect.minX + 0.5, "末尾まで動かない")
            }

            XCTAssertEqual(textView.selectedSTTextRange.range, caretBefore, "[\(direction)] スクロールでキャレットが動いた")
        }
    }

    //--------------------------------------------------------------//
    // MARK: - Deletion
    //--------------------------------------------------------------//

    func testDeleteWord() {
        let textView = makeTextView(text: "The quick brown", direction: .lrTb)
        click(textView, at: 15)

        textView.deleteWordBackward(nil)
        XCTAssertEqual(textView.text, "The quick ")

        click(textView, at: 0)
        textView.deleteWordForward(nil)
        XCTAssertEqual(textView.text, " quick ")
    }

    func testDeleteToBeginningOfLine() {
        let textView = makeTextView(text: text, direction: .tbRl)
        click(textView, at: 9)

        textView.deleteToBeginningOfLine(nil)
        XCTAssertEqual(textView.text, "あいうえお\nけこさしすせそ\nたちつてと")
        XCTAssertEqual(caret(textView), 6)

        // 行頭では前の行とつなぐ
        textView.deleteToBeginningOfLine(nil)
        XCTAssertEqual(textView.text, "あいうえおけこさしすせそ\nたちつてと")
    }

    /// Ctrl+K で段落の終わりまで消し、段落の終わりでは改行を消すこと。
    func testDeleteToEndOfParagraph() throws {
        let textView = makeTextView(text: text, direction: .lrTb)
        click(textView, at: 8)

        try pressControl(textView, "k", keyCode: 40)
        XCTAssertEqual(textView.text, "あいうえお\nかき\nたちつてと")

        try pressControl(textView, "k", keyCode: 40)
        XCTAssertEqual(textView.text, "あいうえお\nかきたちつてと")
    }

    /// 選択があるときは、まとめて消す命令でも選択だけを消すこと。
    func testDeleteCommandsDeleteSelection() {
        let textView = makeTextView(text: text, direction: .lrTb)
        textView.selectedTextRange = STTextRange(range: 7 ..< 9)
        layout(textView)

        textView.deleteWordBackward(nil)
        XCTAssertEqual(textView.text, "あいうえお\nかけこさしすせそ\nたちつてと")
    }
}
#endif
