/*
STMaxLineCountTests.swift

行数制限と省略記号を検証する。

テキストを何行までに収めるかは組版の結果そのものではなく、組んだあとの
「どのランを描くか」で決まる。行数を超えた行のランは invisible になり、
テキストが返す大きさからも外れる。省略記号を出すときは、最後に描かれる
ランが ellipsis に替わる。

いちばん大事なのは、既定（maxLineCount = 0）では何も変わらないこと。
*/

import XCTest
@testable import stone_engine

@MainActor
final class STMaxLineCountTests: STEngineTestCase {

    //--------------------------------------------------------------//
    // MARK: - Helper
    //--------------------------------------------------------------//

    /// 全角 charsPerLine 文字ぶんの幅しかない横組みの文脈。
    private func makeNarrowContext(
        charsPerLine: Int,
        direction: STDirection = .lrTb,
        fontSize: CGFloat = 16
    ) -> STContext {
        let inline = fontSize * CGFloat(charsPerLine)
        let block: CGFloat = 400
        return makeContext(
            direction: direction,
            fontSize: fontSize,
            renderSize: direction == .lrTb
                ? CGSize(width: inline, height: block)
                : CGSize(width: block, height: inline)
        )
    }

    /// 描かれるランの文字列。
    private func shownText(_ context: STContext) -> String {
        return String(
            (0 ..< context.runs.count)
                .filter { context.runs[$0].visibility != .invisible }
                .map { context.runChars[$0] }
        )
    }

    private func visibilities(_ context: STContext) -> [STRunVisibility] {
        return context.runs.map { $0.visibility }
    }

    //--------------------------------------------------------------//
    // MARK: - 既定
    //--------------------------------------------------------------//

    /// 行数を指定しなければ、どの行も描かれる。
    func testUnlimitedByDefault() {
        let context = makeNarrowContext(charsPerLine: 3)
        XCTAssertEqual(context.maxLineCount, 0)
        XCTAssertFalse(context.isShownEllipsis)

        layout("あいうえおかきくけこ", into: context)

        XCTAssertEqual(context.lineCount, 4)
        XCTAssertTrue(
            context.runs.allSatisfy { $0.visibility == .visible },
            "既定で描かれないランがある: \(visibilities(context))"
        )
        XCTAssertFalse(context.isTruncated)
    }

    /// isShownLine は、指定が無ければ常に真。
    func testIsShownLineWithoutLimit() {
        let context = makeContext()
        for line in 0 ..< 100 {
            XCTAssertTrue(context.isShownLine(line))
        }
    }

    //--------------------------------------------------------------//
    // MARK: - 行数制限
    //--------------------------------------------------------------//

    /// 指定した行までしか描かれない。
    func testLinesPastTheCountAreNotDrawn() {
        let context = makeNarrowContext(charsPerLine: 3)
        context.maxLineCount = 2
        layout("あいうえおかきくけこ", into: context)

        // 組むこと自体はする。どこで行が変わるかを知らないと、
        // 行数を数えることもできない
        XCTAssertEqual(context.lineCount, 4, "行は最後まで組まれる")
        XCTAssertEqual(shownText(context), "あいうえおか", "2 行ぶんだけ描かれる")
    }

    /// 行数に収まっていれば何も落とさない。
    func testCountLargerThanTheTextChangesNothing() {
        let context = makeNarrowContext(charsPerLine: 3)
        context.maxLineCount = 10
        layout("あいうえおかきくけこ", into: context)

        XCTAssertEqual(shownText(context), "あいうえおかきくけこ")
        XCTAssertFalse(context.isTruncated)
    }

    /// 落とした行は、テキストが返す大きさにも入らない。
    func testRenderedSizeLeavesOutTheLinesNotDrawn() {
        let text = "あいうえおかきくけこ"

        let full = makeNarrowContext(charsPerLine: 3)
        layout(text, into: full)

        let limited = makeNarrowContext(charsPerLine: 3)
        limited.maxLineCount = 2
        layout(text, into: limited)

        XCTAssertLessThan(
            limited.renderedSize.height, full.renderedSize.height,
            "落とした行のぶん高さが減っていない"
        )
        XCTAssertEqual(
            limited.renderedSize.height, full.renderedSize.height * 0.5,
            accuracy: 0.5,
            "4 行を 2 行に収めたのに高さが半分にならない"
        )
    }

    /// 縦組みでも同じ。落とした行のぶん幅が減る。
    func testRenderedSizeTbRl() {
        let text = "あいうえおかきくけこ"

        let full = makeNarrowContext(charsPerLine: 3, direction: .tbRl)
        layout(text, into: full)

        let limited = makeNarrowContext(charsPerLine: 3, direction: .tbRl)
        limited.maxLineCount = 2
        layout(text, into: limited)

        XCTAssertLessThan(
            limited.renderedSize.width, full.renderedSize.width,
            "落とした行のぶん幅が減っていない"
        )
    }

