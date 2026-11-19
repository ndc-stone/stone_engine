/*
STRubyTests.swift

ルビの記法を読む段を検証する。

STParser は「記法つきの文字列 → 組む文字列 + STRuby 配列 + ランごとの倍率」に
落とす。ここで決まるのは「どこまでが読まれる語で、どこからが読みか」だけで、
それをどう置くかはレイアウトの仕事（スナップショットで固定している）。

いちばん大事なのは、記法として成り立っていない文字列を壊さないこと。
`{` も `|` も普通の文に出る文字なので、閉じ忘れた括弧が以降を飲み込むと、
ルビを使っていないつもりの文章まで変わってしまう。
*/

import XCTest
@testable import stone_engine

@MainActor
final class STRubyTests: STEngineTestCase {

    //--------------------------------------------------------------//
    // MARK: - Helper
    //--------------------------------------------------------------//

    private func makeRubyContext(
        _ notation: STRubyNotation,
        direction: STDirection = .lrTb,
        rubyFontScale: CGFloat = 0.5
    ) -> STContext {
        let context = makeContext(direction: direction)
        context.rubyNotation = notation
        context.rubyFontScale = rubyFontScale

        return context
    }

    /// 組まれた文字列と、「語／読み」の組。
    private func rubyPairs(_ context: STContext) -> [(base: String, reading: String)] {
        return context.rubies.map {
            (
                base: String(context.runChars[$0.rbcRunIdRange]),
                reading: String(context.runChars[$0.rtcRunIdRange])
            )
        }
    }

    private func assertRuby(
        _ text: String,
        _ notation: STRubyNotation,
        plain: String,
        pairs: [(base: String, reading: String)],
        direction: STDirection = .lrTb,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let context = parse(text, into: makeRubyContext(notation, direction: direction))

        XCTAssertEqual(
            runText(context), plain,
            "組まれる文字列が違う [\(text)]", file: file, line: line
        )

        let actual = rubyPairs(context)
        XCTAssertEqual(
            actual.count, pairs.count,
            "ルビの数が違う [\(text)] -> \(actual)", file: file, line: line
        )
        for (index, expected) in pairs.enumerated() where index < actual.count {
            XCTAssertEqual(
                actual[index].base, expected.base,
                "語が違う [\(text)] #\(index)", file: file, line: line
            )
            XCTAssertEqual(
                actual[index].reading, expected.reading,
                "読みが違う [\(text)] #\(index)", file: file, line: line
            )
        }
    }

    /// 記法として成り立っていない文字列は、1 文字も変えずに組まれること。
    private func assertUntouched(
        _ text: String,
        _ notation: STRubyNotation,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertRuby(text, notation, plain: text, pairs: [], file: file, line: line)
    }

    //--------------------------------------------------------------//
    // MARK: - none
    //--------------------------------------------------------------//

    /// 既定では記法を読まない。記法の記号はただの文字として組まれる。
    func testNoneLeavesEverythingAlone() {
        assertUntouched("今日は{晴|は}れ", .none)
        assertUntouched("今日は漢字《かんじ》です", .none)
        assertUntouched("｜漢字《かんじ》", .none)
    }

    //--------------------------------------------------------------//
    // MARK: - braces
    //--------------------------------------------------------------//

    func testBracesGroup() {
        assertRuby(
            "今日は{晴|は}れ", .braces,
            plain: "今日は晴はれ",
            pairs: [(base: "晴", reading: "は")]
        )
    }

    /// 1 文字ずつ読みが付く語。隣り合った組が別々に読まれること。
    func testBracesMonoRuby() {
        assertRuby(
            "{消|しょう}{防|ぼう}{士|し}", .braces,
            plain: "消しょう防ぼう士し",
            pairs: [
                (base: "消", reading: "しょう"),
                (base: "防", reading: "ぼう"),
                (base: "士", reading: "し"),
            ]
        )
    }

    /// 読みが空の組は、語だけが組まれてルビにならない。
    /// 書きかけの印であって、何も乗せるものがない。
    func testBracesEmptyReadingIsPlainText() {
        assertRuby(
            "{漢字|}です", .braces,
            plain: "漢字です",
            pairs: []
        )
    }

    /// 閉じ括弧がない、区切りがない、中に括弧がある、行をまたぐ。
    /// どれも組ではないので、書かれたとおりに組まれる。
    func testBracesMalformedIsLiteral() {
        assertUntouched("設定{を開く", .braces)
        assertUntouched("温度は{25}度", .braces)
        assertUntouched("x = {1, 2} | y", .braces)
        assertUntouched("{|かんじ}", .braces)
        assertUntouched("{漢\n字|かんじ}", .braces)
    }

