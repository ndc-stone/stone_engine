# 変更履歴

## 0.3.0

### 追加

- SwiftUI用のライブラリ`StoneEngineSwiftUI`を追加（`STLabelView`、`STTextEditor`）
- iOSの`STTextView`に、本文の変更を伝える`STTextView.textChanged`通知を追加
- iOS / macOS共通のSwiftUIサンプルを`sample/SwiftUI`に追加

### 修正

- `STTextView.text`を短くしたとき、選択範囲が本文の外に残ってクラッシュすることがある不具合を修正

## 0.2.1

### 追加

- `STContext`、`STParser`、`STLayout`を公開し、印刷などでエンジンを直接使えるように変更
- `STFontManager`のフォント指定と取得のメソッドを公開
- `STTextRange.range`、`STIsAlnum`を公開
- `STTextView`のスクロール位置、選択範囲の表示、置換、選択解除のメソッドを公開
- `STTextView`、`STKnobView`、`STCursorView`の一部をサブクラスで上書きできるように変更

## 0.2.0

### 互換性のない変更

- 最低対応OSをiOS 17 / macOS 14に変更
- `swift-tools-version`を5.9に変更
- `STRun.char`を削除（文字は`STContext.runChars`から取得する）
- サンプルのプロジェクトを`sample/stone.xcodeproj`へ移動

### 追加

- macOSに対応
- `STTextView(frame:)`を公開
- `STLabel.renderSize(forBounds:)`を追加
- macOSの`STCursorView`に`color`を追加
- テストとGitHub ActionsのCIを追加

### 修正

- 全置換で文末の一致が置換されない不具合を修正
- 縦書きでスクロール位置を行にそろえる処理を修正
- 短い行の末尾より先を選んだとき、隣の行ではなくその行の末尾を選ぶように修正
- macOSの変換候補ウィンドウの位置を修正

### 性能

- スクロール時に不要な再レイアウトと再描画をしないように改善
- 描画範囲にかかる文字だけを描くように改善
