/*
STLayoutKinsokuTests.swift

禁則処理・ぶら下がり・約物モードの検証。

日本語組版のうち、字面ではなく枡目の割り当てが決まる部分。
1 文字 = fontSize ちょうどの枡に載る全角文字だけを使えば、
フォントの送りに依存せずに数値そのものを確かめられる。
*/

import XCTest
@testable import stone_engine

@MainActor
final class STLayoutKinsokuTests: STEngineTestCase {

    /// 全角 charsPerLine 文字ぶんの幅を持つ横組みコンテキスト。
    private func hContext(charsPerLine: Int, punctuationMode: STPunctuationMode = .stone) -> STContext {
        return makeContext(
            punctuationMode: punctuationMode,
            renderSize: CGSize(width: 16 * CGFloat(charsPerLine), height: 400)
        )
    }

    /// 全角 charsPerLine 文字ぶんの高さを持つ縦組みコンテキスト。
    private func vContext(charsPerLine: Int, punctuationMode: STPunctuationMode = .stone) -> STContext {
        return makeContext(
            direction: .tbRl,
            punctuationMode: punctuationMode,
            renderSize: CGSize(width: 400, height: 16 * CGFloat(charsPerLine))
        )
    }

    //--------------------------------------------------------------//
    // MARK: - 行頭禁則
    //--------------------------------------------------------------//

    /// 行頭禁則文字が行頭に来ないこと。
    func testNotStartingCharacterNeverStartsALine() {
        // 素直に組むと 7 文字目の「、」が 2 行目の頭に来る
        let context = layout("あいうえおか、きくけこ", into: hContext(charsPerLine: 6))
        let texts = lineTexts(context)

        XCTAssertGreaterThan(texts.count, 1, "折り返す前提が崩れた")
        for text in texts.dropFirst() {
            guard let scalar = text.first?.unicodeScalars.first else { continue }
            XCTAssertFalse(
                STKinsoku.notStartingCharSet.contains(scalar),
                "行頭禁則文字 '\(text.first!)' が行頭に来た: \(texts)"
            )
        }
    }

    /// 縦組みでも同じこと。
    func testNotStartingCharacterNeverStartsALineTbRl() {
        let context = layout("あいうえおか、きくけこ", into: vContext(charsPerLine: 6))
        for text in lineTexts(context).dropFirst() {
            guard let scalar = text.first?.unicodeScalars.first else { continue }
            XCTAssertFalse(
                STKinsoku.notStartingCharSet.contains(scalar),
                "縦組みで行頭禁則文字 '\(text.first!)' が行頭に来た"
            )
        }
    }

    /// 行末禁則文字が行末に来ないこと。
    func testNotEndingCharacterNeverEndsALine() {
        // 素直に組むと 6 文字目の「「」が 1 行目の末尾に来る
        let context = layout("あいうえお「かきくけこ」", into: hContext(charsPerLine: 6))
        let texts = lineTexts(context)

        XCTAssertGreaterThan(texts.count, 1, "折り返す前提が崩れた")
        for text in texts.dropLast() {
            guard let scalar = text.last?.unicodeScalars.first else { continue }
            XCTAssertFalse(
                STKinsoku.notEndingCharSet.contains(scalar),
                "行末禁則文字 '\(text.last!)' が行末に来た: \(texts)"
            )
        }
    }

