# stone_engineへの貢献

不具合の報告や改善の提案は、GitHubのIssueまたはPull Requestで受け付けている。

## 開発環境

- Xcode 26以降
- iOS 17以降のシミュレーター

## テスト

macOS:

```bash
swift test
```

iOS Simulator:

```bash
xcodebuild test -scheme stone_engine-Package -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)'
```

シミュレーター名は、手元にあるものに読み替える。

サンプルのビルド:

```bash
xcodebuild build -project sample/SwiftUI/StoneEngineSwiftUISample.xcodeproj -scheme StoneEngineSwiftUISample -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO
```

```bash
xcodebuild build -project sample/SwiftUI/StoneEngineSwiftUISample.xcodeproj -scheme StoneEngineRevealSample -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO
```

### スナップショット

レイアウトと描画の期待値は`Tests/stone_engineTests/__Snapshots__`に、OSごとに置いている。
意図して結果を変えたときは、記録モードでテストを実行し、ログに出るコマンドで期待値を更新する。

```bash
SNAPSHOT_RECORD=1 swift test --filter STLayoutSnapshotTests
```

```bash
SNAPSHOT_RECORD=1 swift test --filter STLabelSnapshotTests
```

iOS Simulatorで実行するときは、環境変数名を`TEST_RUNNER_SNAPSHOT_RECORD`にする。

画像の比較はOSやフォントのバージョンの影響を受ける。macOSのCIでは`SKIP_IMAGE_SNAPSHOTS=1`を指定して省略している。

### 性能の計測

計測用のテストは、既定では実行されない。

```bash
MEASURE_PERFORMANCE=1 swift test --filter STPerformanceTests
```

## Pull Request

- 1つのPull Requestには、1つの目的の変更だけを含める
- 動作を変えるときは、テストを追加または更新する
- コミットするサンプルやテストの文章は、自作のもの、または権利上問題のないものにする
- `swift test`とiOS Simulatorのテストが通ることを確認する

投稿された変更は、このリポジトリと同じ[MIT License](LICENSE)で提供されるものとする。
