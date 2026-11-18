/*
STLayoutTests.swift

STLayout の幾何・行分割・揃えの検証。

グリフの送りはフォントのバージョンで動くので、絶対座標ではなく
「同じ行の中では単調に進む」「行は一方向に積まれる」「行数と lineCount が合う」
といった関係で書く。数値を直接見るのは、約物や縦中横のように
1 文字ぶんの枡目が決まっているところだけに絞る。
*/

import XCTest
@testable import stone_engine

@MainActor
final class STLayoutTests: STEngineTestCase {

    private let sampleTexts: [(name: String, text: String)] = [
        ("empty",       ""),
        ("single",      "あ"),
        ("ascii",       "Hello, world! This is a test of the layout engine."),
        ("japanese",    "吾輩は猫である。名前はまだ無い。どこで生れたかとんと見当がつかぬ。"),
        ("brackets",    "「こんにちは」と彼は言った（笑）。"),
        ("mixed",       "abc あ、い 漢字 123 😀"),
        ("newlines",    "いち\nに\r\nさん\rよん"),
        ("trailingNL",  "おわり\n"),
        ("newlineOnly", "\n\n\n"),
        ("emoji",       "あ🇯🇵a😀漢👨‍👩‍👧‍👦"),
        ("long",        String(repeating: "あいうえおかきくけこ", count: 20)),
    ]

    //--------------------------------------------------------------//
    // MARK: - 不変条件
    //--------------------------------------------------------------//

    /// レイアウト後に必ず成り立つ性質をまとめて確かめる。
    private func assertInvariants(_ context: STContext, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        // すべての座標が有限
        for (runId, run) in context.runs.enumerated() {
            XCTAssertTrue(
                run.frame.isFinite && run.position.x.isFinite && run.position.y.isFinite,
                "[\(label)] 座標が有限でない runId=\(runId) frame=\(run.frame) position=\(run.position)",
                file: file, line: line
            )
            XCTAssertGreaterThanOrEqual(run.frame.width, 0, "[\(label)] 幅が負 runId=\(runId)", file: file, line: line)
            XCTAssertGreaterThanOrEqual(run.frame.height, 0, "[\(label)] 高さが負 runId=\(runId)", file: file, line: line)
        }

        // 行番号は run 順に単調非減少で、0 から 1 ずつ増える
        var expectedLine = 0
        for (runId, run) in context.runs.enumerated() {
            XCTAssertTrue(
                run.line == expectedLine || run.line == expectedLine + 1,
                "[\(label)] 行番号が飛んだ runId=\(runId) line=\(run.line) 直前=\(expectedLine)",
                file: file, line: line
            )
            expectedLine = run.line
        }

        // lineCount は実際に使われた行数と一致する。
        // テキストが改行で終わるときは、ランを 1 つも持たない空行が末尾に増える。
        let trailingEmptyLine = context.runs.last?.isNewline == true ? 1 : 0
        let expectedLineCount = context.runs.isEmpty ? 1 : expectedLine + 1 + trailingEmptyLine
        XCTAssertEqual(
            context.lineCount, expectedLineCount,
            "[\(label)] lineCount が実際の行数と違う",
            file: file, line: line
        )

        // 行内・行間の並び
        for range in lineRanges(context) {
            for runId in range.dropFirst() {
                let prev = context.runs[runId - 1].frame
                let curr = context.runs[runId].frame
                switch context.direction {
                case .lrTb:
                    XCTAssertGreaterThanOrEqual(
                        curr.minX, prev.minX - 0.001,
                        "[\(label)] 横組みで行内の x が戻った runId=\(runId)",
                        file: file, line: line
                    )
                case .tbRl:
                    XCTAssertGreaterThanOrEqual(
                        curr.minY, prev.minY - 0.001,
                        "[\(label)] 縦組みで行内の y が戻った runId=\(runId)",
                        file: file, line: line
                    )
                }
            }
        }

        let ranges = lineRanges(context)
        for index in ranges.indices.dropFirst() {
            let prev = context.runs[ranges[index - 1].lowerBound].frame
            let curr = context.runs[ranges[index].lowerBound].frame
            switch context.direction {
            case .lrTb:
                // 行は上から下へ積まれる
                XCTAssertGreaterThan(
                    curr.minY, prev.minY,
                    "[\(label)] 横組みで行が下に進んでいない 行=\(index)",
                    file: file, line: line
                )
            case .tbRl:
                // 行は右から左へ積まれる
                XCTAssertLessThan(
                    curr.minX, prev.minX,
                    "[\(label)] 縦組みで行が左に進んでいない 行=\(index)",
                    file: file, line: line
                )
            }
        }
    }

