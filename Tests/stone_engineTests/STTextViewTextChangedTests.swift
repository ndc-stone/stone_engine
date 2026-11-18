/*
STTextViewTextChangedTests.swift

STTextView.textChanged の通知のテスト。
*/

import XCTest
@testable import stone_engine

@MainActor
final class STTextViewTextChangedTests: XCTestCase {

    private func makeTextView(text: String = "") -> STTextView {
        let textView = STTextView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        textView.label.context.fontManager.refresh()
        textView.text = text
        return textView
    }

    /// block の実行中に textView から届いた通知ごとの本文を返す。
    private func observedTexts(of textView: STTextView, during block: () -> Void) -> [String?] {
        var texts = [String?]()
        let observer = NotificationCenter.default.addObserver(
            forName: STTextView.textChanged, object: textView, queue: nil
        ) { [weak textView] _ in
            MainActor.assumeIsolated { texts.append(textView?.text) }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        block()
        return texts
    }

    func testSettingTextPostsNotification() {
        let textView = makeTextView()

        let texts = observedTexts(of: textView) { textView.text = "吾輩は猫である" }

        XCTAssertEqual(texts, ["吾輩は猫である"])
    }

    func testNotificationFromOtherTextViewIsNotObserved() {
        let textView = makeTextView()
        let other = makeTextView()

        let texts = observedTexts(of: textView) { other.text = "別のビュー" }

        XCTAssertEqual(texts, [])
    }

    func testInsertingTextPostsNotification() {
        let textView = makeTextView(text: "猫")
        textView.selectedSTTextRange = STTextRange(range: 1 ..< 1)

        let texts = observedTexts(of: textView) {
            #if os(iOS)
            textView.insertText("犬")
            #else
            textView.insertText("犬", replacementRange: NSRange(location: NSNotFound, length: 0))
            #endif
        }

        XCTAssertEqual(texts, ["猫犬"])
    }

    #if os(iOS)
    func testDeletingTextPostsNotification() {
        let textView = makeTextView(text: "猫犬")
        textView.selectedSTTextRange = STTextRange(range: 2 ..< 2)

        let texts = observedTexts(of: textView) { textView.deleteBackward() }

        XCTAssertEqual(texts, ["猫"])
    }

    func testReplacingTextPostsNotification() {
        let textView = makeTextView(text: "猫と猫")

        let texts = observedTexts(of: textView) {
            textView.replace(STTextRange(range: 0 ..< 1), withText: "犬")
        }

        XCTAssertEqual(texts, ["犬と猫"])
    }

    func testReplacingAllTextPostsNotification() {
        let textView = makeTextView(text: "猫と猫")

        let texts = observedTexts(of: textView) {
            textView.replaceAll([STTextRange(range: 0 ..< 1), STTextRange(range: 2 ..< 3)], withText: "犬")
        }

        XCTAssertEqual(texts, ["犬と犬"])
    }

    func testMarkedTextPostsNotification() {
        let textView = makeTextView()

        let texts = observedTexts(of: textView) {
            textView.setAttributedMarkedText(NSAttributedString(string: "ね"), selectedRange: NSRange(location: 1, length: 0))
        }

        XCTAssertEqual(texts.last, "ね")
    }
    #endif
}
