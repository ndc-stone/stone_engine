/*
STLayoutSnapshotTests.swift

代表的な組版パターンのレイアウト結果を、まとめて 1 つのテキストと突き合わせる。

期待値は `__Snapshots__/<OS>/layout.txt`。個々の不変条件テストと違って
「今の組版がどう見えるか」を丸ごと固定するので、最適化やリファクタで
意図せず配置が変わったときにここが落ちる。

期待値の更新（記録モード）:
    SNAPSHOT_RECORD=1 swift test --filter STLayoutSnapshotTests
  新しい内容を一時ファイルへ書き出し、期待値へコピーするコマンドをログに出す。
  iOS Simulator では環境変数名を TEST_RUNNER_SNAPSHOT_RECORD にして xcodebuild test を使う。
*/

import XCTest
@testable import stone_engine

@MainActor
final class STLayoutSnapshotTests: STEngineTestCase {

    private static let baselineName = "layout.txt"

    //--------------------------------------------------------------//
    // MARK: - Cases
    //--------------------------------------------------------------//

    /// 全角だけのケースは 16pt の枡にちょうど載るので、フォントの送りに依存しない。
    /// ラテン・絵文字を含むケースは依存するので note に明記してある。
    private var snapshotCases: [STLayoutSnapshotCase] {
        var cases = [STLayoutSnapshotCase]()

        func add(_ snapshotCase: STLayoutSnapshotCase, _ configure: ((inout STLayoutSnapshotCase) -> Void)? = nil) {
            var snapshotCase = snapshotCase
            configure?(&snapshotCase)
            cases.append(snapshotCase)
        }

        let fontDependent = "ラテン／絵文字を含むためフォントの送りに依存する"

        // --- 横組み: 行分割 ---
        add(.make("lrTb-wrap", "あいうえおかきくけこさしすせそ", charsPerLine: 6))
        add(.make("lrTb-wrap-narrow", "あいうえおかきくけこ", charsPerLine: 3))
        add(.make("lrTb-newlines", "いち\nに\r\nさん\rよん", charsPerLine: 8))
        add(.make("lrTb-trailing-newline", "おわり\n", charsPerLine: 8))

        // --- 横組み: 禁則 ---
        add(.make("lrTb-kinsoku-not-starting", "あいうえおか、きくけこ", charsPerLine: 6))
        add(.make("lrTb-kinsoku-not-ending", "あいうえお「かきくけこ」さし", charsPerLine: 6))
        add(.make("lrTb-kinsoku-off", "あいうえおか、きくけこ", charsPerLine: 6)) { $0.isKinsokuAvailable = false }
        add(.make("lrTb-kinsoku-dense", "アイウエオャュョッーヽヾカキク", charsPerLine: 4),
            { $0.note = "行まるごとが行頭禁則になる場合の打ち切り" })
        add(.make("lrTb-hanging", "あいうえお、かきく", charsPerLine: 5)) { $0.isFixedWidth = true }

        // --- 横組み: 約物 ---
        for mode in STPunctuationMode.allCases {
            add(.make("lrTb-punctuation-\(mode)", "」「あ。」・", charsPerLine: 20)) { $0.punctuationMode = mode }
        }
        add(.make("lrTb-punctuation-sentence", "「こんにちは」と、彼は言った。", charsPerLine: 8))
        add(.make("lrTb-opening-bracket-at-line-start", "あいうえおか「きくけこさしすせそ", charsPerLine: 6))

        // --- 横組み: 揃え ---
        for align in STTextAlign.allCases {
            add(.make("lrTb-align-\(align)", "あいうえ\nかきくけこさ", charsPerLine: 8)) { $0.textAlign = align }
        }
        add(.make("lrTb-justify-words", "aaa bbb ccc ddd eee fff", charsPerLine: 0),
            { $0.textAlign = .justify; $0.renderSize = CGSize(width: 100, height: 400); $0.note = fontDependent })
        for align in STDirectionAlign.allCases {
            add(.make("lrTb-direction-align-\(align)", "あいうえおか", charsPerLine: 4),
                { $0.directionAlign = align; $0.renderSize = CGSize(width: 64, height: 100) })
        }

        // --- 横組み: その他 ---
        add(.make("lrTb-line-height-1.5", "あいうえおか", charsPerLine: 3)) { $0.lineHeightScale = 1.5 }
        add(.make("lrTb-single-line", "あいうえおかきく", charsPerLine: 3)) { $0.isSingleLine = true }
        add(.make("lrTb-mixed", "abc あ、い 漢字 123 😀", charsPerLine: 10), { $0.note = fontDependent })

        // --- 縦組み ---
        add(.make("tbRl-wrap", "あいうえおかきくけこさしすせそ", direction: .tbRl, charsPerLine: 6))
        add(.make("tbRl-newlines", "いち\nに\r\nさん", direction: .tbRl, charsPerLine: 8))
        add(.make("tbRl-kinsoku-not-starting", "あいうえおか、きくけこ", direction: .tbRl, charsPerLine: 6))
        add(.make("tbRl-punctuation-stone", "」「あ。」・", direction: .tbRl, charsPerLine: 20))
        add(.make("tbRl-punctuation-half", "」「あ。」・", direction: .tbRl, charsPerLine: 20)) { $0.punctuationMode = .half }
        for align in STDirectionAlign.allCases {
            add(.make("tbRl-direction-align-\(align)", "あいうえおか", direction: .tbRl, charsPerLine: 4),
                { $0.directionAlign = align; $0.renderSize = CGSize(width: 100, height: 64) })
        }

        // --- 縦組み: 縦中横・回転 ---
        add(.make("tbRl-tate-chu-yoko", "第12章と第345章", direction: .tbRl, charsPerLine: 10), { $0.note = fontDependent })
        add(.make("tbRl-tate-chu-yoko-off", "第12章と第345章", direction: .tbRl, charsPerLine: 10),
            { $0.isAllowedTateChuYoko = false; $0.note = fontDependent })
        add(.make("tbRl-rotated-latin", "あABC漢", direction: .tbRl, charsPerLine: 10), { $0.note = fontDependent })
        add(.make("tbRl-emoji", "あ😀漢🇯🇵", direction: .tbRl, charsPerLine: 10),
            { $0.note = fontDependent + "（絵文字は反転描画のため position が枡の中央基準になる）" })

        // --- ルビ ---
        //
        // 読みは行の上の余白に組まれるので、行間を詰めたままだと上の行に
        // 食い込む。1.5 はちょうど半分の読みが収まる高さ
        let rubyLineHeight: CGFloat = 1.5

        add(.make("lrTb-ruby-braces", "今日は{晴天|せいてん}なり", charsPerLine: 10),
            { $0.rubyNotation = .braces; $0.lineHeightScale = rubyLineHeight })
        add(.make("lrTb-ruby-aozora", "今日は晴天《せいてん》なり", charsPerLine: 10),
            { $0.rubyNotation = .aozora; $0.lineHeightScale = rubyLineHeight })
        add(.make("lrTb-ruby-mono", "{消|しょう}{防|ぼう}{士|し}", charsPerLine: 10),
            { $0.rubyNotation = .braces; $0.lineHeightScale = rubyLineHeight;
              $0.note = "1 文字ずつ読みが付く語。組が続けて並ぶ" })
        add(.make("lrTb-ruby-wider-reading", "{空|からっぽ}", charsPerLine: 10),
            { $0.rubyNotation = .braces; $0.lineHeightScale = rubyLineHeight;
              $0.note = "読みのほうが長い場合。広いほうが幅を決め、狭いほうが中に寄る" })
        add(.make("lrTb-ruby-wrap", "{晴天|せいてん}{曇天|どんてん}", charsPerLine: 4),
            { $0.rubyNotation = .braces; $0.lineHeightScale = rubyLineHeight;
              $0.note = "語と読みは割らずに次の行へ送る" })
        add(.make("lrTb-ruby-font-scale", "{晴天|せいてん}", charsPerLine: 10),
            { $0.rubyNotation = .braces; $0.lineHeightScale = rubyLineHeight;
              $0.rubyFontScale = 0.25 })
        add(.make("lrTb-ruby-malformed", "設定{を開く", charsPerLine: 10),
            { $0.rubyNotation = .braces; $0.lineHeightScale = rubyLineHeight;
              $0.note = "組になっていない括弧。書かれたとおりに組まれる" })

        add(.make("tbRl-ruby-braces", "今日は{晴天|せいてん}なり", direction: .tbRl, charsPerLine: 10),
            { $0.rubyNotation = .braces; $0.lineHeightScale = rubyLineHeight })
        add(.make("tbRl-ruby-aozora", "今日は晴天《せいてん》なり", direction: .tbRl, charsPerLine: 10),
            { $0.rubyNotation = .aozora; $0.lineHeightScale = rubyLineHeight })
        add(.make("tbRl-ruby-wrap", "{晴天|せいてん}{曇天|どんてん}", direction: .tbRl, charsPerLine: 4),
            { $0.rubyNotation = .braces; $0.lineHeightScale = rubyLineHeight;
              $0.note = "語と読みは割らずに次の行へ送る" })

        // --- 行数制限と省略記号 ---
        add(.make("lrTb-max-line-count", "あいうえおかきくけこさしすせそ", charsPerLine: 3),
            { $0.maxLineCount = 2; $0.note = "3 行目から先は組まれるが描かれない" })
        add(.make("lrTb-max-line-count-ellipsis", "あいうえおかきくけこさしすせそ", charsPerLine: 3),
            { $0.maxLineCount = 2; $0.isShownEllipsis = true })
        add(.make("lrTb-ellipsis-single-line", "あいうえおかきくけこ", charsPerLine: 3),
            { $0.maxLineCount = 1; $0.isShownEllipsis = true })
        add(.make("lrTb-max-line-count-fits", "あいうえ", charsPerLine: 10),
            { $0.maxLineCount = 3; $0.isShownEllipsis = true;
              $0.note = "収まっているので何も落とさず、記号も出ない" })
        add(.make("lrTb-ellipsis-over-ruby", "{晴天|せいてん}{曇天|どんてん}", charsPerLine: 3),
            { $0.rubyNotation = .braces; $0.lineHeightScale = 1.5;
              $0.maxLineCount = 1; $0.isShownEllipsis = true;
              $0.note = "記号は読みの上には置かず、残った語に読みを寄せ直す" })

        add(.make("tbRl-max-line-count", "あいうえおかきくけこさしすせそ", direction: .tbRl, charsPerLine: 3),
            { $0.maxLineCount = 2 })
        add(.make("tbRl-max-line-count-ellipsis", "あいうえおかきくけこさしすせそ", direction: .tbRl, charsPerLine: 3),
            { $0.maxLineCount = 2; $0.isShownEllipsis = true })

        return cases
    }

