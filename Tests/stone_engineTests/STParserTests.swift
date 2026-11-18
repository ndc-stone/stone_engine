/*
STParserTests.swift

STParser のトークン化とラン生成を検証する。

STParser は「文字列 → STRun 配列 + STToken 配列 + runChars」に落とす段。
STRun は Character を持たず、文字そのものは context.runChars に別配列で
並ぶので、両者の対応が崩れると表示も選択もコピーも一斉に壊れる。
ここでは主にフォントに依存しない性質（対応・個数・フラグ・トークン境界）を
固定し、フォント依存の項目は最小限に絞る。
*/

import XCTest
@testable import stone_engine

@MainActor
final class STParserTests: STEngineTestCase {

    /// 往復・個数の検証に使う代表的な入力。
    private let sampleTexts: [(name: String, text: String)] = [
        ("empty",       ""),
        ("ascii",       "Hello, world!"),
        ("hiragana",    "こんにちは"),
        ("sentence",    "吾輩は猫である。名前はまだ無い。"),
        ("brackets",    "「こんにちは」と彼は言った（笑）。"),
        ("mixed",       "abc あ、い 漢字 123"),
        ("newlines",    "いち\nに\r\nさん\rよん"),
        ("tateChuYoko", "第12章 縦中横"),
        ("emoji",       "あ🇯🇵a😀漢👨‍👩‍👧‍👦"),
        ("keycap",      "1️⃣2️⃣3️⃣"),
        ("skinTone",    "👍🏽ありがとう"),
        ("spacesOnly",  "　  \t "),
        ("newlineOnly", "\n\n\n"),
    ]

    //--------------------------------------------------------------//
    // MARK: - 往復
    //--------------------------------------------------------------//

    /// runChars を連結すると元のテキストに戻ること。
    /// フォントにも CoreText にも依存しない、いちばん強い不変条件。
    func testRunCharsRoundTrip() {
        for mode in STPunctuationMode.allCases {
            for sample in sampleTexts {
                let context = parse(sample.text, into: makeContext(punctuationMode: mode))
                XCTAssertEqual(
                    runText(context), sample.text,
                    "往復に失敗 [\(sample.name) / \(mode)]"
                )
            }
        }
    }

    /// ラン数が書記素クラスタ数と一致すること。
    /// 合成絵文字（国旗・ZWJ・肌色・キーキャップ）が 1 ランに収まることの検証でもある。
    func testRunCountEqualsGraphemeCount() {
        for mode in STPunctuationMode.allCases {
            for sample in sampleTexts {
                let context = parse(sample.text, into: makeContext(punctuationMode: mode))
                XCTAssertEqual(
                    context.runs.count, sample.text.count,
                    "ラン数が書記素クラスタ数と違う [\(sample.name) / \(mode)]"
                )
                XCTAssertEqual(
                    context.runChars.count, context.runs.count,
                    "runChars と runs の長さが違う [\(sample.name) / \(mode)]"
                )
            }
        }
    }

    /// 合成絵文字が 1 ランになること（個別に明示）。
    func testComposedEmojiIsSingleRun() {
        let cases: [(name: String, text: String)] = [
            ("flag",      "🇯🇵"),
            ("zwjFamily", "👨‍👩‍👧‍👦"),
            ("skinTone",  "👍🏽"),
            ("keycap",    "1️⃣"),
            ("heartVS16", "❤️"),
        ]
        for item in cases {
            let context = parse(item.text)
            XCTAssertEqual(context.runs.count, 1, "\(item.name) が 1 ランになっていない")
            XCTAssertEqual(runText(context), item.text, "\(item.name) が壊れた")
        }
    }

    func testEmptyAndNilText() {
        for text: String? in ["", nil] {
            let context = parse(text)
            XCTAssertTrue(context.runs.isEmpty, "空入力でランができた")
            XCTAssertTrue(context.tokens.isEmpty, "空入力でトークンができた")
            XCTAssertTrue(context.runChars.isEmpty, "空入力で runChars ができた")
            XCTAssertEqual(context.lineCount, 0, "空入力で lineCount が 0 でない")
        }
    }

    //--------------------------------------------------------------//
    // MARK: - トークン
    //--------------------------------------------------------------//

