/*
STLabelFontChangeTests.swift

書体を変えたときに、組み直されることの検証。

STLabelは組み直す前に「組み直す必要があるか」を見る。見ているのは
needsToLayoutの旗と、前に組んだときの大きさの2つだけなので、大きさの
変わらない変更は旗を立てないかぎり素通りする。書体はまさにそれで、
立て忘れるとグリフは前の書体のまま残り、画面を開き直すまで直らない。
*/

#if os(iOS)
import XCTest
import UIKit
@testable import stone_engine

final class STLabelFontChangeTests: XCTestCase {
    /// 日本語で使える、別々の書体。
    private let fontName = "HiraginoSans-W3"
    private let otherFontName = "HiraginoSans-W7"

    /// 組んだ結果のグリフ。書体が変われば、同じ文字でも別のIDになる。
    private func glyphs(of label: STLabel) -> [CGGlyph] {
        return label.context.runs.map { $0.glyph }
    }

    /// 1度組んだあとのラベル。
    private func laidOutLabel() -> STLabel {
        let label = STLabel()
        label.text = "あいうえお"
        label.fontSize = 17
        label.setFontNames([fontName], script: .japanese)
        label.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
        label.layoutSubviews()

        return label
    }

    /// 書体を変えたら、大きさが変わらなくても組み直されること。
    func testChangingFontNamesRelaysOut() throws {
        let label = laidOutLabel()
        let before = glyphs(of: label)
        XCTAssertFalse(before.isEmpty, "前提が崩れている")

        // 書体だけを変える。フレームはそのまま
        label.setFontNames([otherFontName], script: .japanese)
        label.layoutSubviews()

        let after = glyphs(of: label)
        try XCTSkipIf(
            before == glyphsForSameText(fontName: otherFontName),
            "2つの書体のグリフIDが同じなので、この検証では違いを見られない"
        )
        XCTAssertNotEqual(
            before, after,
            "書体を変えても組み直されていない。前の書体のグリフが残っている"
        )
    }

    /// 文字の倍率を変えたときも、組み直されること。
    func testChangingFontScaleRelaysOut() {
        let label = laidOutLabel()
        let before = label.context.renderedSize

        // 倍率だけを変える。フレームはそのまま
        label.setFontScale(0.5, script: .japanese)
        label.layoutSubviews()

        XCTAssertNotEqual(
            before, label.context.renderedSize,
            "倍率を変えても組み直されていない"
        )
    }

    /// 比較用。その書体で同じ文字を組んだときのグリフ。
    private func glyphsForSameText(fontName: String) -> [CGGlyph] {
        let label = STLabel()
        label.text = "あいうえお"
        label.fontSize = 17
        label.setFontNames([fontName], script: .japanese)
        label.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
        label.layoutSubviews()

        return glyphs(of: label)
    }
}
#endif
