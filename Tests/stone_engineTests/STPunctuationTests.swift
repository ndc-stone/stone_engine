/*
STPunctuationTests.swift

約物分類（STPunctuation）と禁則文字集合（STKinsoku）の検証。

どちらも定数テーブルで、レイアウトの詰め幅・追い出し・ぶら下がりが全部
ここに乗っている。集合そのものの整合と、代表文字の分類を固定しておく。
*/

import XCTest
@testable import stone_engine

@MainActor
final class STPunctuationTests: STEngineTestCase {

    //--------------------------------------------------------------//
    // MARK: - STPunctuation
    //--------------------------------------------------------------//

    /// 3 つの約物集合が互いに素であること。
    /// 重なると valueOf の if-else 順で先勝ちになり、詰め方が静かに変わる。
    func testPunctuationSetsAreDisjoint() {
        let first = STPunctuation.firstHalfPunctuationCharSet
        let second = STPunctuation.secondHalfPunctuationCharSet
        let quarter = STPunctuation.quarterPunctuationCharSet

        XCTAssertTrue(first.intersection(second).isEmpty, "行頭約物と行末約物が重なっている")
        XCTAssertTrue(first.intersection(quarter).isEmpty, "行頭約物と 1/4 約物が重なっている")
        XCTAssertTrue(second.intersection(quarter).isEmpty, "行末約物と 1/4 約物が重なっている")
    }

    /// 開き括弧と閉じ括弧が対応して登録されていること。
    func testBracketPairsAreRegisteredOnBothSides() {
        let pairs: [(open: Character, close: Character)] = [
            ("（", "）"), ("［", "］"), ("｛", "｝"), ("〔", "〕"),
            ("〈", "〉"), ("《", "》"), ("「", "」"), ("『", "』"),
            ("【", "】"), ("〘", "〙"), ("〖", "〗"), ("〝", "〟"),
            ("｟", "｠"),
        ]
        for pair in pairs {
            XCTAssertEqual(
                STPunctuation.valueOf(charatcter: pair.open), .secondHalf,
                "開き括弧 '\(pair.open)' が後ろ半分（secondHalf）でない"
            )
            XCTAssertEqual(
                STPunctuation.valueOf(charatcter: pair.close), .firstHalf,
                "閉じ括弧 '\(pair.close)' が前半分（firstHalf）でない"
            )
        }
    }

    func testValueOfRepresentativeCharacters() {
        let expectations: [(Character, STPunctuation)] = [
            ("、", .firstHalf),
            ("。", .firstHalf),
            ("」", .firstHalf),
            ("「", .secondHalf),
            ("（", .secondHalf),
            ("・", .quarter),
            ("：", .quarter),
            ("；", .quarter),
            ("あ", .whole),
            ("漢", .whole),
            ("A", .whole),
            ("　", .whole),   // 全角スペース
            ("ー", .whole),
            ("😀", .whole),
        ]
        for (char, expected) in expectations {
            XCTAssertEqual(
                STPunctuation.valueOf(charatcter: char), expected,
                "'\(char)' の約物分類が期待と違う"
            )
        }
    }

    //--------------------------------------------------------------//
    // MARK: - STKinsoku
    //--------------------------------------------------------------//

    /// 行頭禁則と行末禁則が重なっていないこと。
    /// 同じ文字が両方に入ると、追い出し先がなくなってレイアウトが詰む。
    func testKinsokuSetsAreDisjoint() {
        let both = STKinsoku.notStartingCharSet.intersection(STKinsoku.notEndingCharSet)
        XCTAssertTrue(
            both.isEmpty,
            "行頭禁則と行末禁則の両方に入っている文字がある: \(both.map { String($0) }.sorted())"
        )
    }

    /// ぶら下げ対象は必ず行頭禁則でもあること（行頭に置けないからぶら下げる）。
    func testHangingCharactersAreAlsoNotStarting() {
        for scalar in STKinsoku.hangingCharSet {
            XCTAssertTrue(
                STKinsoku.notStartingCharSet.contains(scalar),
                "ぶら下げ対象 '\(scalar)' が行頭禁則に入っていない"
            )
        }
    }

    func testNotStartingCharacters() {
        let chars: [Character] = [
            "、", "。", "」", "』", "）", "]", "｝",
            "ゃ", "ッ", "ヽ", "々", "〻",
            "？", "！", "：", "；", "!", "‼", "⁉", "™", " ",
        ]
        for char in chars {
            guard let scalar = char.unicodeScalars.first else { continue }
            XCTAssertTrue(
                STKinsoku.notStartingCharSet.contains(scalar),
                "'\(char)' が行頭禁則に入っていない"
            )
        }
    }

    /// 全角と半角の約物が揃って行頭禁則に入っていること。
    /// 全角側（！：；）だけ抜けていて、半角側だけ入っている状態が長く続いていた。
    func testFullwidthAndHalfwidthPunctuationBothKinsoku() {
        let pairs: [(fullwidth: Character, halfwidth: Character)] = [
            ("！", "!"), ("：", ":"), ("；", ";"), ("？", "?"),
        ]
        for pair in pairs {
            guard let full = pair.fullwidth.unicodeScalars.first,
                  let half = pair.halfwidth.unicodeScalars.first else { continue }
            XCTAssertTrue(
                STKinsoku.notStartingCharSet.contains(full),
                "全角 '\(pair.fullwidth)' が行頭禁則に入っていない"
            )
            XCTAssertTrue(
                STKinsoku.notStartingCharSet.contains(half),
                "半角 '\(pair.halfwidth)' が行頭禁則に入っていない"
            )
        }
    }

    func testNotEndingCharacters() {
        for char: Character in ["「", "『", "（", "［", "【", "〈", "《", "\"", "'"] {
            guard let scalar = char.unicodeScalars.first else { continue }
            XCTAssertTrue(
                STKinsoku.notEndingCharSet.contains(scalar),
                "'\(char)' が行末禁則に入っていない"
            )
        }
    }

    func testOrdinaryCharactersAreNotKinsoku() {
        for char: Character in ["あ", "漢", "A", "0", "ア", "　"] {
            guard let scalar = char.unicodeScalars.first else { continue }
            XCTAssertFalse(STKinsoku.notStartingCharSet.contains(scalar), "'\(char)' が行頭禁則に入っている")
            XCTAssertFalse(STKinsoku.notEndingCharSet.contains(scalar), "'\(char)' が行末禁則に入っている")
            XCTAssertFalse(STKinsoku.hangingCharSet.contains(scalar), "'\(char)' がぶら下げ対象に入っている")
        }
    }

    /// ぶら下げ対象は現状「、」と「。」の 2 つだけ。
    func testHangingCharSetContents() {
        XCTAssertEqual(
            Set(STKinsoku.hangingCharSet.map { String($0) }), ["、", "。"],
            "ぶら下げ対象の顔ぶれが変わった"
        )
    }
}
