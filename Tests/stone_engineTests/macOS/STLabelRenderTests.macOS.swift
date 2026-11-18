/*
STLabelRenderTests.swift

STLabel の描画パスの検証。

レイアウトのテストは枡の位置までしか見ないので、実際にグリフを描く経路
（縦組みの回転、絵文字の反転描画、選択範囲の塗り、可視ラン範囲の絞り込み）
には手が届かない。ここでは STLabel をオフスクリーンで描いて、
落ちないこと・インクが期待した場所に乗ることを確かめる。

画素そのものの比較は STLabelSnapshotTests が行う。
*/

#if os(macOS)
import XCTest
@testable import stone_engine

@MainActor
final class STLabelRenderTests: STLabelRenderTestCase {

    //--------------------------------------------------------------//
    // MARK: - 描けること
    //--------------------------------------------------------------//

    /// いろいろな設定の総当たりで、描画が落ちずインクが乗ること。
    /// 描画パスにはレイアウトのテストが届かないので、まず通ることを確かめる。
    func testDrawsWithoutCrashing() throws {
        let texts = [
            "あいうえお",
            "Hello, world!",
            "「吾輩は猫である」と、彼は言った。\n名前はまだ無い。",
            "第12章と第345章",
            "あ🇯🇵a😀漢👨‍👩‍👧‍👦",
            "\n\n\n",
        ]

        for direction in STDirection.allCases {
            for punctuationMode in STPunctuationMode.allCases {
                for text in texts {
                    let label = makeLabel(text: text, direction: direction) {
                        $0.context.punctuationMode = punctuationMode
                    }
                    let rep = try render(label)
                    XCTAssertEqual(rep.pixelsWide > 0 && rep.pixelsHigh > 0, true)

                    // 改行だけの本文はインクがなくて当たり前
                    if text.contains(where: { !$0.isNewline }) {
                        XCTAssertNotNil(
                            inkBounds(rep),
                            "[\(direction)/\(punctuationMode)] 何も描かれていない: \(text)"
                        )
                    }
                }
            }
        }
    }

    /// 空のラベルは何も描かないこと。
    func testEmptyTextDrawsNothing() throws {
        let label = makeLabel(text: "")
        XCTAssertNil(inkBounds(try render(label)), "空なのにインクが乗っている")
    }

    //--------------------------------------------------------------//
    // MARK: - インクの位置
    //--------------------------------------------------------------//

    /// 横組みは左上から、縦組みは右上から描き始めること。
    ///
    /// ビットマップは Retina で 2 倍の画素数になるので、位置の比較は
    /// ポイントではなくビットマップ自身の画素数を基準にする。
    /// NSBitmapImageRep の座標は左上が原点なので、y が小さいほど上。
    func testInkStartsAtTheExpectedCorner() throws {
        let size = CGSize(width: 16 * 10, height: 16 * 6)

        let hRep = try render(makeLabel(text: "あいう", size: size, direction: .lrTb))
        let hWide = CGFloat(hRep.pixelsWide)
        let hInk = try XCTUnwrap(inkBounds(hRep), "横組みで何も描かれていない")
        XCTAssertLessThan(hInk.minX, hWide * 0.25, "横組みが左から始まっていない: \(hInk) / 幅 \(hWide)")
        XCTAssertLessThan(hInk.maxX, hWide * 0.5, "横組みが右まで伸びている: \(hInk) / 幅 \(hWide)")

        let vRep = try render(makeLabel(text: "あいう", size: size, direction: .tbRl))
        let vWide = CGFloat(vRep.pixelsWide)
        let vInk = try XCTUnwrap(inkBounds(vRep), "縦組みで何も描かれていない")
        XCTAssertGreaterThan(vInk.maxX, vWide * 0.75, "縦組みが右端から始まっていない: \(vInk) / 幅 \(vWide)")
        XCTAssertGreaterThan(vInk.minX, vWide * 0.5, "縦組みが左まで伸びている: \(vInk) / 幅 \(vWide)")
    }

    /// 行が増えるとインクが下（縦組みでは左）へ広がること。
    func testInkGrowsWithLines() throws {
        let size = CGSize(width: 16 * 4, height: 16 * 6)

        let oneLine = try XCTUnwrap(inkBounds(try render(makeLabel(text: "あいう", size: size))))
        let twoLines = try XCTUnwrap(inkBounds(try render(makeLabel(text: "あいうえおかき", size: size))))
        XCTAssertGreaterThan(twoLines.maxY, oneLine.maxY, "横組みで 2 行目が下に描かれていない")

        let vOne = try XCTUnwrap(inkBounds(try render(makeLabel(text: "あいう", size: size, direction: .tbRl))))
        let vTwo = try XCTUnwrap(inkBounds(try render(makeLabel(text: "あいうえおかきくけこ", size: size, direction: .tbRl))))
        XCTAssertLessThan(vTwo.minX, vOne.minX, "縦組みで 2 行目が左に描かれていない")
    }

    /// 文字が増えるとインクの量も増えること（同じ枡に重ね描きしていない）。
    func testInkAmountGrowsWithText() throws {
        let size = CGSize(width: 16 * 10, height: 16 * 6)
        let one = inkRatio(try render(makeLabel(text: "あ", size: size)))
        let many = inkRatio(try render(makeLabel(text: "あいうえおかきくけこ", size: size)))

        XCTAssertGreaterThan(many, one * 3, "文字数を増やしてもインクが増えていない（重ね描き？）")
    }

    //--------------------------------------------------------------//
    // MARK: - 選択範囲
    //--------------------------------------------------------------//

    /// 選択範囲の塗りは、STLabel ではなく持ち主の STTextView が持つ
    /// selectedSTTextRange を見て描かれる。そのためラベル単体では試せない。
    private func renderSelection(text: String, range: Range<Int>, size: CGSize) throws -> NSBitmapImageRep {
        let textView = STTextView(frame: CGRect(origin: .zero, size: size))
        textView.text = text
        textView.selectedSTTextRange = STTextRange(range: range)
        textView.layoutSubtreeIfNeeded()

        let label = textView.label!
        label.frame = CGRect(origin: .zero, size: size)
        label.parseAndLayout()

        return try render(label)
    }

    /// 選択範囲が塗られること。塗った側のほうがインクが多い。
    func testSelectedAreaIsFilled() throws {
        let size = CGSize(width: 16 * 10, height: 16 * 3)
        let text = "あいうえおかきくけこ"

        let plain = inkRatio(try renderSelection(text: text, range: 0 ..< 0, size: size))
        let selected = inkRatio(try renderSelection(text: text, range: 0 ..< 10, size: size))

        XCTAssertGreaterThan(selected, plain * 2, "選択範囲が塗られていない（\(plain) → \(selected)）")
    }

    /// 選択範囲の広さが塗りの量に反映されること。
    func testSelectionWidthAffectsFill() throws {
        let size = CGSize(width: 16 * 10, height: 16 * 3)
        let text = "あいうえおかきくけこ"

        let half = inkRatio(try renderSelection(text: text, range: 0 ..< 5, size: size))
        let all = inkRatio(try renderSelection(text: text, range: 0 ..< 10, size: size))

        XCTAssertLessThan(half, all, "選択範囲の広さが塗りに反映されていない")
    }
}
#endif
