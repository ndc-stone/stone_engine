/*
STTextViewSelectionTests.swift

本文が短くなったときに、選択範囲と変換中の範囲が本文の外に残らないことのテスト。
*/

import XCTest
@testable import stone_engine

@MainActor
final class STTextViewSelectionTests: XCTestCase {

    private func makeTextView(text: String) -> STTextView {
        let textView = STTextView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        textView.label.context.fontManager.refresh()
        textView.text = text
        layout(textView)
        return textView
    }

    private func layout(_ textView: STTextView) {
        #if os(iOS)
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        #else
        textView.needsLayout = true
        textView.layoutSubtreeIfNeeded()
        #endif
    }

    func testSelectionIsKeptInShorterText() {
        let textView = makeTextView(text: "吾輩は猫である")
        textView.selectedSTTextRange = STTextRange(range: 5 ..< 7)

        textView.text = "猫"
        layout(textView)

        XCTAssertEqual(textView.selectedSTTextRange.range, 1 ..< 1)
    }

    func testSelectionPartlyInShorterTextIsCut() {
        let textView = makeTextView(text: "吾輩は猫である")
        textView.selectedSTTextRange = STTextRange(range: 1 ..< 7)

        textView.text = "吾輩は"
        layout(textView)

        XCTAssertEqual(textView.selectedSTTextRange.range, 1 ..< 3)
    }

    func testSelectionInTextIsNotChanged() {
        let textView = makeTextView(text: "吾輩は猫である")
        textView.selectedSTTextRange = STTextRange(range: 1 ..< 2)

        textView.text = "吾輩は"

        XCTAssertEqual(textView.selectedSTTextRange.range, 1 ..< 2)
    }

    func testClearingTextResetsSelection() {
        let textView = makeTextView(text: "吾輩は猫である")
        textView.selectedSTTextRange = STTextRange(range: 7 ..< 7)

        textView.text = nil
        layout(textView)

        XCTAssertEqual(textView.selectedSTTextRange.range, 0 ..< 0)
    }

    func testMarkedRangeIsKeptInShorterText() throws {
        let textView = makeTextView(text: "吾輩は猫である")
        textView.markedSTTextRange = STTextRange(range: 5 ..< 7)

        textView.text = "猫"

        XCTAssertEqual(try XCTUnwrap(textView.markedSTTextRange).range, 1 ..< 1)
    }

    func testCharacterCountIsUsedForRanges() {
        let textView = makeTextView(text: "👨‍👩‍👧猫")
        textView.selectedSTTextRange = STTextRange(range: 2 ..< 2)

        textView.text = "👨‍👩‍👧"
        layout(textView)

        XCTAssertEqual(textView.selectedSTTextRange.range, 1 ..< 1)
    }
}
