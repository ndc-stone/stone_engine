/*
STLabelPunctuationFontTests.macOS.swift

「…」「‥」「―」などの検証。

Unicode の General Punctuation（U+2000〜206F）は、どの文字種にも属さないので、
放っておくと最初に見つかる欧文フォントで組まれる。欧文の「…」は点が小さく
ベースライン上にあり、縦組みで横倒しにすると点が行の左に寄る。送りも全角に
ならない。stone 1.2 と同じく、横組みでも縦組みでも日本語フォントで組み、
縦組みではその字形を横倒しにする。日本語フォントの「…」は字の枠の上下中央に
あるので、横組みでは字の上下中央に、縦組みでは行の左右中央に来る。
*/

#if os(macOS)
import XCTest
@testable import stone_engine

@MainActor
final class STLabelPunctuationFontTests: STLabelRenderTestCase {

    private let punctuation = "…‥―"

    /// 縦組みでは、日本語フォントで横倒しに組むこと。送りは全角になる。
    func testSetSidewaysInJapaneseFontInVertical() {
        let label = makeLabel(text: punctuation, size: CGSize(width: 16 * 4, height: 16 * 10), direction: .tbRl)
        let context = label.context

        for run in context.runs {
            let char = String(UnicodeScalar(run.scalar)!)
            XCTAssertEqual(context.fontManager.script(fontId: run.fontId), .japanese, "「\(char)」が日本語フォントで組まれていない")
            XCTAssertTrue(context.isClockwise(run: run), "「\(char)」が横倒しになっていない")
            XCTAssertEqual(run.frame.height, 16, accuracy: 0.5, "「\(char)」の送りが全角でない")
        }
    }

    /// 縦組みでは「…」の点が行の左右中央に来ること。
    func testEllipsisIsCenteredInVertical() throws {
        let label = makeLabel(text: "…", size: CGSize(width: 16 * 4, height: 16 * 10), direction: .tbRl)
        let run = label.context.runs[0]
        let rep = try render(label)
        let ink = try XCTUnwrap(inkBounds(rep), "「…」が描かれていない")

        // インクの位置は画素で返るので、ラベルの座標に直す
        let scale = CGFloat(rep.pixelsWide) / label.bounds.width
        XCTAssertEqual(ink.midX / scale, run.frame.midX, accuracy: 16 * 0.1, "「…」の点が行の中央にない（点 \(ink)、文字 \(run.frame)）")
    }

    /// 横組みでも日本語フォントで組むこと。横倒しにはしない。送りは全角になる。
    func testSetInJapaneseFontInHorizontal() {
        let label = makeLabel(text: punctuation)
        let context = label.context

        for run in context.runs {
            let char = String(UnicodeScalar(run.scalar)!)
            XCTAssertEqual(context.fontManager.script(fontId: run.fontId), .japanese, "「\(char)」が日本語フォントで組まれていない")
            XCTAssertFalse(context.isClockwise(run: run), "「\(char)」が横倒しになっている")
            XCTAssertEqual(run.frame.width, 16, accuracy: 0.5, "「\(char)」の送りが全角でない")
        }
    }

    /// 横組みでは「…」の点が字の上下中央に来ること。
    func testEllipsisIsCenteredInHorizontal() throws {
        let label = makeLabel(text: "…")
        let run = label.context.runs[0]
        let rep = try render(label)
        let ink = try XCTUnwrap(inkBounds(rep), "「…」が描かれていない")

        // インクの位置は画素で返るので、ラベルの座標に直す
        let scale = CGFloat(rep.pixelsWide) / label.bounds.width
        XCTAssertEqual(ink.midY / scale, run.frame.midY, accuracy: 16 * 0.15, "「…」の点が字の中央にない（点 \(ink)、文字 \(run.frame)）")
    }

    /// 縦組みと横組みで同じフォントを使うこと。点の大きさが組み方向で変わらない。
    func testSameFontInBothDirections() {
        let vertical = makeLabel(text: punctuation, direction: .tbRl)
        let horizontal = makeLabel(text: punctuation)

        XCTAssertEqual(vertical.context.runs.map(\.fontId), horizontal.context.runs.map(\.fontId))
    }
}
#endif