    //--------------------------------------------------------------//
    // MARK: - Test
    //--------------------------------------------------------------//

    func testLayoutSnapshots() throws {
        let cases = snapshotCases

        // 名前の重複はスナップショットを黙って上書きするので弾く
        XCTAssertEqual(
            Set(cases.map(\.name)).count, cases.count,
            "スナップショットのケース名が重複している"
        )

        let actual = cases.map { STLayoutSnapshot.render($0) }.joined()
            + STLayoutSnapshot.separator + "\n"

        guard ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == nil else {
            try emitForRecording(actual, reason: "SNAPSHOT_RECORD が指定された")
            return
        }

        let expected: String
        do {
            expected = try String(contentsOf: Self.baselineURL, encoding: .utf8)
        }
        catch {
            try emitForRecording(actual, reason: "期待値ファイルが読めない: \(error.localizedDescription)")
            XCTFail("期待値 \(Self.baselineURL.path) が読めない。上のログの手順で記録すること")
            return
        }

        guard actual != expected else { return }

        try emitForRecording(actual, reason: "レイアウト結果が期待値と違う")
        XCTFail("レイアウトが変わった: " + Self.firstDifference(expected: expected, actual: actual))
    }

    //--------------------------------------------------------------//
    // MARK: - Baseline
    //--------------------------------------------------------------//

