/*
STTextViewWholeLineScrollTests.swift

スクロールが止まったとき、上端と下端の文字が途中で切れていないことの検証。

stone はこれを 2 段構えで実現している。
  1. アプリ側のレイアウト処理が、テキストビューの高さ（縦組みでは幅）を
     行の高さの整数倍にする
  2. STTextView.scrollToWholeLines() が、スクロールの終わりに先頭側の端を
     行の境目へ寄せる

2 は先頭側の端しか動かさないので、下端が切れないことは 1 が支えている。
つまり 1 が効かない状況では 2 だけでは救えない。ここではその関係と、
現状で救えない組み合わせを、実測できる形で固定する。

「半分隠れている」の定義: あるランの見えている量が、ほぼ全部でもほぼ皆無でもないこと。
端にわずかに掛かっているだけのランは、利用者から見れば見えていないので数えない。
*/

#if os(macOS)
import XCTest
@testable import stone_engine

@MainActor
final class STTextViewWholeLineScrollTests: XCTestCase {

    /// 端に掛かっているとみなさない量（pt）。scrollToWholeLines の許容と揃えてある。
    private let tolerance: CGFloat = 0.5

    //--------------------------------------------------------------//
    // MARK: - Helpers
    //--------------------------------------------------------------//

    /// 行の高さの整数倍の高さを持つテキストビュー。
    ///
    /// contentInsets は 0 にする。STTextView の既定は上下 1pt ずつ入っていて、
    /// そのままだと見える高さが行の高さの整数倍にならない。
    private func makeTextView(
        text: String,
        visibleLines: Int,
        fontSize: CGFloat = 16,
        lineHeightScale: CGFloat = 1,
        direction: STDirection = .lrTb,
        overrideLength: CGFloat? = nil
    ) -> STTextView {
        let lineHeight = fontSize * lineHeightScale
        let length = overrideLength ?? lineHeight * CGFloat(visibleLines)
        let size = direction == .lrTb
            ? CGSize(width: 16 * 20, height: length)
            : CGSize(width: length, height: 16 * 20)

        let textView = STTextView(frame: CGRect(origin: .zero, size: size))
        textView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.fontSize = fontSize
        textView.lineHeightScale = lineHeightScale
        textView.direction = direction
        textView.text = text
        textView.layoutSubtreeIfNeeded()

        return textView
    }

    /// 途中で切れて見えているランの一覧。
    private func clippedRuns(_ textView: STTextView) -> [(runId: Int, char: Character, shown: CGFloat, size: CGFloat)] {
        let visible = textView.documentVisibleRect
        var out = [(Int, Character, CGFloat, CGFloat)]()

        for (runId, run) in textView.label.context.runs.enumerated() {
            // グリフを持たないランは対象外
            guard !run.isNewline, !run.isHidden else { continue }

            let rect = textView.textDocumentView.convert(run.frame, from: textView.label)
            let shown: CGFloat
            let size: CGFloat
            switch textView.direction {
            case .lrTb:
                shown = min(rect.maxY, visible.maxY) - max(rect.minY, visible.minY)
                size = rect.height
            case .tbRl:
                shown = min(rect.maxX, visible.maxX) - max(rect.minX, visible.minX)
                size = rect.width
            }

            if shown > tolerance && shown < size - tolerance {
                out.append((runId, textView.label.context.runChars[runId], shown, size))
            }
        }

        return out
    }

