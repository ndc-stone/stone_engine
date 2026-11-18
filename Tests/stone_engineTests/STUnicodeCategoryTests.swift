/*
STUnicodeCategoryTests.swift

STUnicodeCategory.range のテーブル検証。

STUnicodeCategory は「Unicode ブロックの表」であり、Unicode 標準という
外部の正解が存在する純粋データ。フォントにも CoreText にも依存しないので、
テーブル全体を走査する不変条件テストが最も安く効く。

`Unicode.Scalar.unicodeCategory` は `allCases.first { $0.range.contains(value) }`
で引くため、allCases の順（= 宣言順）が先勝ちになる。したがって
「範囲が重なっている」ことと「引いた結果が誤る」ことは別問題であり、
両方を別々に検証する。
*/

import XCTest
@testable import stone_engine

@MainActor
final class STUnicodeCategoryTests: STEngineTestCase {

    /// 宣言順（= allCases の順）のまま保持した全ケース。
    private let categories = STUnicodeCategory.allCases

    private func name(_ category: STUnicodeCategory) -> String {
        return String(describing: category)
    }

    //--------------------------------------------------------------//
    // MARK: - Range の形
    //--------------------------------------------------------------//

    /// すべての範囲が空でなく、Unicode のスカラー値空間に収まっていること。
    func testEveryRangeIsWellFormed() {
        for category in categories {
            let range = category.range
            XCTAssertLessThan(
                range.lowerBound, range.upperBound,
                "\(name(category)) の範囲が空: \(range.lowerBound.hex)..<\(range.upperBound.hex)"
            )
            XCTAssertLessThanOrEqual(
                range.upperBound, 0x110000,
                "\(name(category)) の上限が Unicode の範囲外: \(range.upperBound.hex)"
            )
        }
    }

    /// 同じ範囲を持つケースが重複していないこと。
    func testNoDuplicatedRanges() {
        var seen = [Range<UInt32>: STUnicodeCategory]()
        for category in categories {
            if let other = seen[category.range] {
                XCTFail("\(name(category)) と \(name(other)) が同一の範囲を持つ")
            }
            seen[category.range] = category
        }
    }

    //--------------------------------------------------------------//
    // MARK: - 重なり
    //--------------------------------------------------------------//

    /// どの範囲も重なっていないこと。
    ///
    /// `Unicode.Scalar.unicodeCategory` は allCases.first {} で引くので、
    /// 重なりがあっても宣言順の先勝ちで「たまたま正しく」見えてしまう。
    /// case を並べ替えた瞬間に誤分類 → フォント選択の誤りとして表に出るため、
    /// 引き当て結果ではなくデータそのものを検証する。
    func testRangesDoNotOverlap() {
        var overlaps = Set<String>()
        for i in 0 ..< categories.count {
            for j in (i + 1) ..< categories.count {
                let a = categories[i], b = categories[j]
                guard a.range.overlaps(b.range) else { continue }
                // 宣言順の早い方を先に書く
                overlaps.insert("\(name(a))/\(name(b))")
            }
        }

        XCTAssertEqual(
            overlaps, [],
            "範囲が重なっている。宣言順に依存しないと正しく引けなくなる"
        )
    }

    /// 隣接ブロックの境目が Unicode 標準どおりに切れていること。
    /// かつて Runic / Khmer Symbols の始点が誤っていて隣と重なっていた箇所。
    func testAdjacentBlockBoundaries() {
        let expectations: [(UInt32, STUnicodeCategory)] = [
            (0x1680, .ogham),           // Ogham の先頭
            (0x169F, .ogham),           // Ogham の末尾
            (0x16A0, .runic),           // Runic の先頭
            (0x16FF, .runic),           // Runic の末尾
            (0x1980, .newTaiLue),       // New Tai Lue の先頭
            (0x19DF, .newTaiLue),       // New Tai Lue の末尾
            (0x19E0, .khmerSymbols),    // Khmer Symbols の先頭
            (0x19FF, .khmerSymbols),    // Khmer Symbols の末尾
            (0x009F, .c1Control),       // C1 制御文字の末尾
            (0x00A0, .latin1Supplement),// Latin-1 Supplement の先頭
            (0x097F, .devanagari),      // Devanagari の末尾
            (0x0980, .bengali),         // Bengali の先頭
            (0x09FF, .bengali),         // Bengali の末尾
            (0x0A00, .gurmukhi),        // Gurmukhi の先頭
        ]

        for (value, expected) in expectations {
            XCTAssertEqual(
                Unicode.Scalar.u(value).unicodeCategory, expected,
                "\(value.hex) が \(name(expected)) に分類されない"
            )
        }
    }

    //--------------------------------------------------------------//
    // MARK: - 穴
    //--------------------------------------------------------------//

