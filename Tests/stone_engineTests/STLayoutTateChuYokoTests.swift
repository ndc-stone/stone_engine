/*
STLayoutTateChuYokoTests.swift

縦中横（縦組みの中の横並び数字）と、縦組みでの字送りの向きの検証。

縦中横の条件は STContext.isTateChuYoko(run:) に集約されている:
  - 縦組みであること
  - 字詰め固定（isFixedWidth）でなく、isAllowedTateChuYoko であること
  - そのランのスクリプトが縦組みで倒す側（= ラテン）であること
  - トークンが数字だけで構成され、かつ 2 文字以内であること
条件から外れたラテン文字は時計回りに倒される（isClockwise）。
*/

import XCTest
@testable import stone_engine

@MainActor
final class STLayoutTateChuYokoTests: STEngineTestCase {

    private func vContext(charsPerLine: Int = 20) -> STContext {
        return makeContext(direction: .tbRl, renderSize: CGSize(width: 400, height: 16 * CGFloat(charsPerLine)))
    }

    /// トークンの文字列から、そのトークンを引く。
    private func token(_ context: STContext, text: String) -> (id: Int, range: Range<Int>)? {
        for (id, token) in context.tokens.enumerated() {
            if String(context.runChars[token.runIdRange]) == text { return (id, token.runIdRange) }
        }
        return nil
    }

    //--------------------------------------------------------------//
    // MARK: - 判定
    //--------------------------------------------------------------//

    /// 1〜2 桁の数字トークンだけが縦中横になること。
    func testOnlyOneOrTwoDigitTokensAreTateChuYoko() {
        let context = layout("第1章 第12章 第345章 第AB章", into: vContext())

        let expectations: [(text: String, isTcy: Bool)] = [
            ("1", true),      // 1 桁
            ("12", true),     // 2 桁
            ("345", false),   // 3 桁は対象外
            ("AB", false),    // 数字でない
            ("第", false),    // 日本語は倒さないので対象外
        ]
        for expectation in expectations {
            guard let token = token(context, text: expectation.text) else {
                XCTFail("トークン '\(expectation.text)' が見つからない: \(context.tokens.map { String(context.runChars[$0.runIdRange]) })")
                continue
            }
            XCTAssertEqual(
                context.isTateChuYoko(token: context.tokens[token.id]), expectation.isTcy,
                "'\(expectation.text)' の縦中横判定が違う"
            )
        }
    }

    /// 横組みでは縦中横にならないこと。
    func testNoTateChuYokoInLrTb() {
        let context = layout("第12章", into: makeContext(renderSize: CGSize(width: 400, height: 100)))
        for token in context.tokens {
            XCTAssertFalse(context.isTateChuYoko(token: token), "横組みで縦中横になった")
        }
    }

    /// isAllowedTateChuYoko = false で無効になること。
    func testTateChuYokoCanBeDisabled() {
        let context = vContext()
        context.isAllowedTateChuYoko = false
        layout("第12章", into: context)

        for token in context.tokens {
            XCTAssertFalse(context.isTateChuYoko(token: token), "無効にしたのに縦中横になった")
        }
    }

    /// 字詰め固定でも無効になること。
    func testNoTateChuYokoInFixedWidth() {
        let context = vContext()
        context.isFixedWidth = true
        layout("第12章", into: context)

        for token in context.tokens {
            XCTAssertFalse(context.isTateChuYoko(token: token), "字詰め固定なのに縦中横になった")
        }
    }

    //--------------------------------------------------------------//
    // MARK: - 配置
    //--------------------------------------------------------------//

    /// 縦中横の 2 桁は、1 文字ぶんの枡に横並びで収まること。
    func testTwoDigitsFitInOneCharacterCell() {
        let context = layout("第12章", into: vContext())

        guard let digits = token(context, text: "12") else { return XCTFail("トークン '12' が見つからない") }
        let one = context.runs[digits.range.lowerBound]
        let two = context.runs[digits.range.lowerBound + 1]

        // 同じ枡（= 同じ y）に載り、横に並ぶ
        XCTAssertEqual(one.frame.minY, two.frame.minY, accuracy: 0.001, "2 桁が縦に積まれている")
        XCTAssertGreaterThan(two.frame.minX, one.frame.minX, "2 桁が横に並んでいない")

        // 枡の高さは 1 文字ぶん
        XCTAssertEqual(one.frame.height, context.adjustFontSize, accuracy: 0.001, "縦中横の枡が 1 文字ぶんでない")
        XCTAssertEqual(two.frame.height, context.adjustFontSize, accuracy: 0.001, "縦中横の枡が 1 文字ぶんでない")

        // 前後の文字は 1 文字ぶんだけ送られる
        let before = context.runs[digits.range.lowerBound - 1]   // 第
        let after = context.runs[digits.range.upperBound]        // 章
        XCTAssertEqual(one.frame.minY, before.frame.maxY, accuracy: 0.001, "縦中横の前に隙間がある")
        XCTAssertEqual(after.frame.minY, one.frame.maxY, accuracy: 0.001, "縦中横が 1 文字ぶんを超えて送られている")
    }