    /// 先頭から数行ぶんの範囲を 1pt ずつスクロールして止め、切れたランを数える。
    private func sweep(_ textView: STTextView, lineHeight: CGFloat) -> [(offset: CGFloat, clipped: Int)] {
        let visible = textView.documentVisibleRect
        let documentRect = textView.contentView.documentRect
        var results = [(CGFloat, Int)]()

        let limit: CGFloat
        switch textView.direction {
        case .lrTb: limit = min(max(0, documentRect.maxY - visible.height), lineHeight * 3)
        case .tbRl: limit = min(max(0, documentRect.maxX - visible.width), lineHeight * 3)
        }

        var offset: CGFloat = 0
        while offset <= limit {
            switch textView.direction {
            case .lrTb: textView.contentView.setBoundsOrigin(CGPoint(x: 0, y: offset))
            case .tbRl: textView.contentView.setBoundsOrigin(CGPoint(x: offset, y: 0))
            }
            textView.reflectScrolledClipView(textView.contentView)

            // スクロールが止まったときの処理
            textView.scrollToWholeLines(animated: false)

            let clipped = clippedRuns(textView)
            if !clipped.isEmpty { results.append((offset, clipped.count)) }
            offset += 1
        }

        return results
    }

    private func describe(_ results: [(offset: CGFloat, clipped: Int)]) -> String {
        return results.prefix(4).map { String(format: "%.0f→%d字", $0.offset, $0.clipped) }.joined(separator: ", ")
    }

    //--------------------------------------------------------------//
    // MARK: - うまくいく組み合わせ
    //--------------------------------------------------------------//

    /// 同じ書体だけのテキストなら、どこで止めても文字が切れないこと。
    func testUniformTextIsNeverClipped() {
        let textView = makeTextView(
            text: String(repeating: "あいうえおかきくけこ", count: 40),
            visibleLines: 6
        )

        let results = sweep(textView, lineHeight: 16)

        XCTAssertTrue(results.isEmpty, "和文だけなのに文字が切れた: \(describe(results))")
    }

    /// 空行が混ざっていても切れないこと。
    /// 空行はグリフを持つランがないので、境目の判定から抜け落ちやすい。
    func testTextWithEmptyLinesIsNeverClipped() {
        let textView = makeTextView(
            text: (0 ..< 40).map { "\($0)行目\n\n" }.joined(),
            visibleLines: 6
        )

        let results = sweep(textView, lineHeight: 16)

        XCTAssertTrue(results.isEmpty, "空行を含むテキストで文字が切れた: \(describe(results))")
    }

    /// 和欧混植でも切れないこと。
    func testMixedLatinAndJapaneseIsNeverClipped() {
        let textView = makeTextView(
            text: (0 ..< 40).map { "abc あいう \($0) def\n" }.joined(),
            visibleLines: 6
        )

        let results = sweep(textView, lineHeight: 16)

        XCTAssertTrue(results.isEmpty, "和欧混植で文字が切れた: \(describe(results))")
    }

    /// 行間を広げても切れないこと。
    func testWiderLineHeightIsNeverClipped() {
        let textView = makeTextView(
            text: String(repeating: "あいうえおかきくけこ", count: 40),
            visibleLines: 6,
            lineHeightScale: 1.5
        )

        let results = sweep(textView, lineHeight: 24)

        XCTAssertTrue(results.isEmpty, "行間 1.5 で文字が切れた: \(describe(results))")
    }

    /// 縦組みでも切れないこと。
    func testVerticalTextIsNeverClipped() {
        let textView = makeTextView(
            text: String(repeating: "あいうえおかきくけこ", count: 40),
            visibleLines: 6,
            direction: .tbRl
        )

        let results = sweep(textView, lineHeight: 16)

        XCTAssertTrue(results.isEmpty, "縦組みで文字が切れた: \(describe(results))")
    }

    //--------------------------------------------------------------//
    // MARK: - うまくいかない組み合わせ
    //--------------------------------------------------------------//

