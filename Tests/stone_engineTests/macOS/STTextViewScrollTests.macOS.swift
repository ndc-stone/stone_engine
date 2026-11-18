/*
STTextViewScrollTests.swift

選択を伸ばしたときのスクロール追従の検証。

STTextRange は昇順の範囲しか持たないので、範囲だけを見ても
「利用者がどちらの端を動かしているか」は分からない。動いている端は
isCursorBeginSelected が覚えていて、scrollCursorToVisible はそちらを
追いかけなければならない。ここを取り違えると、下方向のドラッグでは
スクロールするのに上方向では動かない（範囲の上端＝固定側の
アンカーを追いかけてしまうため）。
*/

#if os(macOS)
import XCTest
@testable import stone_engine

@MainActor
final class STTextViewScrollTests: XCTestCase {

    /// 数画面ぶんの本文を持つ、スクロールできる状態のテキストビュー。
    private func makeTextView(
        direction: STDirection = .lrTb,
        size: CGSize = CGSize(width: 16 * 10, height: 16 * 6)
    ) -> STTextView {
        let textView = STTextView(frame: CGRect(origin: .zero, size: size))
        textView.fontSize = 16
        textView.direction = direction
        // 1 行 10 文字で 60 行ぶん。表示できるのは 6 行なので確実にスクロールする
        textView.text = (0 ..< 60).map { _ in "あいうえおかきくけこ" }.joined()
        textView.layoutSubtreeIfNeeded()

        return textView
    }

    /// いまのスクロール位置。
    private func scrollOrigin(_ textView: STTextView) -> CGPoint {
        return textView.contentView.bounds.origin
    }

    /// 選択範囲と「動いている端」を決めてから、スクロールを走らせる。
    private func scroll(_ textView: STTextView, to range: Range<Int>, movingBegin: Bool) {
        textView.isCursorBeginSelected = movingBegin
        textView.selectedSTTextRange = STTextRange(range: range)
        textView.scrollCursorToVisible()
        textView.layoutSubtreeIfNeeded()
    }

    //--------------------------------------------------------------//
    // MARK: - 動いている端
    //--------------------------------------------------------------//

    /// movingSelectionIndex が、動いている側の端を返すこと。
    func testMovingSelectionIndex() {
        let textView = makeTextView()

        textView.selectedSTTextRange = STTextRange(range: 100 ..< 300)

        textView.isCursorBeginSelected = false
        XCTAssertEqual(textView.movingSelectionIndex, 300, "下方向に伸ばしているとき、上端を追っていない")

        textView.isCursorBeginSelected = true
        XCTAssertEqual(textView.movingSelectionIndex, 100, "上方向に伸ばしているとき、下端を追っていない")
    }

    //--------------------------------------------------------------//
    // MARK: - 横組み
    //--------------------------------------------------------------//

    /// 選択を下へ伸ばすと下へスクロールすること。
    func testScrollsDownWhenExtendingForward() {
        let textView = makeTextView()
        let before = scrollOrigin(textView)

        scroll(textView, to: 0 ..< 500, movingBegin: false)

        XCTAssertGreaterThan(
            scrollOrigin(textView).y, before.y,
            "選択を下へ伸ばしても下にスクロールしない"
        )
    }

    /// 選択を上へ伸ばすと上へスクロールすること。
    ///
    /// これが以前の不具合。範囲の上端（＝固定側のアンカー）を追いかけていたため、
    /// 上方向のドラッグではスクロールが起きなかった。
    func testScrollsUpWhenExtendingBackward() {
        let textView = makeTextView()

        // まず末尾まで送って、下までスクロールした状態にする
        scroll(textView, to: 590 ..< 600, movingBegin: false)
        let bottom = scrollOrigin(textView)
        XCTAssertGreaterThan(bottom.y, 0, "前提が崩れた: 下までスクロールしていない")

        // ここから選択を先頭へ向かって伸ばす（動いているのは下端）
        scroll(textView, to: 0 ..< 600, movingBegin: true)

        XCTAssertLessThan(
            scrollOrigin(textView).y, bottom.y,
            "選択を上へ伸ばしても上にスクロールしない"
        )
    }

    /// 動いている端を取り違えると追従しないことの裏づけ。
    /// 同じ範囲でも、動いている端の指定が逆だとスクロールしない。
    func testAnchorEndDoesNotDriveScrolling() {
        let textView = makeTextView()

        scroll(textView, to: 590 ..< 600, movingBegin: false)
        let bottom = scrollOrigin(textView)

        // 上端（＝アンカー側の 600）を追わせると、すでに見えているので動かない
        scroll(textView, to: 0 ..< 600, movingBegin: false)

        XCTAssertEqual(
            scrollOrigin(textView).y, bottom.y, accuracy: 1.0,
            "アンカー側の端を追ったのにスクロールした（前提の理解が違う）"
        )
    }

    //--------------------------------------------------------------//
    // MARK: - 縦組み
    //--------------------------------------------------------------//

    /// 縦組みは右から左へ組むので、選択を先へ伸ばすと左へスクロールすること。
    func testScrollsLeftWhenExtendingForwardTbRl() {
        let textView = makeTextView(direction: .tbRl, size: CGSize(width: 16 * 6, height: 16 * 10))
        let before = scrollOrigin(textView)

        scroll(textView, to: 0 ..< 500, movingBegin: false)

        XCTAssertNotEqual(
            scrollOrigin(textView).x, before.x,
            "縦組みで選択を伸ばしてもスクロールしない"
        )
    }

    /// 縦組みでも、選択を戻す方向に伸ばすとスクロールが追従すること。
    func testScrollsBackWhenExtendingBackwardTbRl() {
        let textView = makeTextView(direction: .tbRl, size: CGSize(width: 16 * 6, height: 16 * 10))

        scroll(textView, to: 590 ..< 600, movingBegin: false)
        let far = scrollOrigin(textView)

        scroll(textView, to: 0 ..< 600, movingBegin: true)

        XCTAssertNotEqual(
            scrollOrigin(textView).x, far.x, accuracy: 1.0,
            "縦組みで選択を戻す方向に伸ばしてもスクロールしない"
        )
    }
}
#endif
