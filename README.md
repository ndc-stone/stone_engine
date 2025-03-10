stone_engineは、日本語の文字組版を実現する、テキストレンダリングエンジンである。

## 提供クラス

stone_engineは、`STLabel`と`STTextView`というクラスを提供する。これは、UI KitにおけるUILabelとUITextViewを置き換えることを意図している。

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


## STTextView

STTextViewは、テキストの編集を行うためのビュークラスである。STLabelが持つ特徴をすべて有する。

