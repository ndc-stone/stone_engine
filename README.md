stone_engineは、日本語の文字組版を実現する、iOS / macOS向けのテキストレンダリングエンジンである。

## 対応環境

- iOS 17以降
- macOS 14以降
- Swift 5.9以降

## 導入

Swift Package Managerで導入する。`Package.swift`に次を追加する。

```swift
dependencies: [
    .package(url: "https://github.com/ndc-stone/stone_engine.git", from: "0.3.0"),
],
targets: [
    .target(name: "YourApp", dependencies: ["stone_engine"]),
]
```

Xcodeでは、File > Add Package Dependencies...から同じURLを指定する。

## 使い方

```swift
import stone_engine

let textView = STTextView(frame: view.bounds)
textView.direction = .tbRl  // 縦書き
textView.fontSize = 17
textView.lineHeightScale = 1.625
textView.text = "吾輩は猫である。名前はまだ無い。"
view.addSubview(textView)
```

縦書きで表示範囲の両端の行を欠けずに表示するには、`STTextView`の幅を行送り（`fontSize * lineHeightScale`）の整数倍にする。

UIKitのサンプルアプリは`sample/stone.xcodeproj`に、iOS / macOS共通のSwiftUIサンプルは`sample/SwiftUI/StoneEngineSwiftUISample.xcodeproj`にある。

### SwiftUI

SwiftUIでは、`StoneEngineSwiftUI`を使う。ターゲットの依存関係に追加する。

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "StoneEngineSwiftUI", package: "stone_engine"),
    ]
)
```

```swift
import SwiftUI
import StoneEngineSwiftUI
import stone_engine

struct ContentView: View {
    @State private var text = "吾輩は猫である。名前はまだ無い。"

