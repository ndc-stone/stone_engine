/*
STTextView+Responder.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(iOS)
import UIKit

public extension STTextView {
    //--------------------------------------------------------------//
    // MARK: - UIResponder
    //--------------------------------------------------------------//
    
    override var canBecomeFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        // Invoke super
        let result = super.becomeFirstResponder()
        
        // Show cursor
        isCursorShown = true
        
        // Set needs layout
        setNeedsLayout()
        
        return result
    }
    
    override func resignFirstResponder() -> Bool {
        // Invoke super
        let result = super.resignFirstResponder()
        
        // Hide cursor
        isCursorShown = false
        
        // Set needs layout
        setNeedsLayout()
        
        return result
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // For selected
        if selectedSTTextRange.range.count > 0 {
            return action == #selector(cut(_:)) 
                || action == #selector(copy(_:))
                || action == #selector(paste(_:))
                || action == #selector(delete(_:))
                || action == #selector(select(_:))
                || action == #selector(selectAll(_:))
                || action == #selector(undo(_:))
                || action == #selector(getter: undoManager)
        }
        // For not selected
        else {
            return action == #selector(paste(_:))
                || action == #selector(select(_:))
                || action == #selector(selectAll(_:))
                || action == #selector(undo(_:))
                || action == #selector(getter: undoManager)
        }
    }
    
    override func cut(_ sender: Any?) {
        // Copy and delete
        copy(sender)
        delete(sender)
    }
    
    @objc func undo(_ sender: Any?) {
        // Undo
        _undoManager.undo()
    }
    
    override func copy(_ sender: Any?) {
        // Get selected text
        let range = selectedSTTextRange.range
        guard let text = text, text.count >= range.upperBound else { return }
        let subtext = String(text[text.index(text.startIndex, offsetBy: range.lowerBound) ..< text.index(text.startIndex, offsetBy: range.upperBound)])
        
        // Set selected text to pboard
        UIPasteboard.general.string = subtext
    }
    
    override func paste(_ sender: Any?) {
        // Get text from pboard
        guard let text = UIPasteboard.general.string else { return }
        
        // Insert text
        insertText(text)
    }
    
    override func delete(_ sender: Any?) {
        // Delete selected range
        guard let text = self.text, text.count >= selectedSTTextRange.range.upperBound else { return }
        replaceText("", textRange: selectedSTTextRange)
    }
    
    override func select(_ sender: Any?) {
        // Set selected text range
        let range = selectedSTTextRange.range
        guard range.isEmpty else { return }
        guard let text = text, text.count > 0 else { return }
        if range.upperBound == text.count {
            selectedTextRange = STTextRange(range: range.upperBound - 1 ..< range.upperBound)
        }
        else {
            selectedTextRange = STTextRange(range: range.upperBound ..< range.upperBound + 1)
        }
        
        // Needs to show menu
        setNeedsToUpdateMenu(true)
    }
    
    override func selectAll(_ sender: Any?) {
        // Set selected text range
        guard let text else { return }
        selectedTextRange = STTextRange(range: 0 ..< text.count)
        
        // Needs to show menu
        setNeedsToUpdateMenu(true)
    }
}

public extension STTextView {
    //--------------------------------------------------------------//
    // MARK: - Keyboard handling
    //--------------------------------------------------------------//
    
    private func moveCursor(lower: Int, upper: Int) {
        // Set selected range
        selectedTextRange = STTextRange(range: min(lower, upper) ..< max(lower, upper))
        
        // Set flag
        needsToScrollToShowCurosr = true
    }
    
    func deselect(begin: Bool) {
        // Move cursor
        let index = begin ? selectedSTTextRange.range.lowerBound : selectedSTTextRange.range.upperBound
        moveCursor(lower: index, upper: index)
    }
    
    func moveUp(modifySelection: Bool) {
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
        let line = label.context.line(at: isCursorBeginSelected ? selectedSTTextRange.range.lowerBound : selectedSTTextRange.range.upperBound)
        
        // Decide cursor rect for up down
        if line == 0 {
            cursorRectForUpDown = .zero
        }
        else if cursorRectForUpDown.isEmpty {
            cursorRectForUpDown = convert(cursorView.frame, to: label)
        }
        
        // Decide moved index
        let index: Int?
        if line == 0 {
            index = 0
        }
        else {
            // Get closest run at prev line
            guard let range = label.context.runIndexes(line: line - 1) else { return }
            index = label.context.closestRunIndex(to: .init(x: cursorRectForUpDown.midX, y: cursorRectForUpDown.midY), range: range)
        }
        guard let index = index else { return }
        
        // Decide moved range
        var lower = selectedSTTextRange.range.lowerBound
        var upper = selectedSTTextRange.range.upperBound
        if modifySelection {
            if isCursorBeginSelected {
                lower = index
            }
            else {
                upper = index
            }
        }
        else {
            lower = index
            upper = index
        }
        
        // Move cursor
        moveCursor(lower: lower, upper: upper)
    }
    
    func moveDown(modifySelection: Bool) {
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
        let line = label.context.line(at: isCursorBeginSelected ? selectedSTTextRange.range.lowerBound : selectedSTTextRange.range.upperBound)
        
        // Decide cursor rect for up down
        if line == label.context.lineCount - 1 {
            let cursorRect = label.context.cursorFrame(at: text.count)
            cursorRectForUpDown = cursorRect
        }
        else if cursorRectForUpDown.isEmpty {
            cursorRectForUpDown = convert(cursorView.frame, to: label)
        }
        
        // Decide moved index
        let index: Int?
        if line == label.context.lineCount - 1 {
            index = text.count
        }
        else {
            // Get closest run at next line
            guard let range = label.context.runIndexes(line: line + 1) else { return }
            index = label.context.closestRunIndex(to: .init(x: cursorRectForUpDown.midX, y: cursorRectForUpDown.midY), range: range)
        }
        guard let index = index else { return }
        
        // Decide moved range
        var lower = selectedSTTextRange.range.lowerBound
        var upper = selectedSTTextRange.range.upperBound
        if modifySelection {
            if isCursorBeginSelected {
                lower = index
            }
            else {
                upper = index
            }
        }
        else {
            lower = index
            upper = index
        }
        
        // Move cursor
        moveCursor(lower: lower, upper: upper)
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
    
    func moveToBeginingOfLine(modifySelection: Bool) {
        // Set flags
        if selectedSTTextRange.range.count == 0 {
            isCursorBeginSelected = true
        }
        cursorRectForUpDown = .zero

        // For selected
        if selectedSTTextRange.range.count > 0 && !modifySelection {
            // Deselect
            deselect(begin: true)
            return
        }

        // Get current line
        let cursorIndex = isCursorBeginSelected ? selectedSTTextRange.range.lowerBound : selectedSTTextRange.range.upperBound
        let line = label.context.line(at: cursorIndex)

        // Get line begin index
        guard let lineRange = label.context.runIndexes(line: line) else { return }
        let index = lineRange.lowerBound

        // Decide moved range
        var lower = selectedSTTextRange.range.lowerBound
        var upper = selectedSTTextRange.range.upperBound
        if modifySelection {
            if isCursorBeginSelected {
                lower = index
            }
            else {
                upper = index
            }
        }
        else {
            lower = index
            upper = index
        }

        // Move cursor
        moveCursor(lower: lower, upper: upper)
    }

    func moveToEndOfLine(modifySelection: Bool) {
        // Set flags
        if selectedSTTextRange.range.count == 0 {
            isCursorBeginSelected = false
        }
        cursorRectForUpDown = .zero

        // For selected
        if selectedSTTextRange.range.count > 0 && !modifySelection {
            // Deselect
            deselect(begin: false)
            return
        }

        // Get current line
        let cursorIndex = isCursorBeginSelected ? selectedSTTextRange.range.lowerBound : selectedSTTextRange.range.upperBound
        let line = label.context.line(at: cursorIndex)

        // Get line end index
        guard let lineRange = label.context.runIndexes(line: line) else { return }
        let index = lineRange.upperBound

        // Decide moved range
        var lower = selectedSTTextRange.range.lowerBound
        var upper = selectedSTTextRange.range.upperBound
        if modifySelection {
            if isCursorBeginSelected {
                lower = index
            }
            else {
                upper = index
            }
        }
        else {
            lower = index
            upper = index
        }

        // Move cursor
        moveCursor(lower: lower, upper: upper)
    }
    
    func moveToBeginingOfDocument(modifySelection: Bool) {
    }
    
    func moveToEndOfDocument(modifySelection: Bool) {
    }
    
    private func handleArrowKey(_ key: UIKey) -> Bool {
        // Get modifiers
        let shift = key.modifierFlags.contains(.shift)
        let command = key.modifierFlags.contains(.command)

        // Switch by characters
        switch key.charactersIgnoringModifiers {
        case UIKeyCommand.inputUpArrow:
            switch direction {
            case .lrTb:
                if command { moveToBeginingOfDocument(modifySelection: shift) }
                else { moveUp(modifySelection: shift) }
            case .tbRl:
                if command { moveToBeginingOfLine(modifySelection: shift) }
                else { moveBackward(modifySelection: shift) }
            }
            return true
        case UIKeyCommand.inputDownArrow:
            switch direction {
            case .lrTb:
                if command { moveToEndOfDocument(modifySelection: shift) }
                else { moveDown(modifySelection: shift) }
            case .tbRl:
                if command { moveToEndOfLine(modifySelection: shift) }
                else { moveForward(modifySelection: shift) }
            }
            return true
        case UIKeyCommand.inputLeftArrow:
            switch direction {
            case .lrTb:
                if command { moveToBeginingOfLine(modifySelection: shift) }
                else { moveBackward(modifySelection: shift) }
            case .tbRl:
                if command { moveToEndOfDocument(modifySelection: shift) }
                else { moveDown(modifySelection: shift) }
            }
            return true
        case UIKeyCommand.inputRightArrow:
            switch direction {
            case .lrTb:
                if command { moveToEndOfLine(modifySelection: shift) }
                else { moveForward(modifySelection: shift) }
            case .tbRl:
                if command { moveToBeginingOfDocument(modifySelection: shift) }
                else { moveUp(modifySelection: shift) }
            }
            return true
        default:
            return false
        }
    }

    private func startKeyRepeat(key: UIKey) {
        // Stop existing timer
        stopKeyRepeat()

        // Create action
        keyRepeatAction = { [weak self] in
            guard let self = self else { return }
            _ = self.handleArrowKey(key)
        }

        // Start timer with initial delay
        keyRepeatTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            // Execute action
            self.keyRepeatAction?()

            // Start repeat timer
            self.keyRepeatTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
                self?.keyRepeatAction?()
            }
        }
    }

    private func stopKeyRepeat() {
        keyRepeatTimer?.invalidate()
        keyRepeatTimer = nil
        keyRepeatAction = nil
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // For marked
        guard markedTextRange == nil else {
            // Invoke super
            super.pressesBegan(presses, with: event)
            return
        }

        // Get presses
        for press in presses {
            // Get key
            guard let key = press.key else { continue }

            // Handle arrow key
            if handleArrowKey(key) {
                // Start key repeat
                startKeyRepeat(key: key)
                return
            }
        }

        // Invoke super
        super.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // Stop key repeat
        stopKeyRepeat()

        // Invoke super
        super.pressesEnded(presses, with: event)
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // Stop key repeat
        stopKeyRepeat()

        // Invoke super
        super.pressesCancelled(presses, with: event)
    }
}

#endif