    func testInvariantsLrTb() {
        for sample in sampleTexts {
            let context = layout(sample.text, into: makeContext(renderSize: CGSize(width: 16 * 12, height: 400)))
            assertInvariants(context, "lrTb/\(sample.name)")
        }
    }

    func testInvariantsTbRl() {
        for sample in sampleTexts {
            let context = layout(sample.text, into: makeContext(direction: .tbRl, renderSize: CGSize(width: 400, height: 16 * 12)))
            assertInvariants(context, "tbRl/\(sample.name)")
        }
    }

    /// 揃えと約物モードを総当たりしても不変条件が崩れないこと。
    func testInvariantsAcrossSettings() {
        for direction in STDirection.allCases {
            for textAlign in STTextAlign.allCases {
                for punctuationMode in STPunctuationMode.allCases {
                    let context = makeContext(
                        direction: direction,
                        punctuationMode: punctuationMode,
                        renderSize: direction == .lrTb
                            ? CGSize(width: 16 * 10, height: 400)
                            : CGSize(width: 400, height: 16 * 10)
                    )
                    context.textAlign = textAlign
                    layout("「吾輩は猫である」と、名前はまだ無い。\nabc 123 😀", into: context)
                    assertInvariants(context, "\(direction)/\(textAlign)/\(punctuationMode)")
                }
            }
        }
    }

    //--------------------------------------------------------------//
    // MARK: - 空・改行
    //--------------------------------------------------------------//

    func testEmptyTextHasOneLine() {
        let context = layout("")
        XCTAssertTrue(context.runs.isEmpty, "空文字列でランができた")
        XCTAssertEqual(context.lineCount, 1, "空文字列でも行は 1 行ぶんある")
    }

    /// 改行のたびに行が増えること。
    func testNewlinesBreakLines() {
        XCTAssertEqual(layout("あ").lineCount, 1)
        XCTAssertEqual(layout("あ\nい").lineCount, 2)
        XCTAssertEqual(layout("あ\r\nい").lineCount, 2, "CRLF が 2 行に割れた")
        XCTAssertEqual(layout("あ\rい").lineCount, 2, "CR で改行していない")
        XCTAssertEqual(layout("あ\n").lineCount, 2, "末尾の改行の後ろに行がない")
        XCTAssertEqual(layout("\n\n\n").lineCount, 4)
    }

    /// 改行文字は幅ゼロで、その行の末尾に置かれること。
    func testNewlineRunIsZeroWidth() {
        let context = layout("ab\ncd", into: makeContext(renderSize: CGSize(width: 200, height: 200)))
        let newline = context.runs[2]
        XCTAssertTrue(newline.isNewline)
        XCTAssertEqual(newline.frame.width, 0, "横組みの改行に幅がある")
        XCTAssertEqual(newline.line, 0, "改行が次の行に送られている")
        XCTAssertEqual(context.runs[3].line, 1, "改行の次の文字が同じ行にいる")
    }

    //--------------------------------------------------------------//
    // MARK: - 行分割
    //--------------------------------------------------------------//

