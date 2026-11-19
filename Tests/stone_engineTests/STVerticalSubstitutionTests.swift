/*
縦組みのグリフ差し替えが、フォントごとの表を使うことの検証。

差し替え表はフォントごとに持つ。表を取り違えると、グリフIDは
フォントごとに違うので、別のフォントの無関係なグリフを引くことになり、
その文字は空白か別物になって出る。横組みはこの差し替えを通らないため、
取り違えても気づけない。
*/

import XCTest
import CoreText
@testable import stone_engine

final class STVerticalSubstitutionTests: XCTestCase {
    /// 日本語フォント。縦組みの字形を持つ。
    private let kanaFontName = "HiraginoSans-W3"

    /// ラテン文字のフォント。仮名の縦組みの字形は持たない。
    private let latinFontName = "HelveticaNeue"

    /// fontNameでcharを組むときのグリフID。
    private func glyph(of char: Character, fontName: String) -> CGGlyph? {
        let font = CTFontCreateWithName(fontName as CFString, 17, nil)
        let chars = Array(String(char).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        guard CTFontGetGlyphsForCharacters(font, chars, &glyphs, chars.count) else { return nil }
        guard let glyph = glyphs.first, glyph != 0 else { return nil }

        return glyph
    }

    /// 縦組みの字形を持つ文字のうち、日本語フォントで引けたもの。
    private func kanaGlyphWithVerticalForm() throws -> CGGlyph {
        for char in ["、", "。", "「", "」", "ー"] {
            guard let glyph = glyph(of: Character(char), fontName: kanaFontName) else { continue }
            guard STTextVerticalSubstitutionGlyphWithGlyph(fontName: kanaFontName, glyph: glyph) != 0 else { continue }

            return glyph
        }

        throw XCTSkip("縦組みの字形を持つ文字が\(kanaFontName)で見つからない")
    }

    /// 仮名の縦組みの字形を、ラテン文字のフォントが持っていると答えないこと。
    ///
    /// 表を取り違えていると、日本語フォントの表を引いて字形を見つけてしまう。
    func testLatinFontHasNoKanaVerticalForm() throws {
        let glyph = try kanaGlyphWithVerticalForm()
        XCTAssertEqual(
            STTextVerticalSubstitutionGlyphWithGlyph(fontName: latinFontName, glyph: glyph), 0,
            "\(latinFontName)が仮名の縦組みの字形を返している。別のフォントの表を引いている"
        )
    }

    /// 登録されていないフォントが、登録済みのフォントの答えを受け取らないこと。
    func testUnregisteredFontDoesNotBorrowAnotherTable() throws {
        let glyph = try kanaGlyphWithVerticalForm()
        let kanaSubstitution = STTextVerticalSubstitutionGlyphWithGlyph(fontName: kanaFontName, glyph: glyph)
        XCTAssertNotEqual(kanaSubstitution, 0, "前提が崩れている")

        // 実在しないフォントには、引ける表が無い
        XCTAssertEqual(
            STTextVerticalSubstitutionGlyphWithGlyph(fontName: "NoSuchFont-Regular", glyph: glyph), 0,
            "登録されていないフォントが、別のフォントの表を引いている"
        )
    }
}