    /// テーブルの穴（どのケースにも属さない区間）が、既知の一覧と完全に一致すること。
    ///
    /// 穴に落ちたスカラーは unicodeCategory が nil になり、script も nil になって
    /// フォント検索がフォールバック経路に落ちる。
    func testGapsMatchKnownList() {
        // "下限..<上限"（下限は含む、上限は含まない）
        let knownGaps: Set<String> = [
            // 意図的: Unicode 上も未割り当て（Kangxi Radicals と IDC の間）
            "U+2FE0..<U+2FF0",
            // 意図的: BMP 外は絵文字系ブロックのみを対象にしている
            "U+10000..<U+1F000",
            // 意図的: Symbols for Legacy Computing の後ろは対象外
            "U+1FC00..<U+1FF80",
        ]

        let sorted = categories.map(\.range).sorted { ($0.lowerBound, $0.upperBound) < ($1.lowerBound, $1.upperBound) }

        // 重なりを潰して被覆区間にまとめる
        var covered = [Range<UInt32>]()
        for range in sorted {
            if let last = covered.last, range.lowerBound <= last.upperBound {
                covered[covered.count - 1] = last.lowerBound ..< max(last.upperBound, range.upperBound)
            }
            else {
                covered.append(range)
            }
        }

        var gaps = Set<String>()
        var cursor: UInt32 = 0
        for range in covered {
            if range.lowerBound > cursor {
                gaps.insert("\(cursor.hex)..<\(range.lowerBound.hex)")
            }
            cursor = max(cursor, range.upperBound)
        }

        XCTAssertEqual(
            gaps, knownGaps,
            "テーブルの穴が既知の一覧と異なる。新たな穴を作ったか、既知の分を埋めたかのどちらか"
        )
        XCTAssertEqual(cursor, 0x20000, "テーブルの被覆上限が U+20000 でない")
    }

    //--------------------------------------------------------------//
    // MARK: - 引き当て
    //--------------------------------------------------------------//

    /// 代表的なスカラーが期待どおりのカテゴリに引き当たること。
    func testRepresentativeScalars() {
        let expectations: [(UInt32, STUnicodeCategory)] = [
            (0x0000, .c0Control),
            (0x000A, .c0Control),                       // LF
            (0x0020, .basicLatin),                      // SPACE
            (0x0041, .basicLatin),                      // 'A'
            (0x0030, .basicLatin),                      // '0'
            (0x009F, .c1Control),                       // APC（C1 の末尾）
            (0x00A9, .latin1Supplement),                // '©'
            (0x0985, .bengali),                         // 'অ'
            (0x2192, .arrows),                          // '→'
            (0x2460, .enclosedAlphanumerics),           // '①'
            (0x2764, .dingbats),                        // '❤'（Dingbats。Misc Symbols は U+2600..<U+2700）
            (0x2600, .miscellaneousSymbols),            // '☀'
            (0x3001, .cjkSymbolsAndPunctuation),        // '、'
            (0x3042, .hiragana),                        // 'あ'
            (0x30A2, .katakana),                        // 'ア'
            (0x4E00, .cjkUnifiedIdeographs),            // '一'
            (0x6F22, .cjkUnifiedIdeographs),            // '漢'
            (0xFF71, .halfwidthAndFullwidthForms),      // 'ｱ'
            (0xFE30, .cjkCompatibilityForms),           // '︰'
            (0x1F004, .mahjongTiles),                   // '🀄'
            (0x1F1EF, .regionalIndicatorSymbol),        // 🇯 (JP の前半)
            (0x1F600, .emoticons),                      // '😀'
            (0x1F44D, .miscellaneousSymbolsAndPictographs), // '👍'
            (0x1F9D1, .supplementalSymbolsAndPictographs),  // '🧑'
        ]

        for (value, expected) in expectations {
            XCTAssertEqual(
                Unicode.Scalar.u(value).unicodeCategory, expected,
                "\(value.hex) の分類が期待と違う"
            )
        }
    }

    /// 穴に落ちるスカラーは nil になること（既知の穴の記録も兼ねる）。
    func testScalarsInKnownGapsAreUnclassified() {
        for value: UInt32 in [0x2FE5, 0x10000, 0x1FC00] {
            XCTAssertNil(
                Unicode.Scalar.u(value).unicodeCategory,
                "\(value.hex) が分類されるようになった。testGapsMatchKnownList の一覧も更新すること"
            )
        }
    }

    /// STScript が参照しているカテゴリは、必ず自分自身に引き当たること。
    ///
    /// 重なりで先に宣言された別ケースに食われていると、そのスクリプトの
    /// フォントが一生選ばれないまま静かに壊れる。
    func testCategoriesUsedByScriptsAreReachable() {
        for script in STScript.allCases {
            for category in script.unicodeCategories {
                let lower = category.range.lowerBound
                let upper = category.range.upperBound - 1
                XCTAssertEqual(
                    Unicode.Scalar.u(lower).unicodeCategory, category,
                    "\(name(category)) の先頭 \(lower.hex) が別のカテゴリに食われている（script: \(script)）"
                )
                XCTAssertEqual(
                    Unicode.Scalar.u(upper).unicodeCategory, category,
                    "\(name(category)) の末尾 \(upper.hex) が別のカテゴリに食われている（script: \(script)）"
                )
            }
        }
    }
}
