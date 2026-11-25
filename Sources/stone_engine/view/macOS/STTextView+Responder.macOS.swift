/*
STTextView+Responder.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(macOS)
import Cocoa

extension STTextView {
    //--------------------------------------------------------------//
    // MARK: - Responder
    //--------------------------------------------------------------//
    
    open override var acceptsFirstResponder: Bool {
        return true
    }
    
    open override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    open override func becomeFirstResponder() -> Bool {
        // Show cursor
        isCursorShown = true

        // Set needs layout
        needsLayout = true

        // Notify it
        NotificationCenter.default.post(name: STTextView.didBecomeFirstResponder, object: self)

        return true
    }

    open override func resignFirstResponder() -> Bool {
        // Hide cursor
        isCursorShown = false

        // Set needs layout
        needsLayout = true

        // Notify it
        NotificationCenter.default.post(name: STTextView.didResignFirstResponder, object: self)

        return true
    }
    
    //--------------------------------------------------------------//
    // MARK: - Mouse handling
    //--------------------------------------------------------------//
    
    open override func mouseDown(with event: NSEvent) {
        // Invoke super
        super.mouseDown(with: event)

        // Make itself first responder
        if window?.firstResponder != self {
            window?.makeFirstResponder(self)
        }

        // Get point and index
        let point = label.convert(event.locationInWindow, from: nil)
        let index = label.context.closestRunIndex(to: point)
        let hitIndex = label.context.hitRunIndex(to: point)
        
        // Get modifiers
        let control = event.modifierFlags.contains(.control)
        let shift = event.modifierFlags.contains(.shift)
        
        // For control click
        if control {
            return
        }
        
        // For single click
        if event.clickCount == 1 {
            if shift {
                // Extend selection. The end that is not moving stays put, and
                // the click becomes the moving end. Remember which side that
                // ended up on, so scrolling follows it (see movingSelectionIndex).
                let range = selectedSTTextRange.range
                let anchor = isCursorBeginSelected ? range.upperBound : range.lowerBound
                isCursorBeginSelected = index < anchor
                moveCursor(lower: anchor, upper: index)
            }
            else {
                // Move cursor
                mouseDownIndex = index
                isCursorBeginSelected = false
                moveCursor(lower: index, upper: index)
            }
        }
    }
    
    open override func mouseUp(with event: NSEvent) {
        // Inovke super
        super.mouseUp(with: event)
    }
    
    open override func mouseDragged(with event: NSEvent) {
        // Invoke super
        super.mouseDragged(with: event)

        // Get point and index
        let point = label.convert(event.locationInWindow, from: nil)
        let index = label.context.closestRunIndex(to: point)

        // Remember which end is moving. Dragging above the mouse down point
        // moves the lower end, and scrolling has to follow that end rather than
        // the anchor (see movingSelectionIndex).
        isCursorBeginSelected = index < mouseDownIndex

        // Select from mouse down index to current index
        moveCursor(lower: mouseDownIndex, upper: index)
    }
    
    //--------------------------------------------------------------//
    // MARK: - Keyboard handling
    //--------------------------------------------------------------//
    
    open override func keyDown(with event: NSEvent) {
        // Interpret key events
        interpretKeyEvents([event])
    }
    
    func moveCursor(lower: Int, upper: Int) {
        // Set selected range
        selectedTextRange = STTextRange(range: min(lower, upper) ..< max(lower, upper))
        
        // Set flag
        needsToScrollToShowCurosr = true
    }
    
    public func deselect(begin: Bool) {
        // Move cursor
        let index = begin ? selectedSTTextRange.range.lowerBound : selectedSTTextRange.range.upperBound
        moveCursor(lower: index, upper: index)
    }
    
    func moveToPrevLine(modifySelection: Bool) {
        // Set flags
        if selectedSTTextRange.range.count == 0 {
            isCursorBeginSelected = true
        }

        // For selected
        if selectedSTTextRange.range.count > 0 && !modifySelection {
            // Deselect
            deselect(begin: true)
            return
        }

        // Get current line
        let line = label.context.line(at: movingSelectionIndex)

        // Decide moved index. On the first line it goes to the beginning, keeping
        // the goal so that moving back returns to the same place
        let index: Int
        if line == 0 {
            index = 0
        }
        else {
            // Get closest run at prev line
            guard let range = label.context.runIndexes(line: line - 1) else { return }
            index = closestRunIndexForLineMove(range: range)
        }

        // Move cursor
        moveCursorByLine(to: index, modifySelection: modifySelection)
    }

    func moveToNextLine(modifySelection: Bool) {
        // Get current text
        guard let text = text else { return }

        // Set flags
        if selectedSTTextRange.range.count == 0 {
            isCursorBeginSelected = false
        }

        // For selected
        if selectedSTTextRange.range.count > 0 && !modifySelection {
            // Deselect
            deselect(begin: false)
            return
        }

        // Get current line
        let line = label.context.line(at: movingSelectionIndex)

        // Decide moved index. On the last line it goes to the end, keeping the
        // goal so that moving back returns to the same place
        let index: Int
        if line == label.context.lineCount - 1 {
            index = text.count
        }
        else {
            // Get closest run at next line
            guard let range = label.context.runIndexes(line: line + 1) else { return }
            index = closestRunIndexForLineMove(range: range)
        }

        // Move cursor
        moveCursorByLine(to: index, modifySelection: modifySelection)
    }

    // The caret position in the given line closest to the goal of the line moves.
    // The goal is where the moving end of the selection was when the line moves
    // began, so a short line passed on the way does not pull the caret off it.
    func closestRunIndexForLineMove(range: Range<Int>) -> Int {
        // Decide goal from the moving end, not from the cursor view, which sits at
        // the upper bound of the selection and is laid out in another view
        if cursorRectForUpDown.isEmpty {
            cursorRectForUpDown = label.context.cursorFrame(at: movingSelectionIndex)
        }

        return label.context.closestRunIndex(to: .init(x: cursorRectForUpDown.midX, y: cursorRectForUpDown.midY), range: range)
    }

    // Move the moving end of the selection (or the caret) to index, keeping the
    // goal of the line moves.
    private func moveCursorByLine(to index: Int, modifySelection: Bool) {
        moveSelectionEnd(to: index, modifySelection: modifySelection, keepsGoal: true)
    }

    // Move the moving end of the selection to index when extending it, or the
    // caret otherwise. The anchor stays put, and the moving end may cross it.
    func moveSelectionEnd(to index: Int, modifySelection: Bool, keepsGoal: Bool = false) {
        // Decide moved range
        var lower = index
        var upper = index
        if modifySelection {
            let range = selectedSTTextRange.range
            let anchor = isCursorBeginSelected ? range.upperBound : range.lowerBound
            lower = min(anchor, index)
            upper = max(anchor, index)
            isCursorBeginSelected = index < anchor
        }

        // Move cursor
        isMovingCursorByLine = keepsGoal
        moveCursor(lower: lower, upper: upper)
        isMovingCursorByLine = false
    }
    
    func moveForward(modifySelection: Bool) {
        // Set flags
        if selectedSTTextRange.range.count == 0 {
            isCursorBeginSelected = false
            cursorRectForUpDown = .zero
        }
        
        // For selected
        if selectedSTTextRange.range.count > 0 && !modifySelection {
            // Deselect
            deselect(begin: false)
            return
        }
        
        // Decide moved range
        var lower = selectedSTTextRange.range.lowerBound
        var upper = selectedSTTextRange.range.upperBound
        if modifySelection {
            if isCursorBeginSelected {
                if selectedSTTextRange.range.lowerBound < upper {
                    lower = selectedSTTextRange.range.lowerBound + 1
                }
            }
            else {
                if selectedSTTextRange.range.upperBound < label.context.runs.count {
                    upper = selectedSTTextRange.range.upperBound + 1
                }
            }
        }
        else {
            if selectedSTTextRange.range.upperBound < label.context.runs.count {
                lower = selectedSTTextRange.range.upperBound + 1
                upper = lower
            }
        }
        
        // Move cursor
        moveCursor(lower: lower, upper: upper)
    }
    
    func moveBackward(modifySelection: Bool) {
        // Set flags
        if selectedSTTextRange.range.count == 0 {
            isCursorBeginSelected = true
            cursorRectForUpDown = .zero
        }
        
        // For selected
        if selectedSTTextRange.range.count > 0 && !modifySelection {
            // Deselect
            deselect(begin: true)
            return
        }
        
        // Decide moved range
        var lower = selectedSTTextRange.range.lowerBound
        var upper = selectedSTTextRange.range.upperBound
        if modifySelection {
            if isCursorBeginSelected {
                if selectedSTTextRange.range.lowerBound > 0 {
                    lower = selectedSTTextRange.range.lowerBound - 1
                }
            }
            else {
                if selectedSTTextRange.range.upperBound > lower {
                    upper = selectedSTTextRange.range.upperBound - 1
                }
            }
        }
        else {
            if selectedSTTextRange.range.lowerBound > 0 {
                lower = selectedSTTextRange.range.lowerBound - 1
                upper = lower
            }
        }
        
        // Move cursor
        moveCursor(lower: lower, upper: upper)
    }
    
    // The move commands are logical, not on screen. For vertical writing, which
    // drawsVerticallyForCharacter(at:) reports, AppKit already turns the arrow keys
    // a quarter: the up arrow arrives as moveLeft (back one character) and the
    // left arrow as moveDown (the next line). Turning them again here by the
    // direction would send the up arrow to the next line.
    open override func moveUp(_ sender: Any?) {
        moveToPrevLine(modifySelection: false)
    }

    open override func moveUpAndModifySelection(_ sender: Any?) {
        moveToPrevLine(modifySelection: true)
    }

    open override func moveDown(_ sender: Any?) {
        moveToNextLine(modifySelection: false)
    }

    open override func moveDownAndModifySelection(_ sender: Any?) {
        moveToNextLine(modifySelection: true)
    }

    open override func moveLeft(_ sender: Any?) {
        moveBackward(modifySelection: false)
    }

    open override func moveLeftAndModifySelection(_ sender: Any?) {
        moveBackward(modifySelection: true)
    }

    open override func moveRight(_ sender: Any?) {
        moveForward(modifySelection: false)
    }

    open override func moveRightAndModifySelection(_ sender: Any?) {
        moveForward(modifySelection: true)
    }

    open override func moveForward(_ sender: Any?) {
        moveForward(modifySelection: false)
    }

    open override func moveBackward(_ sender: Any?) {
        moveBackward(modifySelection: false)
    }
    
    //--------------------------------------------------------------//
    // MARK: - Deletion
    //--------------------------------------------------------------//

    open override func deleteBackward(_ sender: Any?) {
        // For selection
        if selectedSTTextRange.range.count > 0 {
            replaceText("", textRange: selectedSTTextRange)
            return
        }

        // Delete one character before cursor
        let index = selectedSTTextRange.range.lowerBound
        guard index > 0 else { return }
        replaceText("", textRange: STTextRange(range: index - 1 ..< index))
    }

    open override func deleteForward(_ sender: Any?) {
        // For selection
        if selectedSTTextRange.range.count > 0 {
            replaceText("", textRange: selectedSTTextRange)
            return
        }

        // Delete one character after cursor
        let index = selectedSTTextRange.range.upperBound
        guard let text = text, index < text.count else { return }
        replaceText("", textRange: STTextRange(range: index ..< index + 1))
    }

    //--------------------------------------------------------------//
    // MARK: - Clipboard
    //--------------------------------------------------------------//

    @objc func copy(_ sender: Any?) {
        // Get selected text
        guard let text = text else { return }
        guard selectedSTTextRange.range.count > 0 else { return }
        let range = selectedSTTextRange.range(text: text)
        let selectedText = String(text[range])

        // Copy to pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(selectedText, forType: .string)
    }

    @objc func cut(_ sender: Any?) {
        // Copy and delete
        copy(sender)
        guard selectedSTTextRange.range.count > 0 else { return }
        replaceText("", textRange: selectedSTTextRange)
    }

    @objc func paste(_ sender: Any?) {
        // Get pasteboard string
        guard let string = NSPasteboard.general.string(forType: .string) else { return }

        // Insert text
        insertText(string, replacementRange: .init(location: NSNotFound, length: 0))

        // Commit paste as a single undo group
        _undoManager.register()
        undoEditKind = .none
    }

    @objc func delete(_ sender: Any?) {
        // Delete selected text
        guard selectedSTTextRange.range.count > 0 else { return }
        replaceText("", textRange: selectedSTTextRange)
    }

    //--------------------------------------------------------------//
    // MARK: - Selection
    //--------------------------------------------------------------//

    open override func selectAll(_ sender: Any?) {
        // Get text count
        guard let count = text?.count else { return }

        // Select all
        moveCursor(lower: 0, upper: count)
    }

    //--------------------------------------------------------------//
    // MARK: - Insertion
    //--------------------------------------------------------------//
    
    open override func insertNewline(_ sender: Any?) {
        // For single line, do not insert a newline; notify instead
        if isSingleLine {
            NotificationCenter.default.post(name: STTextView.enterPressed, object: self)
            return
        }

        // Insert new line
        insertText("\n", replacementRange: .init(location: NSNotFound, length: 0))
    }
    
    open override func insertNewlineIgnoringFieldEditor(_ sender: Any?) {
        // As inert new line
        insertNewline(sender)
    }
}
#endif
