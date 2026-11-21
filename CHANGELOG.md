# 変更履歴

## 0.5.3

### 修正

- iOSで、書体や文字の倍率を変えても組み直されない不具合を直した
  - `STLabel`は組み直す前に、組み直す必要があるかを見る。見ているのは旗と前に組んだときの大きさだけなので、大きさの変わらない変更は旗を立てないかぎり素通りしていた
  - `setFontNames(_:script:)`と`setFontScale(_:script:)`がその旗を立てていなかった
  - グリフは前の書体のまま残り、ラベルを作り直すまで直らなかった
  - macOSは`setNeedsParseAndLayout()`を呼んでいるため、影響を受けない

## 0.5.2

### 修正

- ルビのある行の寄せがずれる不具合を直した
  - 読みは語の上（縦組みでは右）に置かれ、行の長さには関与しないが、行の長さを測るときに読みの幅まで足していた
  - 中央寄せでは読みの幅の半分だけ、行頭の側へずれていた
  - 読みが語より広いときは、語を内側へ入れて作った余白も行の長さに数えるようにした
  - 均等割りでは、読みが別のトークンとして空きを開き、語から離れていた

## 0.5.1

### 修正

- 縦組みで、既定以外のフォントを指定すると文字が空白で出る不具合を直した
  - 縦組みの字形への差し替え表はフォントごとに持つが、登録されていないフォントが最初に登録されたフォントの表を引いていた
  - グリフIDはフォントごとに違うので、別のフォントの表から引いたIDは無関係なグリフか.notdefになる
  - 横組みはこの差し替えを通らないため、影響を受けない

## 0.5.0

### 追加

- 文字の縁取りに対応。`STContext.borderColor`と`STContext.borderWidth`で指定する
  - 縁はグリフの輪郭の外側だけに描かれ、文字そのものの太さは変わらない
  - 縁は本文を塗るより先に、すべての文字について描かれる。隣の文字の上に縁が乗らないようにするため
  - 色付きのビットマップで描かれるグリフ（絵文字など）には輪郭がないため、縁取りは行われない
  - `STLabel`から`borderColor` / `borderWidth`で指定できる
- macOSの`STLabel`に、iOSにはあって抜けていたプロパティを追加
  - `textColor` / `selectedTextColor` / `punctuationMode`
  - `fontNames(script:)` / `setFontNames(_:script:)` / `fontScale(script:)` / `setFontScale(_:script:)`

### 修正

- `STFontManager`に`public init()`を追加。`open`でありながらモジュールの外から生成できなかった
- `STFontManager.fontNames(script:)`を`public`にした。`setFontNames(_:script:)`はpublicなのに、読み出す側がinternalで非対称だった

## 0.4.0

### 追加

- ルビに対応。横組みでは語の上、縦組みでは語の右に読みを組む
  - 記法は`STContext.rubyNotation`で指定する。既定は`.none`で、指定しなければ記法の記号もただの文字として組まれる
  - `.aozora`は青空文庫の記法（`漢字《かんじ》` / `｜漢字《かんじ》`）、`.braces`は`{漢字|かんじ}`
  - 組として成り立たない書き方は、1文字も変えずに組む
  - 読みの大きさは`STContext.rubyFontScale`で決める（既定は本文の半分）
  - `STLabel`と`StoneEngineSwiftUI.STLabelView`から指定できる
  - `STContext.rubies`に`STRuby`を直接積めば、自前の記法でも組める
- `STRun.fontScale`を追加。本文の大きさに対する倍率をランごとに持てるようにした
- 行数制限に対応。`STContext.maxLineCount`で組む行数を制限し、`STContext.isShownEllipsis`で切り詰めた箇所に省略記号を出す
  - 制限を超えた行は組まれたうえで描かれず、テキストが返す大きさにも入らない
  - 切り詰められたテキストは`isTruncated`が真になるので、`adjustsFontSizeToFitWidth`は指定した行数に収まるまで文字を小さくする
  - 省略記号はルビの読みの上には置かず、記号が語を切ったときは残った語に読みを寄せ直す
  - `STLabel`と`StoneEngineSwiftUI.STLabelView`から指定できる

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