    /// 見える高さが行の高さの整数倍でないと、どこで止めても下端が切れること。
    ///
    /// scrollToWholeLines は先頭側の端しか動かさないので、下端が切れないことは
    /// 「高さが行の整数倍」に全面的に依存している。アプリ側のレイアウト処理
    /// がその高さを作るが、それが効かない経路がある。そのときはこの状態になる。
    func testNonMultipleHeightAlwaysClips() {
        let textView = makeTextView(
            text: String(repeating: "あいうえおかきくけこ", count: 40),
            visibleLines: 6,
            overrideLength: 100      // 16 の整数倍ではない
        )

        let results = sweep(textView, lineHeight: 16)

        XCTAssertFalse(
            results.isEmpty,
            "高さが行の整数倍でないのに切れなかった。scrollToWholeLines が両端を見るようになったなら、このテストを見直すこと"
        )
    }

    /// 絵文字を含む行でも切れないこと。
    ///
    /// 以前は切れていた。各ランの枠は「その書体のアセントからディセントまで」で、
    /// AppleColorEmoji はアセントを 1.25 em ほどに取るため、絵文字の枠が
    /// 行の枡から外れていた。STLayout.shiftPositionLrTb は文書全体を
    /// 「1 行目のランのうち最も上にあるもの」で正規化するので、その外れた枠が
    /// 基準になり、和文の枠が行の枡から 2.9pt ほど下にずれて次の行へはみ出していた。
    /// 反転描画する絵文字には行の枡を与え、字面をその中央に置くようにして解消した。
    func testEmojiLineIsNeverClipped() {
        let textView = makeTextView(
            text: (0 ..< 40).map { "あ😀漢\($0)\n" }.joined(),
            visibleLines: 6
        )

        let results = sweep(textView, lineHeight: 16)

        XCTAssertTrue(results.isEmpty, "絵文字を含む行で文字が切れた: \(describe(results))")
    }

    /// どのランも行の枡からはみ出さないこと。
    func testRunsStayInsideTheirLineBox() {
        for text in [
            (0 ..< 20).map { "あ😀漢\($0)\n" }.joined(),
            (0 ..< 20).map { "abc あいう \($0) 😀\n" }.joined(),
            "あ🇯🇵a😀漢👨‍👩‍👧‍👦\nいろは",
        ] {
            let textView = makeTextView(text: text, visibleLines: 6)
            let context = textView.label.context
            let lineHeight = context.adjustLineHeight

            for (runId, run) in context.runs.enumerated() where !run.isNewline && !run.isHidden {
                let box = CGFloat(run.line) * lineHeight
                let over = max(box - run.frame.minY, run.frame.maxY - (box + lineHeight))
                XCTAssertLessThanOrEqual(
                    over, tolerance,
                    "'\(context.runChars[runId])' が行の枡からはみ出した"
                        + "（枠 \(run.frame.minY)..\(run.frame.maxY) / 枡 \(box)..\(box + lineHeight)）"
                )
            }
        }
    }

    //--------------------------------------------------------------//
    // MARK: - スクロール停止以外の経路
    //--------------------------------------------------------------//

    /// 見える高さが変わっても、文字が切れないこと。
    ///
    /// ウィンドウの大きさを変えると、行の位置と見える範囲の関係が変わる。
    /// リサイズではスクロールの通知が来ないので、以前は前の大きさに合わせた
    /// 位置がそのまま残り、上端が行の途中に落ちていた。
    func testResizingKeepsLinesWhole() {
        let textView = makeTextView(
            text: String(repeating: "あいうえおかきくけこ", count: 40),
            visibleLines: 6
        )

        // いったん行の境目までスクロールしておく
        textView.contentView.setBoundsOrigin(CGPoint(x: 0, y: 48))
        textView.reflectScrolledClipView(textView.contentView)
        textView.scrollToWholeLines(animated: false)
        XCTAssertTrue(clippedRuns(textView).isEmpty, "前提が崩れた: 寄せた直後に切れている")

        // 高さを 1 行ぶんずつ変えていく。行の整数倍を保ったまま縮める／広げる
        for lines in [5, 4, 7, 3, 6] {
            textView.frame.size.height = 16 * CGFloat(lines)
            textView.layoutSubtreeIfNeeded()

            XCTAssertTrue(
                clippedRuns(textView).isEmpty,
                "高さを \(lines) 行に変えたら文字が切れた"
                    + "（見える範囲 \(textView.documentVisibleRect.minY)..\(textView.documentVisibleRect.maxY)）"
            )
        }
    }

