# 変更履歴

## 0.6.2

### 追加

- `minimumLineHeightScale`を追加。行を何倍の高さにすれば文字が切れないかを返す
  - `STFontManager`と、`STLabel`から読める
  - 多くの書体はemより背が高く、`lineHeightScale`が1.0だと足もとが切れる。Chalkboard SEは1.41emあり、4割が失われる
  - 切れても何も言わない。組版も寸法も言われた行の高さで行われ、はみ出すのは描画だけのため
  - 字母の先頭に置いた書体で測る。後ろの書体は、前の書体にグリフが無い文字のためだけに使われる
  - 絵文字は数に入れない。絵文字は行のem箱に収めて中央に置いているので、どれだけ背が高くても行の高さを要求しない
  - ルビの分は入っていない。読みは行が文字の上に残した余白に組まれるので、使うならこの値に足す

## 0.6.1

### 追加

- 文字の出現のしかたを増やした。`STRevealAnimation`に次を足した
  - `.pop`は小さく出て、原寸を少し行き過ぎてから収まる
  - `.rise`は潰れた字が、置かれる場所の足もとから立ち上がる
  - `.drop`は上から落ちてくる。落下なので加速する。ほかは着地で減速する
  - `.spin`は中心で半回転しながら、小さく出て原寸に戻る
  - `.flip`は真横を向いた状態から正面へ開く。裏面は通さない。文字の鏡像が見えるのは読み物として具合が悪いため
  - `.flyIn`は一方から滑り込んで止まる
- `.flyIn`がどこから来るかを`STContext.revealOrigin`で指定する。既定は`.bottom`
  - 辺が四つ（`.top` / `.bottom` / `.left` / `.right`）と、角が四つ（`.topLeft` / `.topRight` / `.bottomLeft` / `.bottomRight`）
  - 角からは縦横とも満額動かす。移動量を辺の場合に揃えると、角ではなく辺の途中から出てくることになるため
  - 画面の上下左右であって、行の進む向きではない。読み始める側は次の文字が現れる側でもあるので、そこから出すとほとんど動かない効果になる。同じ理由で`.rise`は常に下から、`.drop`は常に上から
- 読みを、読まれる語といっしょに動かすようにした
  - 位置も大きさも、読み自身の枠ではなく語の枠を基準に変える
  - 読み自身の小さい枠を中心に拡大すると、読みが語から離れて飛ぶ
  - `.fade`では起きない。字を動かす効果を入れた時点で出てくる問題である

### 内部

- 効果を`STRevealAnimation.drawing(progress:anchor:origin:)`にまとめた。不透明度とアフィン変換を返し、描画側はそれを当てるだけになっている
  - 効果を足すときに触るのは`STReveal.swift`だけで、iOSとmacOSの描画は変わらない
  - 字の移動量は、置かれる場所の0.8倍までに収めている。描画は本文の周りを一行ぶんだけ広げた範囲で間引いているので、それより外から来る字は視界に入るまで描かれない

## 0.6.0

### 追加

- 本文を先頭から一文字ずつ出す表示に対応。`STLabel.revealAnimation`、`revealedCharacterCount`、`revealDuration`で指定する
  - 出現のしかたは`STRevealAnimation`で決める。`.none`はそのまま出る、`.fade`は無色から文字色まで立ち上がる
  - `revealedCharacterCount`の既定は`Int.max`、`revealAnimation`の既定は`.none`。指定しなければ、これまでどおり本文がそのまま出る
  - 送る速さを決めるのは呼び出し側である。エンジンが受け持つのは、いま届いた一文字をどう出すかだけ
  - 組み直しは起きない。本文は最初から最後まで組んであり、変わるのは描くところだけ。文字列を途中で切って渡す方法と違い、文字が増えても改行位置が動かない
  - 読みは語と同時に出る。語の先頭の文字が出るとき、その語の読みも一緒に出る。語が出終わるのを待つと、読みが語より後から来てしまうため
  - 読みは文字に数えない。`{晴天|せいてん}`は2文字である
  - 縁取りも文字と一緒に出る
  - `STLabel`と`StoneEngineSwiftUI.STLabelView`から指定できる
- `STContext.revealCharacterCount(of:rubyNotation:)`を追加。`revealedCharacterCount`の上限を求める
  - 組む前に答えが要るので、ラベルの値ではなく型メソッドにした。送る側は、一文字も出さないうちに終わりを知る必要がある
  - 読みも記法の記号も数に入れない
- サンプルに`StoneEngineRevealSample`ターゲットを追加。文字を一つずつ出す振る舞いを見るためのもの
  - ルビのあり／なし、組み方向、出現のしかたを切り替えられる
  - 送りは自動で進むほか、スライダで一文字ずつ動かせる。出現の途中で止めて、その一文字を見るため
- サンプルのプロジェクトに共有スキームを追加。入っていなかったため、clone しただけでは起動できなかった

### 削除

- UIKitのサンプル（`sample/stone.xcodeproj`）を削除
  - シーン以前のライフサイクルのままで、iOS 26 SDKでビルドすると起動しない状態だった
  - 同じ内容は`sample/SwiftUI`のサンプルで見られる
  - これをビルドしていたCIのジョブも外した

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