    /// トークンの runIdRange が 0 から隙間も重なりもなく全ランを覆うこと。
    func testTokensPartitionAllRuns() {
        for mode in STPunctuationMode.allCases {
            for sample in sampleTexts {
                let context = parse(sample.text, into: makeContext(punctuationMode: mode))

                var cursor = 0
                for (index, token) in context.tokens.enumerated() {
                    XCTAssertEqual(
                        token.runIdRange.lowerBound, cursor,
                        "トークン \(index) の開始が連続していない [\(sample.name) / \(mode)]"
                    )
                    XCTAssertFalse(
                        token.runIdRange.isEmpty,
                        "トークン \(index) が空 [\(sample.name) / \(mode)]"
                    )
                    cursor = token.runIdRange.upperBound
                }
                XCTAssertEqual(
                    cursor, context.runs.count,
                    "トークンが全ランを覆っていない [\(sample.name) / \(mode)]"
                )
            }
        }
    }

    /// 各ランの tokenId / tokenRunIndex がトークン側と整合すること。
    func testRunTokenBackReferences() {
        for sample in sampleTexts {
            let context = parse(sample.text)
            for (runId, run) in context.runs.enumerated() {
                XCTAssertTrue(
                    context.tokens.indices.contains(run.tokenId),
                    "range 外の tokenId [\(sample.name)] runId=\(runId)"
                )
                let range = context.tokens[run.tokenId].runIdRange
                XCTAssertTrue(
                    range.contains(runId),
                    "run が自分の tokenId のトークンに含まれない [\(sample.name)] runId=\(runId)"
                )
                XCTAssertEqual(
                    run.tokenRunIndex, runId - range.lowerBound,
                    "tokenRunIndex がずれている [\(sample.name)] runId=\(runId)"
                )
                XCTAssertEqual(
                    context.isLastInToken(run: run), runId == range.upperBound - 1,
                    "isLastInToken が合わない [\(sample.name)] runId=\(runId)"
                )
            }
        }
    }

    /// .stone モードのトークン化: 英数字は 1 トークンにまとまり、
    /// 空白・日本語・約物はそれぞれ 1 文字 1 トークンになること。
    func testStoneTokenizerGroupsAlphanumerics() {
        let context = parse("abc あ、い", into: makeContext(punctuationMode: .stone))

        let tokenTexts = context.tokens.map { token in
            String(context.runChars[token.runIdRange])
        }
        XCTAssertEqual(tokenTexts, ["abc", " ", "あ", "、", "い"], "トークン境界が期待と違う")
    }

    /// 数字の連なりも .stone モードでは 1 トークンになること（縦中横の判定単位）。
    func testStoneTokenizerGroupsDigits() {
        let context = parse("第12章", into: makeContext(punctuationMode: .stone))

        let tokenTexts = context.tokens.map { token in
            String(context.runChars[token.runIdRange])
        }
        XCTAssertEqual(tokenTexts, ["第", "12", "章"], "数字がひとかたまりになっていない")
    }

    //--------------------------------------------------------------//
    // MARK: - ランのフラグ
    //--------------------------------------------------------------//

    func testNewlineFlagAndAdvance() {
        let text = "あ\nい\r\nう\rえ"
        let context = parse(text)

        let expectedNewline = Array(text).map(\.isNewline)
        let actualNewline = context.runs.map(\.isNewline)
        XCTAssertEqual(actualNewline, expectedNewline, "改行フラグの位置が違う")

        for (runId, run) in context.runs.enumerated() where run.isNewline {
            XCTAssertEqual(run.advance, .zero, "改行の advance が 0 でない runId=\(runId)")
        }
        XCTAssertEqual(context.runs.filter(\.isNewline).count, 3, "改行が 3 つでない（\\r\\n が 2 つに割れた?）")
    }

    func testNumberFlag() {
        let context = parse("a1あ2３")
        let expected = [false, true, false, true, true]   // ３ は全角数字
        XCTAssertEqual(
            context.runs.map { $0.flags.contains(.number) }, expected,
            "数字フラグの位置が違う"
        )
    }

    func testKinsokuFlags() {
        let context = parse("「あ、」")

        let notEnding = context.runs.map { $0.flags.contains(.notEnding) }
        let notStarting = context.runs.map { $0.flags.contains(.notStarting) }
        let hanging = context.runs.map { $0.flags.contains(.hanging) }

        XCTAssertEqual(notEnding,   [true,  false, false, false], "行末禁則フラグの位置が違う")
        XCTAssertEqual(notStarting, [false, false, true,  true ], "行頭禁則フラグの位置が違う")
        XCTAssertEqual(hanging,     [false, false, true,  false], "ぶら下げフラグの位置が違う")
    }

