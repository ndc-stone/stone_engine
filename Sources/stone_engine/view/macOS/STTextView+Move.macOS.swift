/*
STTextView+Move.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2026 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(macOS)
import Cocoa

// Moves and deletions by units larger than a character or a line: the line's
// ends, paragraphs, words, pages and the whole document, plus scrolling.
//
// Like the arrow keys, these commands are logical, not on screen. For vertical
// writing AppKit turns the keys a quarter before sending them: command-up arrives
// as moveToLeftEndOfLine, the top of the column, and command-left as
// moveToEndOfDocument. So nothing here looks at the direction, except scrolling,
// which moves the view on screen.
extension STTextView {
    //--------------------------------------------------------------//
    // MARK: - Helpers
    //--------------------------------------------------------------//

    // The number of characters, which is where the caret goes at the end
    private var characterCount: Int {
        return text?.count ?? 0
    }

    // The index a move starts from. Extending the selection moves its moving end;
    // otherwise a move forward starts from the end of the selection and a move
    // backward from its beginning.
    private func moveBaseIndex(forward: Bool, modifySelection: Bool) -> Int {
        let range = selectedSTTextRange.range
        if modifySelection && !range.isEmpty { return movingSelectionIndex }
        return forward ? range.upperBound : range.lowerBound
    }

    // The ends of the line the index is on. A line closed by a newline ends before
    // it, otherwise the caret would land at the beginning of the next line.
    private func lineEnds(at index: Int) -> (start: Int, end: Int)? {
        // Get line range
        let context = label.context
        guard let range = context.runIndexes(line: context.line(at: index)) else { return nil }

        // Decide end
        var end = range.upperBound
        if !range.isEmpty, context.runs[range.upperBound - 1].isNewline {
            end = range.upperBound - 1
        }

        return (range.lowerBound, end)
    }

    // The beginning of the paragraph the index is in, the index right after the
    // newline before it.
    private func paragraphStart(at index: Int) -> Int {
        let runs = label.context.runs
        var i = min(index, runs.count)
        while i > 0 && !runs[i - 1].isNewline {
            i -= 1
        }
        return i
    }

    // The end of the paragraph the index is in, the index of the newline closing it.
    private func paragraphEnd(at index: Int) -> Int {
        let runs = label.context.runs
        var i = max(index, 0)
        while i < runs.count && !runs[i].isNewline {
            i += 1
        }
        return i
    }

    // The words of the paragraph the index is in, in character indexes. Only the
    // paragraph is tokenized, so that a long document does not cost a keystroke
    // the whole text. Japanese has no spaces, so it takes the system tokenizer to
    // find the words.
    private func wordRanges(inParagraphAt index: Int) -> [Range<Int>] {
        // Get paragraph text
        guard let text = text else { return [] }
        let start = paragraphStart(at: index)
        let end = paragraphEnd(at: index)
        guard start < end else { return [] }
        let lower = text.index(text.startIndex, offsetBy: start)
        let upper = text.index(lower, offsetBy: end - start)
        let paragraph = String(text[lower ..< upper])

        // Map UTF-16 offsets to character indexes
        var characterIndexes = [Int]()
        for (i, character) in paragraph.enumerated() {
            for _ in 0 ..< character.utf16.count {
                characterIndexes.append(i)
            }
        }
        characterIndexes.append(paragraph.count)

        // Tokenize
        let string = paragraph as CFString
        let tokenizer = CFStringTokenizerCreate(
            nil, string, CFRange(location: 0, length: CFStringGetLength(string)),
            kCFStringTokenizerUnitWord, CFLocaleCreate(nil, CFLocaleIdentifier("ja" as CFString))
        )
        var ranges = [Range<Int>]()
        while CFStringTokenizerAdvanceToNextToken(tokenizer) != [] {
            let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            let lowerIndex = characterIndexes[range.location]
            let upperIndex = characterIndexes[range.location + range.length]
            guard lowerIndex < upperIndex else { continue }
            ranges.append(start + lowerIndex ..< start + upperIndex)
        }

        return ranges
    }

    // The end of the word at or after the index, going over paragraphs, or the end
    // of the text when no word follows.
    private func wordEnd(after index: Int) -> Int {
        let count = characterCount
        var index = index
        while index < count {
            // Find in the paragraph
            if let word = wordRanges(inParagraphAt: index).first(where: { $0.upperBound > index }) {
                return word.upperBound
            }

            // Go to the next paragraph
            index = paragraphEnd(at: index) + 1
        }
        return count
    }

    // The beginning of the word at or before the index, going over paragraphs, or
    // the beginning of the text when no word precedes.
    private func wordStart(before index: Int) -> Int {
        var index = index
        while index > 0 {
            // Find in the paragraph
            if let word = wordRanges(inParagraphAt: index).last(where: { $0.lowerBound < index }) {
                return word.lowerBound
            }

            // Go to the previous paragraph, onto the newline closing it
            let start = paragraphStart(at: index)
            guard start > 0 else { break }
            index = start - 1
        }
        return 0
    }

    // Lines a page moves over. One line of the page stays on screen, so the
    // reading does not lose its place.
    private var linesPerPage: Int {
        let visibleRect = documentVisibleRect
        let extent = direction == .lrTb ? visibleRect.height : visibleRect.width
        let lineHeight = label.context.lineHeight
        guard lineHeight > 0 else { return 1 }
        return max(1, Int(extent / lineHeight) - 1)
    }

    //--------------------------------------------------------------//
    // MARK: - Line
    //--------------------------------------------------------------//

    private func moveToLineEdge(end: Bool, modifySelection: Bool) {
        // Decide index
        let base = moveBaseIndex(forward: end, modifySelection: modifySelection)
        guard let ends = lineEnds(at: base) else { return }

        // Move cursor
        moveSelectionEnd(to: end ? ends.end : ends.start, modifySelection: modifySelection)
    }

    open override func moveToBeginningOfLine(_ sender: Any?) {
        moveToLineEdge(end: false, modifySelection: false)
    }

    open override func moveToBeginningOfLineAndModifySelection(_ sender: Any?) {
        moveToLineEdge(end: false, modifySelection: true)
    }

    open override func moveToEndOfLine(_ sender: Any?) {
        moveToLineEdge(end: true, modifySelection: false)
    }

    open override func moveToEndOfLineAndModifySelection(_ sender: Any?) {
        moveToLineEdge(end: true, modifySelection: true)
    }

    // The left end is where the line begins, for left to right text and for
    // vertical writing, where AppKit sends it for command-up
    open override func moveToLeftEndOfLine(_ sender: Any?) {
        moveToLineEdge(end: false, modifySelection: false)
    }

    open override func moveToLeftEndOfLineAndModifySelection(_ sender: Any?) {
        moveToLineEdge(end: false, modifySelection: true)
    }

    open override func moveToRightEndOfLine(_ sender: Any?) {
        moveToLineEdge(end: true, modifySelection: false)
    }

    open override func moveToRightEndOfLineAndModifySelection(_ sender: Any?) {
        moveToLineEdge(end: true, modifySelection: true)
    }

    //--------------------------------------------------------------//
    // MARK: - Paragraph
    //--------------------------------------------------------------//

    open override func moveToBeginningOfParagraph(_ sender: Any?) {
        let base = moveBaseIndex(forward: false, modifySelection: false)
        moveSelectionEnd(to: paragraphStart(at: base), modifySelection: false)
    }

    open override func moveToBeginningOfParagraphAndModifySelection(_ sender: Any?) {
        let base = moveBaseIndex(forward: false, modifySelection: true)
        moveSelectionEnd(to: paragraphStart(at: base), modifySelection: true)
    }

    open override func moveToEndOfParagraph(_ sender: Any?) {
        let base = moveBaseIndex(forward: true, modifySelection: false)
        moveSelectionEnd(to: paragraphEnd(at: base), modifySelection: false)
    }

    open override func moveToEndOfParagraphAndModifySelection(_ sender: Any?) {
        let base = moveBaseIndex(forward: true, modifySelection: true)
        moveSelectionEnd(to: paragraphEnd(at: base), modifySelection: true)
    }

    // Option-shift-up. From the beginning of a paragraph it goes on to the
    // beginning of the one before, so that repeating it keeps extending.
    open override func moveParagraphBackwardAndModifySelection(_ sender: Any?) {
        let base = moveBaseIndex(forward: false, modifySelection: true)
        var index = paragraphStart(at: base)
        if index == base && base > 0 {
            index = paragraphStart(at: base - 1)
        }
        moveSelectionEnd(to: index, modifySelection: true)
    }

    open override func moveParagraphForwardAndModifySelection(_ sender: Any?) {
        let base = moveBaseIndex(forward: true, modifySelection: true)
        var index = paragraphEnd(at: base)
        if index == base && base < characterCount {
            index = paragraphEnd(at: base + 1)
        }
        moveSelectionEnd(to: index, modifySelection: true)
    }

    //--------------------------------------------------------------//
    // MARK: - Word
    //--------------------------------------------------------------//

    private func moveWord(forward: Bool, modifySelection: Bool) {
        let base = moveBaseIndex(forward: forward, modifySelection: modifySelection)
        let index = forward ? wordEnd(after: base) : wordStart(before: base)
        moveSelectionEnd(to: index, modifySelection: modifySelection)
    }

    open override func moveWordForward(_ sender: Any?) {
        moveWord(forward: true, modifySelection: false)
    }

    open override func moveWordForwardAndModifySelection(_ sender: Any?) {
        moveWord(forward: true, modifySelection: true)
    }

    open override func moveWordBackward(_ sender: Any?) {
        moveWord(forward: false, modifySelection: false)
    }

    open override func moveWordBackwardAndModifySelection(_ sender: Any?) {
        moveWord(forward: false, modifySelection: true)
    }

    open override func moveWordRight(_ sender: Any?) {
        moveWord(forward: true, modifySelection: false)
    }

    open override func moveWordRightAndModifySelection(_ sender: Any?) {
        moveWord(forward: true, modifySelection: true)
    }

    open override func moveWordLeft(_ sender: Any?) {
        moveWord(forward: false, modifySelection: false)
    }

    open override func moveWordLeftAndModifySelection(_ sender: Any?) {
        moveWord(forward: false, modifySelection: true)
    }

    //--------------------------------------------------------------//
    // MARK: - Document
    //--------------------------------------------------------------//

    open override func moveToBeginningOfDocument(_ sender: Any?) {
        moveSelectionEnd(to: 0, modifySelection: false)
    }

    open override func moveToBeginningOfDocumentAndModifySelection(_ sender: Any?) {
        moveSelectionEnd(to: 0, modifySelection: true)
    }

    open override func moveToEndOfDocument(_ sender: Any?) {
        moveSelectionEnd(to: characterCount, modifySelection: false)
    }

    open override func moveToEndOfDocumentAndModifySelection(_ sender: Any?) {
        moveSelectionEnd(to: characterCount, modifySelection: true)
    }

    //--------------------------------------------------------------//
    // MARK: - Page
    //--------------------------------------------------------------//

    // Move the caret a page of lines, keeping the goal like the line moves, and
    // scroll the view as far, so the caret keeps its place on screen.
    private func moveByPage(forward: Bool, modifySelection: Bool) {
        // Collapse a selection that is not extended
        if !modifySelection && !selectedSTTextRange.range.isEmpty {
            let index = moveBaseIndex(forward: forward, modifySelection: false)
            moveCursor(lower: index, upper: index)
        }

        // Decide target line
        let context = label.context
        let lines = linesPerPage
        let line = context.line(at: movingSelectionIndex)
        let targetLine = forward ? min(line + lines, context.lineCount - 1) : max(line - lines, 0)

        // Decide index. With no page left, it goes to the end
        let index: Int
        if targetLine == line {
            index = forward ? characterCount : 0
        }
        else {
            guard let range = context.runIndexes(line: targetLine) else { return }
            index = closestRunIndexForLineMove(range: range)
        }

        // Scroll and move cursor
        scroll(byLines: forward ? targetLine - line : -(line - targetLine))
        moveSelectionEnd(to: index, modifySelection: modifySelection, keepsGoal: true)
    }

    open override func pageDown(_ sender: Any?) {
        moveByPage(forward: true, modifySelection: false)
    }

    open override func pageDownAndModifySelection(_ sender: Any?) {
        moveByPage(forward: true, modifySelection: true)
    }

    open override func pageUp(_ sender: Any?) {
        moveByPage(forward: false, modifySelection: false)
    }

    open override func pageUpAndModifySelection(_ sender: Any?) {
        moveByPage(forward: false, modifySelection: true)
    }

    //--------------------------------------------------------------//
    // MARK: - Scroll
    //--------------------------------------------------------------//

    // Scroll the view along the lines, toward the end of the text for a positive
    // count: down in horizontal writing, to the left in vertical.
    private func scroll(byLines lines: Int) {
        // Decide bounds
        var bounds = contentView.bounds
        let distance = CGFloat(lines) * label.context.lineHeight
        switch direction {
        case .lrTb: bounds.origin.y += distance
        case .tbRl: bounds.origin.x -= distance
        }

        // Scroll inside the scrollable range
        scroll(toBounds: bounds)
    }

    // Scroll to where the text begins, the top in horizontal writing and the right
    // in vertical, or to where it ends.
    private func scrollToDocumentEdge(end: Bool) {
        // Decide bounds past the edge. The clip view brings it back inside the
        // scrollable range, insets included
        var bounds = contentView.bounds
        let documentRect = contentView.documentRect
        switch direction {
        case .lrTb: bounds.origin.y = end ? documentRect.maxY : documentRect.minY - bounds.height
        case .tbRl: bounds.origin.x = end ? documentRect.minX - bounds.width : documentRect.maxX
        }

        // Scroll. Lining the edge up with a line would pull the end of the text
        // back out of view
        scroll(toBounds: bounds, snapsToLines: false)
    }

    private func scroll(toBounds bounds: CGRect, snapsToLines: Bool = true) {
        // Constrain to the scrollable range, insets included
        let bounds = contentView.constrainBoundsRect(bounds)
        guard bounds.origin != contentView.bounds.origin else { return }

        // Scroll itself
        contentView.setBoundsOrigin(bounds.origin)
        reflectScrolledClipView(contentView)

        // Show whole lines at the edge the text starts from
        if snapsToLines {
            scrollToWholeLines(animated: false)
        }
    }

    open override func scrollPageDown(_ sender: Any?) {
        scroll(byLines: linesPerPage)
    }

    open override func scrollPageUp(_ sender: Any?) {
        scroll(byLines: -linesPerPage)
    }

    open override func scrollToBeginningOfDocument(_ sender: Any?) {
        scrollToDocumentEdge(end: false)
    }

    open override func scrollToEndOfDocument(_ sender: Any?) {
        scrollToDocumentEdge(end: true)
    }

    //--------------------------------------------------------------//
    // MARK: - Deletion
    //--------------------------------------------------------------//

    // Delete from the caret to index. A selection is deleted instead, and with
    // nothing between the two, fallback deletes a character.
    private func delete(to index: Int, fallback: () -> Void) {
        // For selection
        if !selectedSTTextRange.range.isEmpty {
            replaceText("", textRange: selectedSTTextRange)
            return
        }

        // Delete between caret and index
        let caret = selectedSTTextRange.range.lowerBound
        guard index != caret else {
            fallback()
            return
        }
        replaceText("", textRange: STTextRange(range: min(index, caret) ..< max(index, caret)))
    }

    open override func deleteWordBackward(_ sender: Any?) {
        let caret = selectedSTTextRange.range.lowerBound
        delete(to: wordStart(before: caret), fallback: {})
    }

    open override func deleteWordForward(_ sender: Any?) {
        let caret = selectedSTTextRange.range.lowerBound
        delete(to: wordEnd(after: caret), fallback: {})
    }

    // At the beginning of the line, command-delete joins it to the line before
    open override func deleteToBeginningOfLine(_ sender: Any?) {
        let caret = selectedSTTextRange.range.lowerBound
        guard let ends = lineEnds(at: caret) else { return }
        delete(to: ends.start, fallback: { deleteBackward(sender) })
    }

    open override func deleteToEndOfLine(_ sender: Any?) {
        let caret = selectedSTTextRange.range.lowerBound
        guard let ends = lineEnds(at: caret) else { return }
        delete(to: ends.end, fallback: { deleteForward(sender) })
    }

    open override func deleteToBeginningOfParagraph(_ sender: Any?) {
        let caret = selectedSTTextRange.range.lowerBound
        delete(to: paragraphStart(at: caret), fallback: { deleteBackward(sender) })
    }

    // Control-K. At the end of the paragraph it deletes the newline, joining the
    // next paragraph, as in Emacs
    open override func deleteToEndOfParagraph(_ sender: Any?) {
        let caret = selectedSTTextRange.range.lowerBound
        delete(to: paragraphEnd(at: caret), fallback: { deleteForward(sender) })
    }
}
#endif