    /// 外側の括弧は組にならず、内側だけが組になる。
    func testBracesNested() {
        assertRuby(
            "{a{b|c}|d}", .braces,
            plain: "{abc|d}",
            pairs: [(base: "b", reading: "c")]
        )
    }

    /// `\{` は組を始めない括弧。
    func testBracesEscape() {
        assertRuby(
            "\\{漢字|かんじ}", .braces,
            plain: "{漢字|かんじ}",
            pairs: []
        )
    }

    /// 逆斜線そのものは普通の文字のまま。`{` の直前にあるときだけ意味を持つ。
    func testBracesBackslashElsewhereIsLiteral() {
        assertUntouched("C:\\Users\\test", .braces)
    }

    //--------------------------------------------------------------//
    // MARK: - aozora
    //--------------------------------------------------------------//

    /// 語を言わない形。《 の直前の文字と同じ種別を遡る。
    func testAozoraUnmarkedBase() {
        assertRuby(
            "今日は漢字《かんじ》です", .aozora,
            plain: "今日は漢字かんじです",
            pairs: [(base: "漢字", reading: "かんじ")]
        )
    }

    /// 種別が変わるところで止まる。記号は遡らない。
    func testAozoraUnmarkedBaseStopsAtOtherClass() {
        assertRuby(
            "ABC《エービーシー》", .aozora,
            plain: "ABCエービーシー",
            pairs: [(base: "ABC", reading: "エービーシー")]
        )
        assertUntouched("、《かんじ》", .aozora)
    }

    /// 語を言う形。種別の混ざった語はこちらでしか書けない。
    func testAozoraMarkedBase() {
        assertRuby(
            "｜お手上げ《おてあげ》", .aozora,
            plain: "お手上げおてあげ",
            pairs: [(base: "お手上げ", reading: "おてあげ")]
        )
    }

    func testAozoraMonoRuby() {
        assertRuby(
            "消《しょう》防《ぼう》士《し》", .aozora,
            plain: "消しょう防ぼう士し",
            pairs: [
                (base: "消", reading: "しょう"),
                (base: "防", reading: "ぼう"),
                (base: "士", reading: "し"),
            ]
        )
    }

    /// 読みが閉じていなければ組ではない。
    func testAozoraMalformedIsLiteral() {
        assertUntouched("漢字《かんじ", .aozora)
        assertUntouched("｜漢字かんじ", .aozora)
    }

    /// 直前の読みまで遡らない。
    ///
    /// 前の組の読みは、次の組の語にならない。遡れる語が無いので 2 つめは組に
    /// ならず、書かれたとおりに組まれる。読みを語として読み直せば
    /// 「しょう」に「ぼう」が乗るという、誰も書いていないものができる
    func testAozoraUnmarkedBaseDoesNotReachIntoPreviousReading() {
        assertRuby(
            "消《しょう》《ぼう》", .aozora,
            plain: "消しょう《ぼう》",
            pairs: [(base: "消", reading: "しょう")]
        )
    }

    //--------------------------------------------------------------//
    // MARK: - Run
    //--------------------------------------------------------------//

    /// 読みのランだけが小さく、語のランは本文と同じ大きさ。
    func testReadingRunsCarryTheFontScale() {
        let context = parse("今日は{晴|は}れ", into: makeRubyContext(.braces))
        guard let ruby = context.rubies.first else {
            XCTFail("ルビが見つからない")
            return
        }

        for runId in 0 ..< context.runs.count {
            let expected: CGFloat = ruby.rtcRunIdRange.contains(runId) ? 0.5 : 1
            XCTAssertEqual(
                context.runs[runId].fontScale, expected,
                "ランの倍率が違う #\(runId) '\(context.runChars[runId])'"
            )
        }
    }

    /// 倍率は設定できる。
    func testReadingFontScaleIsConfigurable() {
        let context = parse(
            "今日は{晴|は}れ",
            into: makeRubyContext(.braces, rubyFontScale: 0.25)
        )
        guard let ruby = context.rubies.first else {
            XCTFail("ルビが見つからない")
            return
        }

        for runId in ruby.rtcRunIdRange {
            XCTAssertEqual(context.runs[runId].fontScale, 0.25)
        }
    }

    /// 読みの付かない文章では、倍率はどのランも 1 のまま。
    func testPlainTextKeepsEveryRunAtFullSize() {
        let context = parse("今日は晴れ", into: makeRubyContext(.braces))
        XCTAssertTrue(
            context.runs.allSatisfy { $0.fontScale == 1 },
            "ルビの無い文章で倍率が動いている"
        )
    }