    func testPunctuationClassPerRun() {
        let context = parse("「あ、」・")
        XCTAssertEqual(
            context.runs.map(\.punctuation),
            [.secondHalf, .whole, .firstHalf, .firstHalf, .quarter],
            "ランごとの約物分類が違う"
        )
    }

    /// run.scalar が文字の先頭スカラーと一致すること（グリフキャッシュのキー）。
    func testRunScalarMatchesCharacter() {
        for sample in sampleTexts {
            let context = parse(sample.text)
            for (runId, run) in context.runs.enumerated() {
                let expected = context.runChars[runId].unicodeScalars.first?.value ?? 0
                XCTAssertEqual(
                    run.scalar, expected,
                    "scalar が文字と一致しない [\(sample.name)] runId=\(runId)"
                )
            }
        }
    }

    /// パース直後は位置がまだ決まっていないこと（レイアウトはこの後の段）。
    func testGeometryIsUnsetBeforeLayout() {
        let context = parse("あいうえお")
        for (runId, run) in context.runs.enumerated() {
            XCTAssertEqual(run.position, .zero, "パース直後に position が入っている runId=\(runId)")
            XCTAssertEqual(run.frame, .zero, "パース直後に frame が入っている runId=\(runId)")
            XCTAssertEqual(run.line, 0, "パース直後に line が入っている runId=\(runId)")
            XCTAssertEqual(run.visibility, .visible, "パース直後の visibility が .visible でない runId=\(runId)")
        }
        XCTAssertEqual(context.lineCount, 0, "パース直後に lineCount が入っている")
    }

    //--------------------------------------------------------------//
    // MARK: - グリフ（フォント依存）
    //--------------------------------------------------------------//

    /// 改行以外のランにグリフと送りが入っていること。
    func testVisibleRunsHaveGlyphAndAdvance() {
        let context = parse("あA漢1、😀")
        for (runId, run) in context.runs.enumerated() {
            let char = context.runChars[runId]
            XCTAssertNotEqual(run.glyph, 0, "'\(char)' が .notdef グリフ")
            XCTAssertGreaterThan(run.advance.width, 0, "'\(char)' の送りが 0")
        }
    }

    /// 改行はその直前の文字のフォントを引き継ぐこと。
    func testNewlineInheritsPreviousFont() {
        let context = parse("あ\nA\n")
        let manager = context.fontManager

        XCTAssertEqual(context.runs.count, 4)
        XCTAssertEqual(
            manager.script(fontId: context.runs[1].fontId), manager.script(fontId: context.runs[0].fontId),
            "「あ」の後の改行が別スクリプトのフォントになっている"
        )
        XCTAssertEqual(
            manager.script(fontId: context.runs[3].fontId), manager.script(fontId: context.runs[2].fontId),
            "「A」の後の改行が別スクリプトのフォントになっている"
        )
    }

    /// 同じテキストを 2 回パースしても同じ結果になること（キャッシュ経路の再現性）。
    func testParsingIsDeterministic() {
        let text = "あ🇯🇵a😀漢、「テスト」123\n第12章"
        let a = parse(text)
        let b = parse(text)

        XCTAssertEqual(a.runs.count, b.runs.count)
        for runId in 0 ..< min(a.runs.count, b.runs.count) {
            XCTAssertEqual(a.runs[runId].glyph, b.runs[runId].glyph, "glyph が 2 回目で変わった runId=\(runId)")
            XCTAssertEqual(a.runs[runId].fontId, b.runs[runId].fontId, "fontId が 2 回目で変わった runId=\(runId)")
            XCTAssertEqual(a.runs[runId].advance, b.runs[runId].advance, "advance が 2 回目で変わった runId=\(runId)")
        }
    }

    /// 同じ context を使い回して別テキストをパースしても状態が残らないこと。
    func testReparseReplacesPreviousState() {
        let context = makeContext()
        parse("最初のテキストです", into: context)
        let firstCount = context.runs.count

        parse("短い", into: context)
        XCTAssertEqual(context.runs.count, 2, "再パースで前のランが残っている（前回 \(firstCount) 個）")
        XCTAssertEqual(runText(context), "短い", "再パースで runChars が残っている")
        XCTAssertEqual(context.tokens.count, 2, "再パースで前のトークンが残っている")
    }
}