    /// 指定幅ちょうどの文字数で折り返すこと（全角・禁則にかからない文字で確認）。
    func testWrapsAtRenderWidth() {
        let text = "あいうえおかきくけこさしすせそ"   // 15 文字
        for charsPerLine in [3, 5, 6] {
            let context = layout(text, into: makeContext(renderSize: CGSize(width: 16 * CGFloat(charsPerLine), height: 400)))
            let texts = lineTexts(context)
            XCTAssertEqual(
                texts.map(\.count).max(), charsPerLine,
                "1 行の最大文字数が \(charsPerLine) でない: \(texts)"
            )
            XCTAssertEqual(texts.joined(), text, "折り返しで文字が失われた")
            XCTAssertEqual(context.lineCount, texts.count, "lineCount と行数が合わない")
        }
    }

    /// 折り返した行が指定幅に収まること。
    func testLinesFitInRenderWidth() {
        let width: CGFloat = 16 * 6
        let context = layout("あいうえおかきくけこさしすせそたちつてと", into: makeContext(renderSize: CGSize(width: width, height: 400)))
        for range in lineRanges(context) {
            let maxX = range.map { context.runs[$0].frame.maxX }.max() ?? 0
            XCTAssertLessThanOrEqual(maxX, width + 0.001, "行が指定幅をはみ出した")
        }
    }

    /// 1 文字も入らない幅でも 1 文字ずつ組んで停止すること（無限ループ検出）。
    func testTinyRenderWidthDoesNotHang() {
        let context = layout("あいう", into: makeContext(renderSize: CGSize(width: 4, height: 400)))
        XCTAssertEqual(context.lineCount, 3, "1 文字ずつ改行されていない")
        XCTAssertEqual(lineTexts(context), ["あ", "い", "う"])
    }

    /// 単一行モードでは幅に関係なく 1 行に組み、はみ出しは不可視になること。
    func testSingleLine() {
        let context = makeContext(renderSize: CGSize(width: 16 * 3, height: 400))
        context.isSingleLine = true
        layout("あいうえおかきく", into: context)

        XCTAssertEqual(context.lineCount, 1, "単一行モードで折り返した")
        XCTAssertTrue(context.runs.allSatisfy { $0.line == 0 })
        XCTAssertEqual(context.runs.prefix(3).filter(\.isHidden).count, 0, "幅に収まる文字が隠れている")
        XCTAssertTrue(context.runs.suffix(4).allSatisfy(\.isHidden), "はみ出した文字が隠れていない")
        XCTAssertTrue(context.isTruncated, "isTruncated が立っていない")
    }

    func testNotTruncatedWhenEverythingFits() {
        let context = makeContext(renderSize: CGSize(width: 16 * 10, height: 400))
        context.isSingleLine = true
        layout("あいう", into: context)
        XCTAssertFalse(context.isTruncated, "収まっているのに isTruncated が立っている")
    }

    //--------------------------------------------------------------//
    // MARK: - renderedSize
    //--------------------------------------------------------------//

    /// renderedSize が実際に置かれたランの広がりと一致すること。
    func testRenderedSizeMatchesRuns() {
        let context = layout("あいうえおかきくけこさし", into: makeContext(renderSize: CGSize(width: 16 * 5, height: 400)))
        let maxX = context.runs.map { $0.frame.maxX }.max() ?? 0

        XCTAssertEqual(context.renderedSize.width, maxX, accuracy: 0.001, "renderedSize.width がランの右端と違う")
        XCTAssertEqual(
            context.renderedSize.height, context.lineHeight * CGFloat(context.lineCount), accuracy: 0.001,
            "renderedSize.height が 行数 × 行高 と違う"
        )
    }