    /// いろいろな禁則文字の組み合わせでも、行頭・行末の禁則が破られないこと。
    ///
    /// 追い出しは行頭（lineStartRunId）まで戻ったところで打ち切る。つまり
    /// 「行まるごとが禁則文字」という行はどこへ送っても解消しないので、
    /// そのときだけ違反を許す（無限ループにするよりはよい）。
    func testKinsokuHoldsAcrossSamples() {
        let texts = [
            "吾輩は猫である。名前はまだ無い。どこで生れたかとんと見当がつかぬ。",
            "「こんにちは」と彼は言った（笑）。それから「さようなら」と続けた。",
            "ちょっと待って！　それは違うよ。ねえ、聞いてる？",
            "アイウエオャュョッーヽヾカキクケコ、サシスセソ。タチツテト",
        ]

        func allScalarsAreIn(_ set: Set<Unicode.Scalar>, _ text: String) -> Bool {
            return text.allSatisfy { char in
                guard let scalar = char.unicodeScalars.first else { return false }
                return set.contains(scalar)
            }
        }

        for direction in STDirection.allCases {
            for charsPerLine in [4, 7, 11] {
                for text in texts {
                    let context = direction == .lrTb
                        ? hContext(charsPerLine: charsPerLine)
                        : vContext(charsPerLine: charsPerLine)
                    layout(text, into: context)

                    let lines = lineTexts(context)
                    let label = "[\(direction)/\(charsPerLine)字] \(lines)"

                    for (index, line) in lines.enumerated() {
                        if index > 0, let scalar = line.first?.unicodeScalars.first,
                           STKinsoku.notStartingCharSet.contains(scalar) {
                            XCTAssertTrue(
                                allScalarsAreIn(STKinsoku.notStartingCharSet, line),
                                "行頭禁則違反（逃げ場のある行なのに追い出していない）: \(label)"
                            )
                        }
                        if index < lines.count - 1, let scalar = line.last?.unicodeScalars.first,
                           STKinsoku.notEndingCharSet.contains(scalar) {
                            XCTAssertTrue(
                                allScalarsAreIn(STKinsoku.notEndingCharSet, line),
                                "行末禁則違反（逃げ場のある行なのに追い出していない）: \(label)"
                            )
                        }
                    }
                    XCTAssertEqual(lines.joined(), text, "禁則処理で文字が失われた: \(label)")
                }
            }
        }
    }

    /// 行まるごとが行頭禁則文字になると、追い出しを諦めて組むこと。
    /// （行頭まで戻っても解消しないので、無限ループにせず打ち切る）
    func testKinsokuGivesUpWhenAWholeLineIsProhibited() {
        let context = layout("アイウエオャュョッーヽヾカキク", into: hContext(charsPerLine: 4))
        let lines = lineTexts(context)

        XCTAssertTrue(lines.contains("ャュョッ"), "禁則文字だけの行ができる前提が崩れた: \(lines)")
        XCTAssertEqual(lines.joined(), "アイウエオャュョッーヽヾカキク", "文字が失われた")
    }

    /// isKinsokuAvailable = false なら禁則が効かず、素直に幅で折り返すこと。
    func testKinsokuCanBeDisabled() {
        let context = hContext(charsPerLine: 6)
        context.isKinsokuAvailable = false
        layout("あいうえおか、きくけこ", into: context)

        XCTAssertEqual(
            lineTexts(context), ["あいうえおか", "、きくけこ"],
            "禁則を切ったのに追い出しが起きている"
        )
    }

    /// 禁則の有無で行分割が実際に変わること（上の 2 つの対比）。
    func testKinsokuChangesLineBreaks() {
        let on = layout("あいうえおか、きくけこ", into: hContext(charsPerLine: 6))
        let off = hContext(charsPerLine: 6)
        off.isKinsokuAvailable = false
        layout("あいうえおか、きくけこ", into: off)

        XCTAssertNotEqual(lineTexts(on), lineTexts(off), "禁則の有無で結果が変わらない")
    }

    //--------------------------------------------------------------//
    // MARK: - ぶら下がり
    //--------------------------------------------------------------//

    /// ぶら下がりは isFixedWidth（字詰め固定）のときだけ働く。
    /// 行末に来た「、」「。」は追い出さず、指定幅の外に出す。
    func testHangingPunctuationInFixedWidth() {
        let charsPerLine = 5
        let context = hContext(charsPerLine: charsPerLine)
        context.isFixedWidth = true
        let originalWidth = context.renderSize.width
        layout("あいうえお、かきく", into: context)

        XCTAssertEqual(
            lineTexts(context), ["あいうえお、", "かきく"],
            "「、」が行末にぶら下がっていない"
        )

        // ぶら下がった「、」は指定幅の外に出る
        let hung = context.runs[5]
        XCTAssertEqual(context.runChars[5], "、")
        XCTAssertEqual(hung.frame.minX, originalWidth, accuracy: 0.001, "「、」が枡目の外に出ていない")

        // ぶら下がったぶん renderSize が広がる（描画がクリップされないように）
        XCTAssertEqual(
            context.renderSize.width, originalWidth + context.fontSize * 0.25, accuracy: 0.001,
            "ぶら下がりぶんの余白が renderSize に足されていない"
        )
    }

