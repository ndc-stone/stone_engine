/*
STPerformanceTests.swift

パースとレイアウトの性能。

絶対時間は機械の速さに左右されるので、合否の判定には使わない。
代わりに「文字数を n 倍にしたとき、時間がおよそ n 倍で収まるか」という
計算量の性質を見る。うっかり O(n²) を持ち込むとここで落ちる。

数値そのものは measure で記録する。ただし 100,000 文字を 10 回ずつ回すと
それだけで 17 秒かかり、0.3 秒で終わるほかのユニットテストの足を引っ張る。
合否を持たない計測なので、既定では飛ばして環境変数で明示的に呼び出す:

    MEASURE_PERFORMANCE=1 swift test --filter STPerformanceTests

（iOS Simulator では環境変数名を TEST_RUNNER_MEASURE_PERFORMANCE にして xcodebuild test を使う）
*/

import XCTest
@testable import stone_engine

@MainActor
final class STPerformanceTests: STEngineTestCase {

    /// 日本語・ラテン・約物・改行が混ざった、実際の原稿に近い本文。
    private func sampleText(charCount: Int) -> String {
        let paragraph = "吾輩は猫である。名前はまだ無い。どこで生れたかとんと見当がつかぬ。"
            + "何でも薄暗いじめじめした所でニャーニャー泣いていた事だけは記憶している。\n"
            + "abc 123 「引用」（注記）\n"
        var text = ""
        text.reserveCapacity(charCount + paragraph.count)
        while text.count < charCount {
            text += paragraph
        }
        return String(text.prefix(charCount))
    }

    private func makeSizedContext(direction: STDirection = .lrTb) -> STContext {
        return makeContext(
            direction: direction,
            renderSize: direction == .lrTb
                ? CGSize(width: 16 * 40, height: 100_000)
                : CGSize(width: 100_000, height: 16 * 40)
        )
    }

    /// 処理を repeats 回まわして中央値の秒数を返す。
    /// 1 回だけだと他のプロセスの影響を拾うので、中央値で均す。
    private func medianSeconds(repeats: Int = 3, _ body: () -> Void) -> Double {
        var times = [Double]()
        for _ in 0 ..< repeats {
            let start = CFAbsoluteTimeGetCurrent()
            body()
            times.append(CFAbsoluteTimeGetCurrent() - start)
        }
        times.sort()

        return times[times.count / 2]
    }

    /// 処理を repeats 回まわして最短の秒数を返す。
    /// 他のプロセスの影響は時間を延ばす方向にしか働かないので、最短が最も安定する。
    private func fastestSeconds(repeats: Int = 5, _ body: () -> Void) -> Double {
        var fastest = Double.greatestFiniteMagnitude
        for _ in 0 ..< repeats {
            let start = CFAbsoluteTimeGetCurrent()
            body()
            fastest = min(fastest, CFAbsoluteTimeGetCurrent() - start)
        }

        return fastest
    }

    //--------------------------------------------------------------//
    // MARK: - 計算量
    //--------------------------------------------------------------//

    /// 文字数を 4 倍にしても、パース＋レイアウトの時間が 4 倍前後で収まること。
    ///
    /// 線形なら 4 倍、二乗なら 16 倍になる。しきい値 8 倍は、
    /// 線形の側の揺らぎを許しつつ二乗をはっきり弾ける位置に置いてある。
    /// CI では一時的に遅くなることがあるので、3 回測って一度も下回らないときだけ失敗にする。
    private func assertScales(
        direction: STDirection,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let small = sampleText(charCount: 6_000)
        let large = sampleText(charCount: 24_000)

        func parseAndLayout(_ text: String) -> Double {
            return fastestSeconds {
                let context = makeSizedContext(direction: direction)
                STParser(context: context).parse(text: text)
                STLayout(context: context).layout()
            }
        }

        var smallTime = 0.0
        var largeTime = 0.0
        var ratio = Double.greatestFiniteMagnitude
        for _ in 0 ..< 3 where ratio >= 8.0 {
            smallTime = parseAndLayout(small)
            largeTime = parseAndLayout(large)
            ratio = largeTime / smallTime
        }

        XCTAssertLessThan(
            ratio, 8.0,
            "[\(direction)] 文字数 4 倍で時間が \(String(format: "%.1f", ratio)) 倍になった"
                + "（\(String(format: "%.1f", smallTime * 1000))ms → \(String(format: "%.1f", largeTime * 1000))ms）。"
                + "線形なら 4 倍前後、二乗なら 16 倍前後になる",
            file: file, line: line
        )
    }