    func testRenderedSizeMatchesRunsTbRl() {
        let context = layout("あいうえおかきくけこさし", into: makeContext(direction: .tbRl, renderSize: CGSize(width: 400, height: 16 * 5)))
        let minY = context.runs.map { $0.frame.minY }.min() ?? 0
        let maxY = context.runs.map { $0.frame.maxY }.max() ?? 0

        XCTAssertEqual(context.renderedSize.height, maxY - minY, accuracy: 0.001, "縦組みの renderedSize.height がランの広がりと違う")
        XCTAssertEqual(
            context.renderedSize.width, context.lineHeight * CGFloat(context.lineCount), accuracy: 0.001,
            "縦組みの renderedSize.width が 行数 × 行高 と違う"
        )
    }

    /// 行間を広げると行の間隔がそのぶん開くこと。
    func testLineHeightScale() {
        for scale: CGFloat in [1.0, 1.5, 2.0] {
            let context = makeContext(renderSize: CGSize(width: 16 * 3, height: 400))
            context.lineHeightScale = scale
            layout("あいうえおか", into: context)

            let ranges = lineRanges(context)
            XCTAssertEqual(ranges.count, 2, "2 行にならなかった（scale: \(scale)）")
            let dy = context.runs[ranges[1].lowerBound].frame.minY - context.runs[ranges[0].lowerBound].frame.minY
            XCTAssertEqual(dy, 16 * scale, accuracy: 0.001, "行間が lineHeight と合わない（scale: \(scale)）")
        }
    }

    //--------------------------------------------------------------//
    // MARK: - textAlign
    //--------------------------------------------------------------//

    private func lineFrames(_ context: STContext, line: Int) -> (minX: CGFloat, maxX: CGFloat) {
        let range = lineRanges(context)[line]
        return (
            range.map { context.runs[$0].frame.minX }.min() ?? 0,
            range.map { context.runs[$0].frame.maxX }.max() ?? 0
        )
    }

    func testTextAlignLrTb() {
        let width: CGFloat = 16 * 8
        let text = "あいうえ"   // 4 文字 = 64pt、余白 64pt

        var results = [STTextAlign: (minX: CGFloat, maxX: CGFloat)]()
        for align in STTextAlign.allCases {
            let context = makeContext(renderSize: CGSize(width: width, height: 400))
            context.textAlign = align
            layout(text, into: context)
            results[align] = lineFrames(context, line: 0)
        }

        XCTAssertEqual(results[.leading]!.minX, 0, accuracy: 0.001, "leading が左端から始まっていない")
        XCTAssertEqual(results[.center]!.minX, 32, accuracy: 0.001, "center が中央に寄っていない")
        XCTAssertEqual(results[.trailng]!.maxX, width, accuracy: 0.001, "trailing が右端で終わっていない")
        // 最終行は均等割りの対象外なので leading と同じ
        XCTAssertEqual(results[.justify]!.minX, 0, accuracy: 0.001, "最終行が均等割りされている")
    }

    /// 均等割りは、折り返した行（= 最終行でも改行終わりでもない行）だけを伸ばすこと。
    func testJustifyStretchesWrappedLinesOnly() {
        let width: CGFloat = 100
        let text = "aaa bbb ccc ddd eee fff"

        let justified = makeContext(renderSize: CGSize(width: width, height: 400))
        justified.textAlign = .justify
        layout(text, into: justified)

        let leading = makeContext(renderSize: CGSize(width: width, height: 400))
        leading.textAlign = .leading
        layout(text, into: leading)

        XCTAssertEqual(justified.lineCount, 2, "2 行に折り返す前提が崩れた")
        XCTAssertEqual(leading.lineCount, 2)

        // 1 行目（折り返した行）は右端まで伸びる
        XCTAssertEqual(lineFrames(justified, line: 0).maxX, width, accuracy: 0.001, "折り返した行が右端まで伸びていない")
        XCTAssertLessThan(lineFrames(leading, line: 0).maxX, width - 1, "leading が既に右端まで来ている（前提が崩れた）")

        // 最終行は伸ばさない
        XCTAssertEqual(
            lineFrames(justified, line: 1).maxX, lineFrames(leading, line: 1).maxX, accuracy: 0.001,
            "最終行が均等割りされている"
        )
    }