    var body: some View {
        VStack {
            STLabelView(text, direction: .lrTb, fontSize: 17)
            STTextEditor(text: $text, direction: .tbRl, fontSize: 17, lineHeightScale: 1.625)
        }
    }
}
```

`STTextEditor`は、両端の行が欠けないよう、行を重ねる方向の大きさを行送りの整数倍にする。日本語の変換中は、バインディング側の変更で本文を上書きしない。

## 目的

stone_engineは、iOSおよびmacOS上で動作するテキストレンダリングエンジンである。
その第一義の目的は、日本語の高度な組版を実現することである。具体的には、縦書き、禁則処理、約物処理、文字種ごとのスケーリングが挙げられる。
また従来の紙媒体によるページ分割を前提とした組版とは違い、電子媒体による大きさに制約のない画面上での組版を模索するものである。

副次的な目的として、プログラマにとって直接内部構造を触ることのできるレンダリングエンジンがほしい、という欲求がある。
あらゆるOSやプラットフォームにとって、テキストのレンダリングとは極めて基本的な機能の一つであり、十分な機能のものがすでに与えられている。
iOSであれば、UIKitのUILabelやUITextView、Swift UIのTextなどがそれにあたる。
それらは使い勝手は問題ないものであるが、その一方で高度にブラックボックス化されており、内部情報に十分にアクセスすることはできない。
たとえば、UILabelで、文字ごとにそれがframeのどこにレイアウトされているか、という情報を得ることはできない。
プログラマであるならば、それらの情報にアクセスできることで、どれだけの可能性が広がるか想像できるだろう。

そのような、ある種トイボックスとして使えるようなレンダリングエンジンを提供することが、隠された目的である。

## 方針

上述の目的のために、以下の方針を定める。

### アプリのための日本語文字組版

電子媒体、中でもアプリに特化した日本語文字組版のあるべき姿を模索する。
紙媒体と比較して、アプリで使われる画面には、以下の特徴がある。

- 画面サイズが不定
- 実行中にサイズが変更される
- スクロールにより極端に広くなる
- ページングの不在

これらの条件下で、あるべき組版のありかたとその実装を実現する。

### 実行速度を最優先

テキストレンダリングエンジンは、low levelの機能である。
あらゆるアプリの基底として使われるものであり、そこには高い実行速度が求められる。
stone_engineは、実行速度を最優先として、そのアーキテクチャ、データ構成、使用言語などを決めていく。

## 提供クラス

stone_engineは、`STLabel`と`STTextView`というクラスを提供する。これは、UIKitやAppKitにおけるラベルとテキストビューを置き換えることを意図している。

## STLabel

STLabelは、画面にテキストを表示するためのビュークラスである。編集はできない。次のような特徴を有する。

### 文字描画方向の指定

文字を描画する方向として、`LrTb`または`TbRl`を指定できる。TbRlは、いわゆる縦書き表示である。

| <img width="480" src="https://github.com/user-attachments/assets/bc779d89-a96a-4235-80b5-332cc18e1f8a"> |
|:--:|
| `LrTb`（横書き表示） |

| <img width="240" src="https://github.com/user-attachments/assets/dc5979e9-dd17-4b9e-9da6-8a8156f899bf"> |
|:--:|
| `TbRl`（縦書き表示） |

### 縦書き表示

縦書き表示では、フォントを描画するときに適切なグリフが選択される。たとえば、句読点、括弧などに適用される。

数字を表示するときは、いわゆる縦中横が反映される。数字が2桁以下のときは、正体で表示される。2桁より大きいとは、90度回転して表示される。

アルファベットは、90度回転して表示される。

| <img width="60" src="https://github.com/user-attachments/assets/47a5b36a-cbfe-435c-8910-27042b73e6de"> |
|:--:|
| 数字の縦中横表示と、アルファベットの90度回転表示 |


### 禁則処理

禁則処理は、行頭禁則および行禁則が行われる。禁則の対象となる文字種を指定可能である。

禁則処理の、オン／オフを指定することが可能である。

### 約物半角

約物（句読点や括弧類）を、半角で表示させることができる。約物の取り扱い方を、以下のモードで指定することができる。

- 常に全角
- 常に半角
- 前後の文字種や行中の位置で、適切に判断する（stoneモード）

| <img width="640" src="https://github.com/user-attachments/assets/8cd0b639-976c-4091-8dc3-d08f2fb480b4"> |
|:--:|
| 常に全角 |

| <img width="640" src="https://github.com/user-attachments/assets/4467fd22-75e7-4038-b852-20612f462edf"> |
|:--:|
| 常に半角 |

| <img width="640" src="https://github.com/user-attachments/assets/b82a28f8-58cc-43eb-9c2d-3b34eed3006c"> |
|:--:|
| stoneモード |

### フォントの指定

STLabelでは、文字種ごとにフォントを指定することが可能である。

| <img width="640" src="https://github.com/user-attachments/assets/efad8041-4e26-4165-acca-13feb3b6d3b8"> |
|:--:|
| 日本語フォント：游明朝<br>ラテン文字フォント：Times New Roman |

| <img width="640" src="https://github.com/user-attachments/assets/a19c165a-bde1-4cd4-9943-7666c26f85c6"> |
|:--:|
| 日本語フォント：游ゴシック<br>ラテン文字フォント：Helvetica |

指定可能な文字種は、Unicodeカテゴリとして定義される。

### 文字種ごとのスケーリング

STLabelでは、文字種ごとに表示するスケールを指定することが可能である。たとえば、日本語フォントとして1.0、ラテン文字フォントとして0.9を指定すると、次のような描画になる。

| <img width="480" src="https://github.com/user-attachments/assets/39372f77-960c-4d41-90f5-528da494a730"> |
|:--:|
| 日本語フォントスケール：1.0<br>ラテン文字フォントスケール：0.9 |

### 文字寄せ

文字寄せとして、以下が指定可能である。

- 行頭
- 中央
- 行末
- 均等

### 単語分割

日本語単語分割のオン／オフを指定することができる。これは、改行を行うときに単語を分割するか、しないかを決定するものである。

### ルビ

本文に書き込まれた読みを、横組みでは語の上に、縦組みでは語の右に組むことができる。

既定ではルビを読まない。`rubyNotation`で記法を指定したときだけ、本文から読みを取り出して組む。指定しなければ、記法に使う記号もただの文字として組まれる。

```swift
let label = STLabel(frame: view.bounds)
label.rubyNotation = .braces
label.lineHeightScale = 1.5
label.text = "今日は{晴天|せいてん}なり"
```

SwiftUIでは`STLabelView`の引数で指定する。

```swift
STLabelView("今日は{晴天|せいてん}なり", rubyNotation: .braces)
```

**読みは行の上の余白に組まれる。** `lineHeightScale`が1.0のままだと、読みが上の行に食い込むか、上端で切れる。本文の半分の大きさの読みであれば1.5で収まる。`STLabelView`の既定は1.5なので、そのままでよい。

#### 記法

| 指定 | 書き方 |
|:--|:--|
| `.none`（既定） | ルビを読まない |
| `.aozora` | `漢字《かんじ》` / `｜漢字《かんじ》` |
| `.braces` | `{漢字\|かんじ}` |

`.aozora`は青空文庫の記法である。全角の記号を使うので、ASCIIばかりの本文と取り違えにくい。

語を言わない`漢字《かんじ》`の形では、`《`の直前の文字と**同じ種別**（漢字・ひらがな・カタカナ・英数）を遡った範囲が読まれる語になる。種別が混ざる語は、`｜`で語の先頭を言う。

```
今日は漢字《かんじ》です      → 「漢字」に「かんじ」
｜お手上げ《おてあげ》        → 「お手上げ」に「おてあげ」
そこでかんじ《・・・》        → 「そこでかんじ」全体が語になる（｜ を使う）
```

`.braces`は全角の記号を打たずに書ける代わりに、`{`も`|`も普通の文に出る文字を使う。`\{`と書いた括弧は組を始めない。

#### 組として成り立たない書き方

**組になっていない文字列は、1文字も変えずに組む。** 閉じ忘れた括弧が以降を飲み込むようなことはしない。

```
設定{を開く            → そのまま「設定{を開く」
温度は{25}度           → そのまま（区切りがない）
x = {1, 2} | y         → そのまま
漢字《かんじ            → そのまま（閉じていない）
```

読みが空の組（`{漢字|}`）は、語だけが組まれてルビにならない。書きかけの印であって、乗せるものがないためである。

#### 読みの大きさ

`rubyFontScale`で決める。既定は本文の半分（0.5）。

語と読みは、広いほうが幅（縦組みでは高さ）を決め、狭いほうがその中で中央に寄る。行末に収まらない組は、語と読みを割らずに次の行へ送る。

#### 自前の記法

`STContext.rubies`に`STRuby`を直接積めば、どんな記法でも組める。`STRuby`は読まれる語のランの範囲と、読みのランの範囲を持つ。


## STTextView

STTextViewは、テキストの編集を行うためのビュークラスである。STLabelが持つ特徴をすべて有する。

## 開発

テストの実行方法や、変更を提案する手順は[CONTRIBUTING.md](CONTRIBUTING.md)を参照。変更履歴は[CHANGELOG.md](CHANGELOG.md)にある。

## ライセンス

[MIT License](LICENSE)