    /// 縦中横は行の中央に寄せられること。
    func testTateChuYokoIsCenteredInTheLine() {
        let context = layout("第12章", into: vContext())

        guard let digits = token(context, text: "12") else { return XCTFail("トークン '12' が見つからない") }
        let one = context.runs[digits.range.lowerBound]
        let two = context.runs[digits.range.lowerBound + 1]
        let kanji = context.runs[digits.range.lowerBound - 1]

        let digitsCenter = (one.frame.minX + two.frame.maxX) * 0.5
        XCTAssertEqual(
            digitsCenter, kanji.frame.midX, accuracy: 0.5,
            "縦中横が行の中央に寄っていない"
        )
    }

    /// 縦中横にならない数字（3 桁）は 1 文字ずつ倒され、縦に積まれること。
    func testThreeDigitsAreRotatedAndStacked() {
        let context = layout("第345章", into: vContext())

        guard let digits = token(context, text: "345") else { return XCTFail("トークン '345' が見つからない") }
        let runs = digits.range.map { context.runs[$0] }

        for run in runs {
            XCTAssertTrue(context.isClockwise(run: run), "3 桁の数字が倒されていない")
            // 倒されたランの枡幅は 1 文字ぶん、高さは元の送り
            XCTAssertEqual(run.frame.width, context.adjustFontSize, accuracy: 0.001, "倒したランの枡幅が 1 文字ぶんでない")
            XCTAssertEqual(run.frame.height, run.advance.width, accuracy: 0.001, "倒したランの高さが元の送りと違う")
        }

        // 縦に積まれる
        for index in 1 ..< runs.count {
            XCTAssertEqual(
                runs[index].frame.minY, runs[index - 1].frame.maxY, accuracy: 0.001,
                "倒した数字が縦に連なっていない"
            )
            XCTAssertEqual(runs[index].frame.minX, runs[0].frame.minX, accuracy: 0.001, "倒した数字の x が揃っていない")
        }
    }

    //--------------------------------------------------------------//
    // MARK: - 倒す / 倒さない
    //--------------------------------------------------------------//

    /// 縦組みで倒すのはラテンだけ。日本語と絵文字は倒さない。
    func testOnlyLatinIsRotatedInTbRl() {
        let context = layout("あA漢😀、", into: vContext())

        let expectations: [(Character, Bool)] = [
            ("あ", false),
            ("A", true),
            ("漢", false),
            ("😀", false),
            ("、", false),
        ]
        for (index, expectation) in expectations.enumerated() {
            XCTAssertEqual(context.runChars[index], expectation.0, "前提のラン並びが崩れた")
            XCTAssertEqual(
                context.isClockwise(run: context.runs[index]), expectation.1,
                "'\(expectation.0)' の回転判定が違う"
            )
        }
    }

    /// 横組みでは何も倒さないこと。
    func testNothingIsRotatedInLrTb() {
        let context = layout("あA漢😀", into: makeContext(renderSize: CGSize(width: 400, height: 100)))
        for run in context.runs {
            XCTAssertFalse(context.isClockwise(run: run), "横組みで回転している")
        }
    }

    //--------------------------------------------------------------//
    // MARK: - 行分割
    //--------------------------------------------------------------//

    /// 縦中横のトークンは途中で行をまたがないこと。
    func testTateChuYokoDoesNotSplitAcrossLines() {
        // 1 行 4 文字。第・1・2 と進むと 4 文字目の枡に縦中横が来る配置
        for charsPerLine in 3 ... 6 {
            let context = layout("あいうえお第12章かきくけこ", into: vContext(charsPerLine: charsPerLine))
            guard let digits = token(context, text: "12") else {
                XCTFail("トークン '12' が見つからない（\(charsPerLine) 文字/行）")
                continue
            }
            let lines = Set(digits.range.map { context.runs[$0].line })
            XCTAssertEqual(lines.count, 1, "縦中横が行をまたいだ（\(charsPerLine) 文字/行）")
        }
    }
}