    /// フォントの測定値が異なるので、期待値はプラットフォームごとに持つ。
    private static var snapshotPlatform: String {
        #if os(iOS)
        return "iOS"
        #else
        return "macOS"
        #endif
    }

    /// 期待値ファイルの場所。テストはサンドボックス内で動くので読み込み専用。
    private static var baselineURL: URL {
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__")
            .appendingPathComponent(snapshotPlatform)
            .appendingPathComponent(baselineName)
    }

    /// 新しい内容を一時ファイルに書き出し、期待値へコピーする手順をログと添付に残す。
    private func emitForRecording(_ actual: String, reason: String) throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("stone-layout-snapshot.txt")
        try actual.write(to: url, atomically: true, encoding: .utf8)

        let attachment = XCTAttachment(string: actual)
        attachment.name = "layout-snapshot"
        attachment.lifetime = .keepAlways
        add(attachment)

        // 記録モードでは本文もログへ出す。アプリはサンドボックスの中にいて、
        // その一時ディレクトリが外から読めない環境があるため、ログが
        // 期待値を取り出す唯一の経路になることがある。
        if ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] != nil {
            for line in actual.split(separator: "\n", omittingEmptySubsequences: false) {
                print("§\(line)")
            }
        }

        print("""

        ############ スナップショット記録 ############
        理由: \(reason)
        新しい内容: \(url.path)
        期待値を更新するには:

            cp '\(url.path)' '\(Self.baselineURL.path)'

        #############################################

        """)
    }

    /// 最初に食い違った行の前後を、どのケースの中かも添えて返す。
    private static func firstDifference(expected: String, actual: String) -> String {
        let expectedLines = expected.components(separatedBy: "\n")
        let actualLines = actual.components(separatedBy: "\n")

        for index in 0 ..< max(expectedLines.count, actualLines.count) {
            let expectedLine = index < expectedLines.count ? expectedLines[index] : "(なし)"
            let actualLine = index < actualLines.count ? actualLines[index] : "(なし)"
            guard expectedLine != actualLine else { continue }

            // 直近の CASE 見出しを探す
            var caseName = "(不明)"
            for back in stride(from: min(index, expectedLines.count - 1), through: 0, by: -1) {
                if expectedLines[back].hasPrefix("CASE ") {
                    caseName = String(expectedLines[back].dropFirst(5))
                    break
                }
            }

            // 1 行に収める。xcodebuild のログは行単位で拾われるので、
            // 複数行にすると grep から肝心の中身がこぼれる
            return "CASE \(caseName) の \(index + 1) 行目"
                + " | 期待: \(expectedLine.trimmed)"
                + " | 実際: \(actualLine.trimmed)"
                + " | 全体はログの記録パスか添付 layout-snapshot を参照"
        }

        return "行単位の差分は見つからなかった（末尾の改行の違いなど）"
    }
}

extension String {
    fileprivate var trimmed: String {
        return trimmingCharacters(in: .whitespaces)
    }
}
