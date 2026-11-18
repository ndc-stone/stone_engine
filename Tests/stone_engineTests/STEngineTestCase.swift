/*
STEngineTestCase.swift

stone_engine のユニットテスト共通の土台。

テストは `@testable import stone_engine` で内部の型に触れる。
UI を扱う型があるので、テストクラスは MainActor に置く。
*/

import XCTest
@testable import stone_engine

@MainActor
class STEngineTestCase: XCTestCase {

    //--------------------------------------------------------------//
    // MARK: - Context
    //--------------------------------------------------------------//

    /// 既定設定の STContext を作る。
    ///
    /// STFontManager は refresh() を呼ぶまで possibleFontNames / possibleScripts が
    /// 空のままで、fontId(char:) も script(fontId:) も使えない。通常は STLabel が
    /// 呼ぶので、ビューを介さないテストではここで初期化しておく必要がある。
    func makeContext(
        direction: STDirection = .lrTb,
        punctuationMode: STPunctuationMode = .stone,
        fontSize: CGFloat = 16,
        renderSize: CGSize = CGSize(width: 1000, height: 1000)
    ) -> STContext {
        let context = STContext()
        context.direction = direction
        context.punctuationMode = punctuationMode
        context.fontSize = fontSize
        context.renderSize = renderSize
        context.fontManager.refresh()

        return context
    }

    //--------------------------------------------------------------//
    // MARK: - Parse
    //--------------------------------------------------------------//

    /// text をパースした STContext を返す（レイアウトは行わない）。
    @discardableResult
    func parse(_ text: String?, into context: STContext? = nil) -> STContext {
        let context = context ?? makeContext()
        STParser(context: context).parse(text: text)

        return context
    }

    /// context が保持している文字列（run 順）。
    func runText(_ context: STContext) -> String {
        return String(context.runChars)
    }

    //--------------------------------------------------------------//
    // MARK: - Layout
    //--------------------------------------------------------------//

    /// text をパースしてレイアウトまで済ませた STContext を返す。
    @discardableResult
    func layout(_ text: String?, into context: STContext? = nil) -> STContext {
        let context = context ?? makeContext()
        STParser(context: context).parse(text: text)
        STLayout(context: context).layout()

        return context
    }

    /// 縦組み用に、幅を組んだ結果ぴったりに詰めてから組み直す。
    ///
    /// 縦組みのレイアウトは renderSize.width の右端から左へ組むが、
    /// `firstRunFrame(line:)`（= ヒットテストの行判定が使う）は
    /// renderedSize.width を基準にする。実アプリでは測定パスを挟んで
    /// 両者が一致するので、ヒットテストを検証するときは同じ状態を作る。
    @discardableResult
    func layoutFittedTbRl(_ text: String?, into context: STContext? = nil) -> STContext {
        let context = context ?? makeContext(direction: .tbRl)
        XCTAssertEqual(context.direction, .tbRl, "縦組み専用のヘルパー")

        layout(text, into: context)
        context.renderSize.width = context.renderedSize.width
        STLayout(context: context).layout()

        return context
    }

    //--------------------------------------------------------------//
    // MARK: - Line
    //--------------------------------------------------------------//

    /// 行ごとの run ID 範囲。行に run がない場合は含めない。
    func lineRanges(_ context: STContext) -> [Range<Int>] {
        var ranges = [Range<Int>]()
        var lower = 0
        for runId in 0 ..< context.runs.count {
            if runId + 1 == context.runs.count || context.runs[runId + 1].line != context.runs[runId].line {
                ranges.append(lower ..< runId + 1)
                lower = runId + 1
            }
        }

        return ranges
    }

    /// 行ごとの文字列（改行文字も含む）。
    func lineTexts(_ context: STContext) -> [String] {
        return lineRanges(context).map { String(context.runChars[$0]) }
    }
}

//--------------------------------------------------------------//
// MARK: - Helpers
//--------------------------------------------------------------//

extension Unicode.Scalar {
    /// テスト表を読みやすく書くための短縮形。
    static func u(_ value: UInt32) -> Unicode.Scalar {
        guard let scalar = Unicode.Scalar(value) else {
            preconditionFailure("不正なスカラー値: \(String(value, radix: 16))")
        }
        return scalar
    }
}

extension UInt32 {
    var hex: String { "U+" + String(format: "%04X", self) }
}