    /// 均等割りした行が、指定の幅ちょうどで終わること。
    ///
    /// 報告のあった不具合。stone モードでは、閉じ括弧の直後に来た開き括弧を
    /// 半角に詰めたうえ、描画位置だけ半角ぶん左へ出す。均等割りが各ランの
    /// 位置を走るカーソルから組み直していたころは、その送りに
    /// frame.maxX - position.x を使っていたため、はみ出したぶんを二重に数えて
    /// いた。1 行に 2 つあると、ちょうど 1 文字ぶん右へあふれる。
    func testJustifiedLinesEndExactlyAtTheMeasure() {
        let text = "　女達はアレキサンダー君を、『サーシャ』『サーシャ』と呼んで取り巻いた。"
            + "アレキサンダー君の女は、頭を見事な男刈りにした、眉根の険しい感じのする、"
            + "十七、八にしか見えない小娘であった。"

        for charsPerLine in 20 ... 28 {
            let width = 16 * CGFloat(charsPerLine)
            let context = makeContext(renderSize: CGSize(width: width, height: 4000))
            context.textAlign = .justify
            layout(text, into: context)

            let ranges = lineRanges(context)
            XCTAssertGreaterThan(ranges.count, 2, "\(charsPerLine) 文字で複数行にならない")

            // 最終行は均等割りの対象外なので除く
            for (index, range) in ranges.enumerated() where index < ranges.count - 1 {
                let maxX = range.map { context.runs[$0].frame.maxX }.max() ?? 0
                XCTAssertEqual(
                    maxX, width, accuracy: 0.001,
                    "\(charsPerLine) 文字の \(index) 行目が指定幅で終わらない"
                        + "（\(maxX) / 指定 \(width)）: \(String(context.runChars[range]))"
                )
            }
        }
    }

    /// 均等割りは、行の中の並び順と重なりを壊さないこと。
    func testJustifyKeepsRunsInOrder() {
        let text = "　『あ』『い』うえお、かきくけこ。さしすせそたちつてと。なにぬねのはひふへほ"
        let context = makeContext(renderSize: CGSize(width: 16 * 12, height: 2000))
        context.textAlign = .justify
        layout(text, into: context)

        for range in lineRanges(context) {
            for runId in range.dropFirst() {
                XCTAssertGreaterThanOrEqual(
                    context.runs[runId].frame.minX, context.runs[runId - 1].frame.minX - 0.001,
                    "均等割りで並び順が入れ替わった runId=\(runId)"
                )
            }
        }
    }

    /// 均等割りでも、描画位置と枡の関係（約物の食い込み）が保たれること。
    func testJustifyPreservesPunctuationOverhang() {
        let text = "　女達はアレキサンダー君を、『サーシャ』『サーシャ』と呼んで取り巻いた。あいうえお"

        let plain = makeContext(renderSize: CGSize(width: 16 * 23, height: 2000))
        plain.textAlign = .leading
        layout(text, into: plain)

        let justified = makeContext(renderSize: CGSize(width: 16 * 23, height: 2000))
        justified.textAlign = .justify
        layout(text, into: justified)

        XCTAssertEqual(plain.runs.count, justified.runs.count, "前提が崩れた")
        for runId in 0 ..< plain.runs.count {
            let before = plain.runs[runId].frame.minX - plain.runs[runId].position.x
            let after = justified.runs[runId].frame.minX - justified.runs[runId].position.x
            XCTAssertEqual(
                after, before, accuracy: 0.001,
                "均等割りで約物の食い込みが変わった runId=\(runId) '\(plain.runChars[runId])'"
            )
        }
    }

    //--------------------------------------------------------------//
    // MARK: - directionAlign
    //--------------------------------------------------------------//