    /// 半端な高さを経由しても、整数倍に戻れば切れないこと。
    /// リサイズの途中は行の整数倍でない高さを通る。
    func testResizingThroughNonMultipleHeights() {
        let textView = makeTextView(
            text: String(repeating: "あいうえおかきくけこ", count: 40),
            visibleLines: 6
        )

        textView.contentView.setBoundsOrigin(CGPoint(x: 0, y: 48))
        textView.reflectScrolledClipView(textView.contentView)
        textView.scrollToWholeLines(animated: false)

        // 半端な高さを何度か通す
        for height: CGFloat in [101, 87, 123, 94] {
            textView.frame.size.height = height
            textView.layoutSubtreeIfNeeded()
        }

        // 整数倍に戻す
        textView.frame.size.height = 16 * 6
        textView.layoutSubtreeIfNeeded()

        XCTAssertTrue(
            clippedRuns(textView).isEmpty,
            "半端な高さを経由したあと、整数倍に戻しても切れている"
                + "（見える範囲 \(textView.documentVisibleRect.minY)..\(textView.documentVisibleRect.maxY)）"
        )
    }

    /// 文字の大きさを変えても切れないこと。行の高さが変われば行の位置も動く。
    func testChangingFontSizeKeepsLinesWhole() {
        let textView = makeTextView(
            text: String(repeating: "あいうえおかきくけこ", count: 40),
            visibleLines: 6
        )

        textView.contentView.setBoundsOrigin(CGPoint(x: 0, y: 48))
        textView.reflectScrolledClipView(textView.contentView)
        textView.scrollToWholeLines(animated: false)

        for fontSize: CGFloat in [20, 12, 24] {
            // アプリと同じく、高さも行の整数倍にし直す
            textView.fontSize = fontSize
            textView.frame.size.height = fontSize * 6
            textView.layoutSubtreeIfNeeded()

            XCTAssertTrue(
                clippedRuns(textView).isEmpty,
                "文字の大きさを \(fontSize) にしたら切れた"
            )
        }
    }

    /// 行間を変えても切れないこと。
    func testChangingLineHeightKeepsLinesWhole() {
        let textView = makeTextView(
            text: String(repeating: "あいうえおかきくけこ", count: 40),
            visibleLines: 6
        )

        textView.contentView.setBoundsOrigin(CGPoint(x: 0, y: 48))
        textView.reflectScrolledClipView(textView.contentView)
        textView.scrollToWholeLines(animated: false)

        for scale: CGFloat in [1.5, 2.0, 1.0] {
            textView.lineHeightScale = scale
            textView.frame.size.height = 16 * scale * 6
            textView.layoutSubtreeIfNeeded()

            XCTAssertTrue(
                clippedRuns(textView).isEmpty,
                "行間を \(scale) にしたら切れた"
            )
        }
    }

    /// Page Down / Page Up でスクロールしても、行が端で切れないこと。
    ///
    /// ページ送りは行の高さの整数倍だけ動かし、そのうえで行に合わせる。
    /// 見える範囲は行の高さの整数倍にしておく。下端が切れないことはアプリ側が
    /// ビューの大きさで支えるもので、スクロールだけでは保証できないため。
    func testPageScrollingShowsWholeLines() {
        for direction in [STDirection.lrTb, .tbRl] {
            for scale: CGFloat in [1.0, 1.5, 1.75] {
                let textView = makeTextView(
                    text: String(repeating: "あいうえおかきくけこ", count: 40),
                    visibleLines: 6,
                    lineHeightScale: scale,
                    direction: direction
                )

                textView.scrollToBeginningOfDocument(nil)
                for (name, scroll) in [
                    ("scrollPageDown", { textView.scrollPageDown(nil) }),
                    ("scrollPageDown", { textView.scrollPageDown(nil) }),
                    ("scrollPageUp", { textView.scrollPageUp(nil) }),
                    ("pageDown", { textView.pageDown(nil) }),
                    ("pageUp", { textView.pageUp(nil) }),
                ] as [(String, () -> Void)] {
                    scroll()
                    textView.layoutSubtreeIfNeeded()
                    XCTAssertTrue(
                        clippedRuns(textView).isEmpty,
                        "[\(direction) 行間 \(scale)] \(name) のあとで行が切れた"
                    )
                }
            }
        }
    }