    /// 行数で切り詰められたテキストは、切り詰められたと答える。
    ///
    /// adjustsFontSizeToFitWidth はこれを見て文字を小さくするので、
    /// ここが偽だと「入っていないのに入ったことになる」。
    func testTruncatedByLineCount() {
        let context = makeNarrowContext(charsPerLine: 3)
        context.maxLineCount = 2
        layout("あいうえおかきくけこ", into: context)

        XCTAssertTrue(context.isTruncated)
    }

    //--------------------------------------------------------------//
    // MARK: - 省略記号
    //--------------------------------------------------------------//

    /// 指定しなければ記号は出ない。切れるところで切れるだけ。
    func testNoEllipsisByDefault() {
        let context = makeNarrowContext(charsPerLine: 3)
        context.maxLineCount = 2
        layout("あいうえおかきくけこ", into: context)

        XCTAssertFalse(
            context.runs.contains { $0.visibility == .ellipsis },
            "指定していないのに記号が出ている"
        )
    }

    /// 指定すると、最後に描かれるランが記号に替わる。
    func testEllipsisReplacesTheLastShownRun() {
        let context = makeNarrowContext(charsPerLine: 3)
        context.maxLineCount = 2
        context.isShownEllipsis = true
        layout("あいうえおかきくけこ", into: context)

        let ellipsisIds = (0 ..< context.runs.count)
            .filter { context.runs[$0].visibility == .ellipsis }
        XCTAssertEqual(ellipsisIds.count, 1, "記号が 1 つではない")

        guard let markId = ellipsisIds.first else { return }
        XCTAssertEqual(
            context.runs[markId].line, 1,
            "記号が最後に描かれる行に無い"
        )
        XCTAssertTrue(
            (markId + 1 ..< context.runs.count).allSatisfy {
                context.runs[$0].visibility == .invisible
            },
            "記号より後ろに描かれるランが残っている"
        )
    }

    /// 全部収まっているときは記号を出さない。
    func testNoEllipsisWhenNothingIsCutOff() {
        let context = makeNarrowContext(charsPerLine: 10)
        context.maxLineCount = 5
        context.isShownEllipsis = true
        layout("あいうえ", into: context)

        XCTAssertFalse(
            context.runs.contains { $0.visibility == .ellipsis },
            "切れていないのに記号が出ている"
        )
        XCTAssertFalse(context.isTruncated)
    }

    /// 記号は組まれる範囲の中に収まる。
    ///
    /// 記号は置き換える字より広いことが多いので、入らなければ手前の字を
    /// 譲っていく。入らないまま置くと、縁で切られて何も読めなくなる。
    func testEllipsisFitsInsideTheRoom() {
        let context = makeNarrowContext(charsPerLine: 3)
        context.maxLineCount = 1
        context.isShownEllipsis = true
        layout("あいうえおかきくけこ", into: context)

        guard let markId = (0 ..< context.runs.count)
            .first(where: { context.runs[$0].visibility == .ellipsis })
        else {
            XCTFail("記号が出ていない")
            return
        }

        let advance = context.fontManager.ellipsisAdvance(
            fontId: context.runs[markId].fontId,
            size: context.adjustFontSize * context.runs[markId].fontScale,
            direction: .lrTb
        )
        XCTAssertLessThanOrEqual(
            context.runs[markId].frame.minX + advance,
            context.renderSize.width,
            "記号が組まれる範囲からはみ出している"
        )
    }

    //--------------------------------------------------------------//
    // MARK: - ルビとの関係
    //--------------------------------------------------------------//

    /// 記号は読みの上には置かない。
    ///
    /// 読みは本文より小さく、行の上の余白に組まれる。そこに記号を置くと、
    /// 下の語の読みとして読まれてしまう。
    func testEllipsisIsNotPutOnAReading() {
        // 1 行 3 文字ぶんの幅。読みつきの語は 2 文字ぶんを占めるので、
        // 2 つめの語は次の行へ送られる
        let context = makeNarrowContext(charsPerLine: 3)
        context.rubyNotation = .braces
        context.lineHeightScale = 1.5
        context.maxLineCount = 1
        context.isShownEllipsis = true
        layout("{晴天|せいてん}{曇天|どんてん}", into: context)

        guard let markId = (0 ..< context.runs.count)
            .first(where: { context.runs[$0].visibility == .ellipsis })
        else {
            XCTFail("記号が出ていない")
            return
        }

        for ruby in context.rubies {
            XCTAssertFalse(
                ruby.rtcRunIdRange.contains(markId),
                "記号が読みの上に置かれている"
            )
        }
    }
}
