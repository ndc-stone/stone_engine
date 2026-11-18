/*
STScriptTests.swift

STScript（Latin / Japanese / Emoji）の判定を検証する。

`Unicode.Scalar.script` は
  1. Emoji_Presentation=Yes なら無条件に .emoji
  2. それ以外は unicodeCategory を引いて、それを含むスクリプトを返す
という 2 段構え。フォント選択（STFontManager.fontId(char:)）が丸ごとこの
判定に乗っているので、境目の文字を表で固定しておく。
*/

import XCTest
@testable import stone_engine

@MainActor
final class STScriptTests: STEngineTestCase {

    //--------------------------------------------------------------//
    // MARK: - テーブルの整合
    //--------------------------------------------------------------//

    /// 同じカテゴリが 2 つのスクリプトに現れないこと。
    /// 重複すると allCases の順で先に来たスクリプトが勝ち、もう一方は死ぬ。
    func testNoCategoryBelongsToTwoScripts() {
        var owner = [STUnicodeCategory: STScript]()
        for script in STScript.allCases {
            for category in script.unicodeCategories {
                if let other = owner[category] {
                    XCTFail("\(category) が \(other) と \(script) の両方に属している")
                }
                owner[category] = script
            }
        }
    }

    /// 縦組みで時計回りに倒す必要がないスクリプト。
    func testNotNeedsToClockwiseInTbRl() {
        XCTAssertFalse(STScript.latin.notNeedsToClockwiseInTbRl, "ラテンは縦組みで倒す")
        XCTAssertTrue(STScript.japanese.notNeedsToClockwiseInTbRl, "日本語は縦組みで倒さない")
        XCTAssertTrue(STScript.emoji.notNeedsToClockwiseInTbRl, "絵文字は縦組みで倒さない")
    }

    //--------------------------------------------------------------//
    // MARK: - 判定
    //--------------------------------------------------------------//

    func testLatinScalars() {
        for value: UInt32 in [0x0020 /* SPACE */, 0x0023 /* # */, 0x0030 /* 0 */,
                              0x0041 /* A */, 0x007A /* z */, 0x007E /* ~ */] {
            XCTAssertEqual(Unicode.Scalar.u(value).script, .latin, "\(value.hex) が .latin でない")
        }
    }

    func testJapaneseScalars() {
        let values: [UInt32] = [
            0x3000, // 全角スペース
            0x3001, // 、
            0x300C, // 「
            0x3042, // あ
            0x30A2, // ア
            0x30FC, // ー
            0x4E00, // 一
            0x6F22, // 漢
            0xFF21, // Ａ（全角）
            0xFF71, // ｱ（半角カナ）
            0x2192, // →（arrows は japanese 側に入れてある）
            0x2460, // ①
        ]
        for value in values {
            XCTAssertEqual(Unicode.Scalar.u(value).script, .japanese, "\(value.hex) が .japanese でない")
        }
    }

    func testEmojiScalars() {
        let values: [UInt32] = [
            0x1F600, // 😀
            0x1F44D, // 👍
            0x1F1EF, // 🇯
            0x1F004, // 🀄
            0x1F0A1, // 🂡
            0x1F202, // 🈂
            0x1F170, // 🅰
        ]
        for value in values {
            XCTAssertEqual(Unicode.Scalar.u(value).script, .emoji, "\(value.hex) が .emoji でない")
        }
    }

    /// Emoji_Presentation=Yes は所属ブロックを問わず .emoji になること。
    /// 逆に「頼まれたときだけ絵文字」の文字（Emoji=Yes, Emoji_Presentation=No）は
    /// ブロックのスクリプトのまま残ること。
    func testEmojiPresentationOverridesBlock() {
        // U+231A WATCH は Miscellaneous Technical（どのスクリプトにも属さないブロック）
        // だが Emoji_Presentation=Yes なので .emoji
        let watch = Unicode.Scalar.u(0x231A)
        XCTAssertTrue(watch.properties.isEmojiPresentation, "前提が崩れた: U+231A が Emoji_Presentation でない")
        XCTAssertEqual(watch.script, .emoji, "U+231A が .emoji でない")

        // '#' と '0' は Emoji=Yes だが Emoji_Presentation=No。ラテンのまま
        for value: UInt32 in [0x0023, 0x0030] {
            let scalar = Unicode.Scalar.u(value)
            XCTAssertFalse(scalar.properties.isEmojiPresentation, "\(value.hex) が Emoji_Presentation になった")
            XCTAssertEqual(scalar.script, .latin, "\(value.hex) が .latin でない")
        }
    }

    /// どのスクリプトにも属さないブロックは nil になること。
    func testUnmappedScalarsHaveNoScript() {
        let values: [UInt32] = [
            0x00A9, // © Latin-1 Supplement
            0x00E9, // é Latin-1 Supplement
            0x0100, // Ā Latin Extended-A
            0x0391, // Α Greek
            0x0410, // А Cyrillic
            0x05D0, // א Hebrew
            0xAC00, // 가 Hangul Syllables
        ]
        for value in values {
            XCTAssertNil(Unicode.Scalar.u(value).script, "\(value.hex) にスクリプトが付いた")
        }
    }

    //--------------------------------------------------------------//
    // MARK: - フォント割り当て
    //--------------------------------------------------------------//

    /// スクリプト判定がそのままフォント割り当てに反映されること。
    /// （このテストだけシステムフォントの存在に依存する）
    func testFontIdFollowsScript() {
        let context = makeContext()
        let manager = context.fontManager

        let expectations: [(Character, STScript)] = [
            ("A", .latin),
            ("0", .latin),
            ("あ", .japanese),
            ("漢", .japanese),
            ("、", .japanese),
            ("😀", .emoji),
            ("🇯", .emoji),
        ]

        for (char, expected) in expectations {
            let fontId = manager.fontId(char: char)
            XCTAssertEqual(
                manager.script(fontId: fontId), expected,
                "'\(char)' が \(expected) のフォントに割り当たらない（fontName: \(manager.fontName(fontId: fontId))）"
            )
        }
    }

    /// fontId(char:) がキャッシュの有無で結果を変えないこと。
    func testFontIdIsStableAcrossCache() {
        let context = makeContext()
        let manager = context.fontManager

        let chars: [Character] = ["A", "あ", "漢", "😀", "🇯🇵", "👨‍👩‍👧‍👦", "①", "→"]
        let first = chars.map { manager.fontId(char: $0) }
        let second = chars.map { manager.fontId(char: $0) }
        XCTAssertEqual(first, second, "同じ文字で fontId が変わった（キャッシュ経路の不整合）")

        // 設定が変わっていなければ refresh() はキャッシュを捨てない
        manager.refresh()
        let third = chars.map { manager.fontId(char: $0) }
        XCTAssertEqual(first, third, "refresh() 後に fontId が変わった")
    }
}