    /// ぶら下がり対象でない行頭禁則文字（「」など）は、字詰め固定でもぶら下がらない。
    func testNonHangingPunctuationDoesNotHang() {
        let context = hContext(charsPerLine: 5)
        context.isFixedWidth = true
        layout("あいうえお」かきく", into: context)

        XCTAssertEqual(
            lineTexts(context), ["あいうえお", "」かきく"],
            "ぶら下げ対象でない文字がぶら下がった"
        )
    }

    /// 字詰め固定でないときはぶら下がらず、追い出しで処理されること。
    func testNoHangingWhenNotFixedWidth() {
        let context = hContext(charsPerLine: 5)
        layout("あいうえお、かきく", into: context)

        // 追い出しは「直前のトークンの先頭の 1 つ前」まで戻るので、
        // 「、」だけでなくその前の「お」も次の行へ送られる
        XCTAssertEqual(
            lineTexts(context), ["あいう", "えお、かき", "く"],
            "字詰め固定でないのにぶら下がった"
        )
    }

    //--------------------------------------------------------------//
    // MARK: - 約物モード
    //--------------------------------------------------------------//

    /// 「」「あ。」・ を 3 つのモードで組んだときの、1 文字ごとの枡幅。
    /// 全角 1 文字 = 16pt、半角詰め = 8pt。
    func testPunctuationModeWidths() {
        let text = "」「あ。」・"
        let expected: [STPunctuationMode: [CGFloat]] = [
            // 詰めない
            .whole: [16, 16, 16, 16, 16, 16],
            // 約物はすべて半角に詰める
            .half: [8, 8, 16, 8, 8, 8],
            // 隣り合う約物の組み合わせだけを詰める
            //   」+「 → 後ろの「 を半角に
            //   。+」 → 。を半角に
            //   」+・ → 」を半角に
            //   単独の ・ は全角のまま
            .stone: [16, 8, 16, 8, 8, 16],
        ]

        for (mode, widths) in expected {
            let context = layout(text, into: hContext(charsPerLine: 60, punctuationMode: mode))
            XCTAssertEqual(
                context.runs.map(\.frame.width), widths,
                "約物モード \(mode) の枡幅が違う"
            )
            XCTAssertEqual(
                context.renderedSize.width, widths.reduce(0, +), accuracy: 0.001,
                "約物モード \(mode) の総幅が枡幅の合計と違う"
            )
        }
    }

    /// 縦組みでも同じ詰め方になること（幅ではなく高さで効く）。
    func testPunctuationModeHeightsTbRl() {
        let text = "」「あ。」・"
        let expected: [STPunctuationMode: [CGFloat]] = [
            .whole: [16, 16, 16, 16, 16, 16],
            .half:  [8, 8, 16, 8, 8, 8],
            .stone: [16, 8, 16, 8, 8, 16],
        ]

        for (mode, heights) in expected {
            let context = layout(text, into: vContext(charsPerLine: 60, punctuationMode: mode))
            XCTAssertEqual(
                context.runs.map(\.frame.height), heights,
                "縦組みの約物モード \(mode) の枡高が違う"
            )
        }
    }

    /// 詰めの強さは half < stone < whole の順に総幅が広がること。
    func testPunctuationModeOrdering() {
        let text = "「こんにちは」と、彼は言った。「さようなら」・「またね」。"
        var widths = [STPunctuationMode: CGFloat]()
        for mode in STPunctuationMode.allCases {
            let context = layout(text, into: hContext(charsPerLine: 200, punctuationMode: mode))
            widths[mode] = context.renderedSize.width
        }

        XCTAssertLessThan(widths[.half]!, widths[.stone]!, "half が stone より広い")
        XCTAssertLessThan(widths[.stone]!, widths[.whole]!, "stone が whole より広い")
    }

