/*
STRubyAlignTests.swift

ルビのある行を寄せる段を検証する。

読みは語の上（縦組みでは右）に置かれるもので、行の長さには関与しない。
行の長さを測るときに読みまで足すと、行は実際より長いことにされ、
寄せは読みの幅のぶんだけ足りなくなる。中央寄せなら、その半分だけずれる。

ルビの有無で本文の置き場所が変わらないこと、が基準になる。
読みは語に対して中央に乗るので、語の中心と読みの中心も揃う。
*/

import XCTest
@testable import stone_engine

@MainActor
final class STRubyAlignTests: STEngineTestCase {

    //--------------------------------------------------------------//
    // MARK: - Helper
    //--------------------------------------------------------------//

    private func layoutAligned(
        _ text: String,
        align: STTextAlign,
        direction: STDirection = .lrTb,
        renderSize: CGSize = CGSize(width: 200, height: 200)
    ) -> STContext {
        let context = makeContext(direction: direction, renderSize: renderSize)
        context.textAlign = align
        context.rubyNotation = .braces
        STParser(context: context).parse(text: text)
        STLayout(context: context).layout()

        return context
    }

    /// 読みではない、本文のランだけ。
    private func baseRuns(_ context: STContext) -> [STRun] {
        return context.runs.filter { !$0.flags.contains(.rubyText) }
    }

    /// 読みのランだけ。
    private func rubyRuns(_ context: STContext) -> [STRun] {
        return context.runs.filter { $0.flags.contains(.rubyText) }
    }

    //--------------------------------------------------------------//
    // MARK: - Center
    //--------------------------------------------------------------//

    /// 横組みの中央寄せで、ルビを振っても本文の置き場所が動かないこと。
    func testCenterLrTbIsUnmovedByRuby() {
        let plain = layoutAligned("白身", align: .center)
        let ruby = layoutAligned("{白身|しろみ}", align: .center)

        let plainXs = baseRuns(plain).map { $0.frame.minX }
        let rubyXs = baseRuns(ruby).map { $0.frame.minX }
        XCTAssertEqual(plainXs, rubyXs, "ルビを振ると本文の中央寄せがずれる")
    }

    /// 縦組みの中央寄せで、ルビを振っても本文の置き場所が動かないこと。
    func testCenterTbRlIsUnmovedByRuby() {
        let size = CGSize(width: 200, height: 200)
        let plain = layoutAligned("白身", align: .center, direction: .tbRl, renderSize: size)
        let ruby = layoutAligned("{白身|しろみ}", align: .center, direction: .tbRl, renderSize: size)

        let plainYs = baseRuns(plain).map { $0.frame.minY }
        let rubyYs = baseRuns(ruby).map { $0.frame.minY }
        XCTAssertEqual(plainYs, rubyYs, "ルビを振ると本文の中央寄せがずれる")
    }

    /// 読みが語より広いときも、本文の置き場所が動かないこと。
    ///
    /// 読みがはみ出すぶん、行の長さに足してしまったときのずれが大きくなる。
    func testCenterIsUnmovedByOverhangingRuby() {
        let plain = layoutAligned("空", align: .center)
        let ruby = layoutAligned("{空|からっぽ}", align: .center)

        XCTAssertEqual(
            baseRuns(plain).map { $0.frame.minX },
            baseRuns(ruby).map { $0.frame.minX },
            "語より広い読みを振ると本文の中央寄せがずれる"
        )
    }

    /// 読みが語の中央に乗ること。
    func testRubyIsCenteredOverItsBase() {
        let context = layoutAligned("{白身|しろみ}", align: .center)
        let base = baseRuns(context)
        let ruby = rubyRuns(context)
        XCTAssertFalse(base.isEmpty || ruby.isEmpty, "前提が崩れている")

        let baseCenter = (base.first!.frame.minX + base.last!.frame.maxX) * 0.5
        let rubyCenter = (ruby.first!.frame.minX + ruby.last!.frame.maxX) * 0.5
        XCTAssertEqual(rubyCenter, baseCenter, accuracy: 0.001, "読みが語の中央に乗っていない")
    }

    //--------------------------------------------------------------//
    // MARK: - Trailing
    //--------------------------------------------------------------//

    /// 行末寄せでも、ルビで本文の置き場所が動かないこと。
    func testTrailingIsUnmovedByRuby() {
        let plain = layoutAligned("白身", align: .trailng)
        let ruby = layoutAligned("{白身|しろみ}", align: .trailng)

        XCTAssertEqual(
            baseRuns(plain).map { $0.frame.minX },
            baseRuns(ruby).map { $0.frame.minX },
            "ルビを振ると本文の行末寄せがずれる"
        )
    }

    //--------------------------------------------------------------//
    // MARK: - Justify
    //--------------------------------------------------------------//

    /// 均等割りで、読みが語から離れないこと。
    ///
    /// 読みは語とは別のトークンになっている。トークンの切れ目として数えると、
    /// 語と読みの間に空きが入り、読みだけが行末の側へ流れる。
    func testJustifyKeepsRubyOverItsBase() {
        let context = layoutAligned("{白身|しろみ}のにぎり", align: .justify)
        let base = baseRuns(context)
        let ruby = rubyRuns(context)
        XCTAssertFalse(ruby.isEmpty, "前提が崩れている")

        // 読みは先頭の語「白身」に乗る
        let baseCenter = (base[0].frame.minX + base[1].frame.maxX) * 0.5
        let rubyCenter = (ruby.first!.frame.minX + ruby.last!.frame.maxX) * 0.5
        XCTAssertEqual(rubyCenter, baseCenter, accuracy: 0.001, "均等割りで読みが語から離れた")
    }
}
