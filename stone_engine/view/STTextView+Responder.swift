/*
STTextView+Responder.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center. All rights reserved.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension STTextView {
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
}

extension STTextView {
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
    }
    
    func moveToEndOfLine(modifySelection: Bool) {
    }
    
    func moveToBeginingOfDocument(modifySelection: Bool) {
    }
    
    func moveToEndOfDocument(modifySelection: Bool) {
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
                
                return
            case UIKeyCommand.inputDownArrow:
                switch direction {
                case .lrTb:
                    if command { moveToEndOfDocument(modifySelection: shift) }
                    else { moveDown(modifySelection: shift) }
                case .tbRl:
                    if command { moveToEndOfLine(modifySelection: shift) }
                    else { moveForward(modifySelection: shift) }
                }
                
                return
            case UIKeyCommand.inputLeftArrow:
                switch direction {
                case .lrTb:
                    if command { moveToBeginingOfLine(modifySelection: shift) }
                    else { moveBackward(modifySelection: shift) }
                case .tbRl:
                    if command { moveToEndOfDocument(modifySelection: shift) }
                    else { moveDown(modifySelection: shift) }
                }
                
                return
            case UIKeyCommand.inputRightArrow:
                switch direction {
                case .lrTb:
                    if command { moveToEndOfLine(modifySelection: shift) }
                    else { moveForward(modifySelection: shift) }
                case .tbRl:
                    if command { moveToBeginingOfDocument(modifySelection: shift) }
                    else { moveUp(modifySelection: shift) }
                }
                
                return
            default: break
            }
        }
        
        // Invoke super
        super.pressesBegan(presses, with: event)
    }
}