    func testDirectionAlignLrTb() {
        let height: CGFloat = 100
        var results = [STDirectionAlign: (minY: CGFloat, maxY: CGFloat)]()
        for align in STDirectionAlign.allCases {
            let context = makeContext(renderSize: CGSize(width: 16 * 4, height: height))
            context.directionAlign = align
            layout("あいうえおか", into: context)   // 2 行 = 32pt
            results[align] = (
                context.runs.map { $0.frame.minY }.min() ?? 0,
                context.runs.map { $0.frame.maxY }.max() ?? 0
            )
        }

        XCTAssertEqual(results[.start]!.minY, 0, accuracy: 0.001, "start が上端から始まっていない")
        XCTAssertEqual(results[.end]!.maxY, height, accuracy: 0.001, "end が下端で終わっていない")

        // middle は上下中央に来る
        let span = results[.middle]!.maxY - results[.middle]!.minY
        XCTAssertEqual(
            results[.middle]!.minY, (height - span) * 0.5, accuracy: 0.001,
            "middle が上下中央に来ていない"
        )
        XCTAssertEqual(
            height - results[.middle]!.maxY, results[.middle]!.minY, accuracy: 0.001,
            "middle の上下の余白が揃っていない"
        )
    }

    /// 縦組みの middle も左右中央に来ること。
    func testDirectionAlignMiddleTbRl() {
        let width: CGFloat = 100
        let context = makeContext(direction: .tbRl, renderSize: CGSize(width: width, height: 16 * 4))
        context.directionAlign = .middle
        layout("あいうえおか", into: context)   // 2 行

        let minX = context.runs.map { $0.frame.minX }.min() ?? 0
        let maxX = context.runs.map { $0.frame.maxX }.max() ?? 0
        XCTAssertEqual(minX, width - maxX, accuracy: 0.001, "縦組みの middle で左右の余白が揃っていない")
    }

    /// 縦組みは右端から左へ組むので、start は右端に着く。
    func testDirectionAlignTbRl() {
        let width: CGFloat = 100
        let context = makeContext(direction: .tbRl, renderSize: CGSize(width: width, height: 16 * 4))
        layout("あいうえおか", into: context)   // 2 行

        XCTAssertEqual(
            context.runs.map { $0.frame.maxX }.max() ?? 0, width, accuracy: 0.001,
            "縦組みの 1 行目が右端に来ていない"
        )
        XCTAssertLessThan(
            context.runs.last!.frame.minX, context.runs.first!.frame.minX,
            "縦組みで行が左へ進んでいない"
        )
    }

    //--------------------------------------------------------------//
    // MARK: - 再レイアウト
    //--------------------------------------------------------------//

    /// 同じ context を同じ条件で組み直しても結果が変わらないこと。
    func testLayoutIsIdempotent() {
        let context = layout("「吾輩は猫である」と、名前はまだ無い。\nabc 123", into: makeContext(renderSize: CGSize(width: 16 * 8, height: 400)))
        let before = context.runs.map(\.frame)
        let beforeLineCount = context.lineCount

        STLayout(context: context).layout()

        XCTAssertEqual(context.runs.map(\.frame), before, "組み直しで位置が変わった")
        XCTAssertEqual(context.lineCount, beforeLineCount, "組み直しで行数が変わった")
    }

    /// 幅を変えて組み直すと、行分割が新しい幅に追随すること。
    func testRelayoutFollowsNewWidth() {
        let context = makeContext(renderSize: CGSize(width: 16 * 10, height: 400))
        layout("あいうえおかきくけこさしすせそ", into: context)
        XCTAssertEqual(context.lineCount, 2)

        context.renderSize.width = 16 * 5
        STLayout(context: context).layout()
        XCTAssertEqual(context.lineCount, 3, "幅を狭めても行数が変わらない")
        XCTAssertEqual(lineTexts(context).joined(), "あいうえおかきくけこさしすせそ", "組み直しで文字が失われた")
    }
}

extension CGRect {
    fileprivate var isFinite: Bool {
        return minX.isFinite && minY.isFinite && width.isFinite && height.isFinite
    }
}