    /// 行頭に来た開き括弧は、その行ぜんたいを半角ぶん左へ寄せて枡目に載せること（stone モード）。
    func testOpeningBracketAtLineStartIsPulledBack() {
        // 「 は 7 文字目なので 2 行目の頭に来る。
        // 詰めは行を組み終えたときに掛かるので、最終行では効かない。
        // ここでは 2 行目が最終行にならない長さにしてある。
        let context = layout("あいうえおか「きくけこさしすせそ", into: hContext(charsPerLine: 6))
        let texts = lineTexts(context)

        XCTAssertEqual(texts.first, "あいうえおか", "1 行目が 6 文字になっていない")
        XCTAssertEqual(context.runChars[6], "「")
        XCTAssertEqual(context.runs[6].line, 1, "「 が 2 行目の頭に来ていない")
        XCTAssertGreaterThan(context.lineCount, 2, "2 行目が最終行になってしまった")

        XCTAssertEqual(context.runs[6].frame.width, 8, accuracy: 0.001, "行頭の「 が半角に詰まっていない")
        XCTAssertEqual(context.runs[6].frame.minX, 0, accuracy: 0.001, "行頭の「 が左端にない")
        XCTAssertEqual(context.runs[7].frame.minX, 8, accuracy: 0.001, "「 の次の文字が半角ぶん左に寄っていない")
    }

    /// 行頭の開き括弧の詰めは、行を組み終えたときに掛かる。
    /// 最終行はそこに到達しないので詰まらない。
    func testOpeningBracketOnLastLineIsNotPulledBack() {
        let context = layout("あいうえおか「きくけこ", into: hContext(charsPerLine: 6))

        XCTAssertEqual(context.runChars[6], "「")
        XCTAssertEqual(context.runs[6].line, 1, "「 が 2 行目の頭に来ていない")
        XCTAssertEqual(context.lineCount, 2, "2 行目が最終行である前提が崩れた")
        XCTAssertEqual(
            context.runs[6].frame.width, 16, accuracy: 0.001,
            "最終行の行頭の「 が詰まった。詰めるようにしたならこのテストを見直すこと"
        )
    }

    /// 行頭の開き括弧が、二重に詰められないこと。
    ///
    /// stone モードには「隣り合う約物を詰める」規則と「行頭の開き括弧を詰める」
    /// 規則の 2 つがある。前者が前のランを見るとき、行の最初のランでは
    /// その「前」は 1 つ上の行の末尾で、隣ではない。そこを見ていたため、
    /// 前の行が閉じ括弧で終わって次の行が開き括弧で始まると両方の規則が掛かり、
    /// 行が半角ぶん左へ寄って、指定幅より半角短く終わっていた。
    func testOpeningBracketAtLineStartIsSqueezedOnlyOnce() {
        // 1 行目を『…』で終わらせ、2 行目を『で始める。
        // 行頭の詰めは行を組み終えたときに掛かるので、2 行目が最終行に
        // ならない長さにしてある（testOpeningBracketOnLastLineIsNotPulledBack 参照）
        let context = layout(
            "あいうえおかきく『けこ』『さしすせそたちつてとなにぬねのはひふへほまみむめも",
            into: hContext(charsPerLine: 12)
        )
        let texts = lineTexts(context)

        XCTAssertEqual(texts.first?.last, "』", "1 行目が閉じ括弧で終わる前提が崩れた: \(texts)")
        let lineStart = try? XCTUnwrap(lineRanges(context).dropFirst().first?.lowerBound)
        guard let lineStart else { return }
        XCTAssertEqual(context.runChars[lineStart], "『", "2 行目が開き括弧で始まる前提が崩れた")

        let run = context.runs[lineStart]
        XCTAssertEqual(run.frame.minX, 0, accuracy: 0.001, "行頭の括弧が左端にない")
        XCTAssertEqual(run.frame.width, 8, accuracy: 0.001, "行頭の括弧が半角に詰まっていない")

        // 食い込みは半角ぶんだけ。二重に掛かると全角ぶん（16pt）になる
        XCTAssertEqual(
            run.frame.minX - run.position.x, 8, accuracy: 0.001,
            "行頭の括弧の食い込みが半角ぶんでない（二重に詰められている）"
        )

        // 続くランが半角ぶんの位置から始まること
        XCTAssertEqual(
            context.runs[lineStart + 1].frame.minX, 8, accuracy: 0.001,
            "括弧の次の文字が半角ぶんの位置にない"
        )
    }

    /// 行末に来た句読点は半角に詰まること（stone モード）。
    func testClosingPunctuationAtLineEndIsHalved() {
        let context = layout("あいうえお。かきくけこ", into: hContext(charsPerLine: 6))

        XCTAssertEqual(context.runChars[5], "。")
        XCTAssertEqual(context.runs[5].line, 0, "。が 1 行目の末尾にない")
        XCTAssertEqual(context.runs[5].frame.width, 8, accuracy: 0.001, "行末の。が半角に詰まっていない")
    }
}