    func testParseAndLayoutScalesLinearlyLrTb() {
        assertScales(direction: .lrTb)
    }

    func testParseAndLayoutScalesLinearlyTbRl() {
        assertScales(direction: .tbRl)
    }

    /// 幅を変えただけの組み直しは、パースからやり直すより速いこと。
    /// STLabel はリサイズ時にパースを飛ばす作りになっており、その前提を守る。
    func testRelayoutIsCheaperThanReparse() {
        let text = sampleText(charCount: 10_000)

        let full = medianSeconds {
            let context = makeSizedContext()
            STParser(context: context).parse(text: text)
            STLayout(context: context).layout()
        }

        let context = makeSizedContext()
        STParser(context: context).parse(text: text)
        STLayout(context: context).layout()
        var width: CGFloat = 16 * 40
        let relayoutOnly = medianSeconds {
            // 毎回違う幅にして、組み直しが実際に走るようにする
            width += 16
            context.renderSize.width = width
            STLayout(context: context).layout()
        }

        XCTAssertLessThan(
            relayoutOnly, full,
            "組み直しだけのほうが、パースからやり直すより遅い"
                + "（組み直し \(String(format: "%.1f", relayoutOnly * 1000))ms / 全部 \(String(format: "%.1f", full * 1000))ms）"
        )
    }

    /// フォントとグリフのキャッシュが効いて、2 回目以降のパースが速くなること。
    func testGlyphCacheSpeedsUpReparse() {
        let text = sampleText(charCount: 10_000)
        let context = makeSizedContext()
        let parser = STParser(context: context)

        let first = medianSeconds(repeats: 1) { parser.parse(text: text) }
        let cached = medianSeconds { parser.parse(text: text) }

        XCTAssertLessThan(
            cached, first,
            "2 回目以降のパースが速くなっていない"
                + "（初回 \(String(format: "%.1f", first * 1000))ms / 2 回目以降 \(String(format: "%.1f", cached * 1000))ms）"
        )
    }

    //--------------------------------------------------------------//
    // MARK: - 記録
    //--------------------------------------------------------------//

    // 以下は合否を持たない計測。既定では飛ばす（ファイル冒頭の説明を参照）。

    private func skipUnlessMeasuring() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["MEASURE_PERFORMANCE"] != nil,
            "計測のみのテスト。MEASURE_PERFORMANCE=1 を指定したときだけ走らせる"
        )
    }

    func testPerformanceParse() throws {
        try skipUnlessMeasuring()
        let text = sampleText(charCount: 100_000)
        let context = makeSizedContext()
        measure {
            STParser(context: context).parse(text: text)
        }
    }

    func testPerformanceLayoutLrTb() throws {
        try skipUnlessMeasuring()
        let text = sampleText(charCount: 100_000)
        let context = makeSizedContext()
        STParser(context: context).parse(text: text)
        measure {
            STLayout(context: context).layout()
        }
    }

    func testPerformanceLayoutTbRl() throws {
        try skipUnlessMeasuring()
        let text = sampleText(charCount: 100_000)
        let context = makeSizedContext(direction: .tbRl)
        STParser(context: context).parse(text: text)
        measure {
            STLayout(context: context).layout()
        }
    }

    func testPerformanceParseAndLayout() throws {
        try skipUnlessMeasuring()
        let text = sampleText(charCount: 100_000)
        measure {
            let context = makeSizedContext()
            STParser(context: context).parse(text: text)
            STLayout(context: context).layout()
        }
    }
}