    /// キャレットを追ってスクロールしたあとも切れず、かつキャレットが見えていること。
    ///
    /// キャレット追従は最小限しか動かさないので、その行が端に半分掛かった状態で
    /// 止まる。ここで「近いほうの境目」に寄せると行ごと画面外へ出てしまい、
    /// キャレットまで見えなくなる。見せる側へ寄せる必要がある。
    func testFollowingTheCaretKeepsItsLineWhole() {
        let textView = makeTextView(
            text: String(repeating: "あいうえおかきくけこ", count: 40),
            visibleLines: 6
        )
        let context = textView.label.context

        for index in [70, 5, 200, 120, 399] {
            textView.selectedTextRange = STTextRange(range: index ..< index)
            textView.needsToScrollToShowCurosr = true
            textView.layoutSubtreeIfNeeded()

            XCTAssertTrue(
                clippedRuns(textView).isEmpty,
                "キャレットを \(index) へ移したあとに文字が切れた"
            )

            // キャレットの行が見えていること
            let cursor = textView.textDocumentView.convert(context.cursorFrame(at: index), from: textView.label)
            let visible = textView.documentVisibleRect
            XCTAssertTrue(
                visible.intersects(cursor),
                "キャレットが画面外に出た index=\(index)"
                    + "（キャレット \(cursor.minY)..\(cursor.maxY) / 見える範囲 \(visible.minY)..\(visible.maxY)）"
            )
        }
    }

    //--------------------------------------------------------------//
    // MARK: - 呼ばれる経路
    //--------------------------------------------------------------//

    /// 端が行の境目にあるときは動かないこと（無駄なスクロールをしない）。
    func testDoesNotMoveWhenAlreadyOnABoundary() {
        let textView = makeTextView(
            text: String(repeating: "あいうえおかきくけこ", count: 40),
            visibleLines: 6
        )

        textView.contentView.setBoundsOrigin(CGPoint(x: 0, y: 32))
        textView.reflectScrolledClipView(textView.contentView)
        let before = textView.documentVisibleRect.minY

        textView.scrollToWholeLines(animated: false)

        XCTAssertEqual(textView.documentVisibleRect.minY, before, accuracy: 0.001, "境目にいるのに動いた")
    }

    /// 端が行の途中にあるときは動くこと。
    func testMovesWhenStoppedMidLine() {
        let textView = makeTextView(
            text: String(repeating: "あいうえおかきくけこ", count: 40),
            visibleLines: 6
        )

        textView.contentView.setBoundsOrigin(CGPoint(x: 0, y: 40))
        textView.reflectScrolledClipView(textView.contentView)

        textView.scrollToWholeLines(animated: false)

        XCTAssertNotEqual(textView.documentVisibleRect.minY, 40, accuracy: 0.001, "行の途中で止まったのに動かない")
        XCTAssertTrue(clippedRuns(textView).isEmpty, "寄せたのに文字が切れている")
    }

    /// テキストが空でも落ちないこと。
    func testEmptyTextDoesNothing() {
        let textView = makeTextView(text: "", visibleLines: 6)

        textView.scrollToWholeLines(animated: false)

        XCTAssertEqual(textView.documentVisibleRect.minY, 0, accuracy: 0.001)
    }
}
#endif
