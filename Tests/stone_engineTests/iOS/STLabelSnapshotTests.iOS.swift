/*
STLabelSnapshotTests.swift

STLabel の描画結果を PNG で突き合わせる。

配置のスナップショット（STLayoutSnapshotTests）は枡の座標までしか見ない。
実際にグリフがどう出るか — 縦組みの回転、絵文字の反転、選択の塗り —
は画素を見ないと分からない。

ただし画素は macOS やフォントのバージョンで動く。そこで:
  - ケース数を絞る（配置の検証は既にテキストのスナップショットが担っている）
  - 完全一致ではなく、食い違った画素の割合で判定する
  - 環境変数で丸ごと飛ばせるようにする（フォントが変わった環境や CI 向け）

期待値の更新（記録モード）:
    TEST_RUNNER_SNAPSHOT_RECORD=1 xcodebuild test -scheme stone_engine \
        -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' \
        -only-testing:stone_engineTests/STLabelSnapshotTests
  新しい PNG を一時ディレクトリに書き出し、期待値へコピーするコマンドをログに出す。

まるごと飛ばす:
    TEST_RUNNER_SKIP_IMAGE_SNAPSHOTS=1 xcodebuild test ...
*/

#if os(iOS)
import XCTest
@testable import stone_engine

final class STLabelSnapshotTests: STLabelRenderTestCase {

    /// 食い違ってよい画素の割合。アンチエイリアスのわずかな差を吸収しつつ、
    /// グリフが 1 つ変わればはっきり超える。
    private let tolerance = 0.02

    /// 画素が違うとみなすチャンネル差（0...1）。比較は STTestBitmap が行う。
    private let channelThreshold: CGFloat = 0.1

    //--------------------------------------------------------------//
    // MARK: - Cases
    //--------------------------------------------------------------//

    private struct Case {
        let name: String
        let make: (STLabelSnapshotTests) -> STLabel
    }

    private var cases: [Case] {
        let size = CGSize(width: 16 * 8, height: 16 * 4)
        return [
            Case(name: "lrTb-japanese") { test in
                test.makeLabel(text: "吾輩は猫である。名前はまだ無い。", size: size)
            },
            Case(name: "lrTb-brackets") { test in
                test.makeLabel(text: "「こんにちは」と、彼は言った。", size: size)
            },
            Case(name: "tbRl-japanese") { test in
                test.makeLabel(text: "吾輩は猫である。名前はまだ無い。", size: size, direction: .tbRl)
            },
            Case(name: "tbRl-rotated-latin") { test in
                // ラテンは縦組みで時計回りに倒される
                test.makeLabel(text: "あABC漢", size: size, direction: .tbRl)
            },
            Case(name: "tbRl-tate-chu-yoko") { test in
                test.makeLabel(text: "第12章と第345章", size: size, direction: .tbRl)
            },
            Case(name: "tbRl-emoji") { test in
                // 絵文字は反転描画の経路を通る
                test.makeLabel(text: "あ😀漢🇯🇵", size: size, direction: .tbRl)
            },
        ]
    }

    //--------------------------------------------------------------//
    // MARK: - Test
    //--------------------------------------------------------------//

    func testLabelSnapshots() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["SKIP_IMAGE_SNAPSHOTS"] != nil,
            "SKIP_IMAGE_SNAPSHOTS が指定された"
        )

        let isRecording = ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] != nil
        var recorded = [String]()

        for item in cases {
            let bitmap = try render(item.make(self))
            let actual = try XCTUnwrap(
                bitmap.pngData(),
                "\(item.name): PNG に変換できない"
            )

            guard !isRecording else {
                try write(actual, name: item.name, into: &recorded)
                continue
            }

            let url = Self.baselineURL(name: item.name)
            guard let expectedData = try? Data(contentsOf: url),
                  let expected = STTestBitmap.from(pngData: expectedData) else {
                try write(actual, name: item.name, into: &recorded)
                XCTFail("\(item.name): 期待値 \(url.lastPathComponent) が読めない。ログの手順で記録すること")
                continue
            }

            let difference = bitmap.differenceRatio(from: expected, threshold: channelThreshold)
            if difference.ratio > tolerance {
                try write(actual, name: item.name, into: &recorded)
                add(attachment(actual, name: "actual-\(item.name)"))
                add(attachment(expectedData, name: "expected-\(item.name)"))
                XCTFail(
                    "\(item.name): 描画が変わった"
                        + "（食い違い \(String(format: "%.2f", difference.ratio * 100))% / 許容 \(String(format: "%.2f", tolerance * 100))%"
                        + "\(difference.note.map { " — \($0)" } ?? "")）"
                )
            }
        }

        if !recorded.isEmpty {
            printRecordingInstructions(recorded)
        }
    }

    //--------------------------------------------------------------//
    // MARK: - Baseline
    //--------------------------------------------------------------//

    private static func baselineURL(name: String) -> URL {
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__")
            .appendingPathComponent("iOS")
            .appendingPathComponent("images")
            .appendingPathComponent("\(name).png")
    }

    private var recordingDirectory: URL {
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("stone-label-snapshots")
    }

    private func write(_ data: Data, name: String, into recorded: inout [String]) throws {
        try FileManager.default.createDirectory(at: recordingDirectory, withIntermediateDirectories: true)
        try data.write(to: recordingDirectory.appendingPathComponent("\(name).png"))
        recorded.append(name)
    }

    private func attachment(_ data: Data, name: String) -> XCTAttachment {
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        return attachment
    }

    private func printRecordingInstructions(_ recorded: [String]) {
        let destination = Self.baselineURL(name: "X").deletingLastPathComponent()
        print("""

        ############ 画像スナップショット記録 ############
        更新されたケース: \(recorded.joined(separator: ", "))
        期待値を更新するには:

            cp '\(recordingDirectory.path)'/*.png '\(destination.path)/'

        #################################################

        """)
    }
}
#endif