    /// 読みは小さく組まれるので、送りも本文より狭い。
    func testReadingAdvanceIsNarrowerThanBase() {
        let context = parse("{晴|晴}", into: makeRubyContext(.braces))
        guard let ruby = context.rubies.first,
              let baseId = ruby.rbcRunIdRange.first,
              let readingId = ruby.rtcRunIdRange.first
        else {
            XCTFail("ルビが見つからない")
            return
        }

        XCTAssertLessThan(
            context.runs[readingId].advance.width,
            context.runs[baseId].advance.width,
            "同じ字なのに読みが本文より狭くない"
        )
    }

    //--------------------------------------------------------------//
    // MARK: - Token
    //--------------------------------------------------------------//

    /// 語と読みは、それぞれまるごと 1 トークン。
    ///
    /// トークンは行を折ってよい位置なので、割れていると読みが語の半分の上に
    /// 乗ってしまう。日本語は 1 文字 1 トークンに割るのが既定なので、
    /// ここをまとめ直さないと必ず割れる。
    func testRubyIsOneTokenEach() {
        for mode in STPunctuationMode.allCases {
            let context = makeRubyContext(.braces)
            context.punctuationMode = mode
            parse("今日は{晴天|せいてん}なり", into: context)

            guard let ruby = context.rubies.first else {
                XCTFail("ルビが見つからない [\(mode)]")
                continue
            }

            let ranges = context.tokens.map { $0.runIdRange }
            XCTAssertTrue(
                ranges.contains(ruby.rbcRunIdRange),
                "語が 1 トークンになっていない [\(mode)] \(ranges)"
            )
            XCTAssertTrue(
                ranges.contains(ruby.rtcRunIdRange),
                "読みが 1 トークンになっていない [\(mode)] \(ranges)"
            )
        }
    }

    /// トークンは隙間なく全ランを覆うこと。まとめ直しで取りこぼさない。
    func testTokensStillCoverEveryRun() {
        let context = parse(
            "{消|しょう}{防|ぼう}{士|し}が走る",
            into: makeRubyContext(.braces)
        )

        var next = 0
        for token in context.tokens {
            XCTAssertEqual(token.runIdRange.lowerBound, next, "トークンに隙間がある")
            next = token.runIdRange.upperBound
        }
        XCTAssertEqual(next, context.runs.count, "末尾までトークンが無い")
    }

    //--------------------------------------------------------------//
    // MARK: - Layout
    //--------------------------------------------------------------//

    /// 横組みでは、読みは語の上に乗る。
    func testReadingSitsAboveBaseLrTb() {
        let context = makeRubyContext(.braces)
        context.lineHeightScale = 1.5
        layout("{晴|は}", into: context)

        guard let ruby = context.rubies.first,
              let baseId = ruby.rbcRunIdRange.first,
              let readingId = ruby.rtcRunIdRange.first
        else {
            XCTFail("ルビが見つからない")
            return
        }

        XCTAssertLessThan(
            context.runs[readingId].frame.minY,
            context.runs[baseId].frame.minY,
            "読みが語の上に来ていない"
        )
    }

    /// 縦組みでは、読みは語の右に出る。
    func testReadingSitsBesideBaseTbRl() {
        let context = makeRubyContext(.braces, direction: .tbRl)
        context.lineHeightScale = 1.5
        layout("{晴|は}", into: context)

        guard let ruby = context.rubies.first,
              let baseId = ruby.rbcRunIdRange.first,
              let readingId = ruby.rtcRunIdRange.first
        else {
            XCTFail("ルビが見つからない")
            return
        }

        XCTAssertGreaterThan(
            context.runs[readingId].frame.minX,
            context.runs[baseId].frame.minX,
            "読みが語の右に来ていない"
        )
    }

    /// 語と読みは同じ行に置かれる。間で行が折れない。
    func testRubyIsNeverBrokenAcrossLines() {
        let context = makeRubyContext(.braces)
        context.lineHeightScale = 1.5
        // 1 行 4 文字ぶんしかない幅に、3 文字ぶんの語を 2 つ置く
        context.renderSize = CGSize(width: 16 * 4, height: 400)
        layout("{晴天|せいてん}{曇天|どんてん}", into: context)

        for ruby in context.rubies {
            let lines = Set(
                (ruby.rbcRunIdRange.lowerBound ..< ruby.rtcRunIdRange.upperBound)
                    .map { context.runs[$0].line }
            )
            XCTAssertEqual(
                lines.count, 1,
                "ルビが行をまたいだ: \(lines.sorted())"
            )
        }
    }
}
