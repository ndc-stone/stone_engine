/*
STTextView+TextInput.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(macOS)
import Cocoa

extension STTextView {
    //--------------------------------------------------------------//
    // MARK: - Range
    //--------------------------------------------------------------//
    
    private func normalizeNSRange(_ nsRange: NSRange, text: String?) -> Range<Int> {
        // Check text
        guard let text = text else { return nsRange.lowerBound ..< nsRange.upperBound }
        
        // Align range
        var lower = 0
        var upper = 0
        var index = 0
        var unicodeIndex = 0
        for c in text {
            if unicodeIndex <= nsRange.lowerBound {
                lower = index
                upper = index
            }
            else if unicodeIndex <= nsRange.upperBound {
                upper = index
            }
            else { break }
            
            index += 1
            unicodeIndex += c.utf16.count
        }
        
        // Check last
        if unicodeIndex == nsRange.lowerBound {
            lower = index
            upper = index
        }
        if unicodeIndex == nsRange.upperBound {
            upper = index
        }
        
        return lower ..< upper
    }
    
    //--------------------------------------------------------------//
    // MARK: - String
    //--------------------------------------------------------------//

    // NSTextInputClient is handed either an NSString or an NSAttributedString, and
    // which one arrives is up to the input method. Take both.

    func normalizedString(_ string: Any) -> String? {
        if let attrStr = string as? NSAttributedString { return attrStr.string }
        return string as? String
    }

    func normalizedAttributedString(_ string: Any) -> NSAttributedString? {
        if let attrStr = string as? NSAttributedString { return attrStr }
        guard let str = string as? String else { return nil }
        return NSAttributedString(string: str)
    }

    //--------------------------------------------------------------//
    // MARK: - Replace
    //--------------------------------------------------------------//
    
    public func replaceText(_ replaceText: String, textRange: STTextRange) {
        // Get current text
        var text = self.text ?? ""
        
        // Replace with text
        let stringIndexRange = textRange.range(text: text)
        let replacedText = String(text[stringIndexRange])
        text.replaceSubrange(stringIndexRange, with: replaceText)
        
        // Decide inserted range
        let index = textRange.range.lowerBound
        let insertedRange = STTextRange(range: index ..< index + replaceText.count)
        
        // Keep current selected range
        let oldSelectedRange = selectedSTTextRange
        
        // For changed
        if self.text != text {
            // Set text
            self.text = text

            // Decide edit kind for undo grouping
            let isDeletion = replaceText.isEmpty
            let kind: STUndoEditKind = isDeletion ? .deleting : .inserting
            let isEditing = !_undoManager.isUndoing && !_undoManager.isRedoing

            // Close the previous group when switching between typing and deleting
            if isEditing && !isComposingText {
                if undoEditKind != .none && undoEditKind != kind {
                    _undoManager.register()
                }
            }

            // Stack text replacement
            _undoManager.stackTextReplacement(
                replacedText: replacedText,
                insertedRange: insertedRange,
                selectedRanage: oldSelectedRange
            )

            // Close the group at a word boundary (whitespace / newline)
            if isEditing && !isComposingText {
                let isWhitespace = !isDeletion && replaceText.unicodeScalars.allSatisfy {
                    CharacterSet.whitespacesAndNewlines.contains($0)
                }
                if isWhitespace {
                    _undoManager.register()
                    undoEditKind = .none
                }
                else {
                    undoEditKind = kind
                }
            }
        }
        
        // Set selected text range
        let selectedStart = index + replaceText.count
        selectedTextRange = STTextRange(range: selectedStart ..< selectedStart)

        // Set flag
        needsToScrollToShowCurosr = true
    }
}

extension STTextView: NSTextInputClient {
    //--------------------------------------------------------------//
    // MARK: - NSTextInputClient
    //--------------------------------------------------------------//
    
    public func insertText(_ string: Any, replacementRange: NSRange) {
        // Check text. AppKit hands over either an NSString or an NSAttributedString
        guard var text = normalizedString(string) else { return }

        // For single line, strip newlines (e.g. pasted multi-line text)
        if isSingleLine {
            text = text.replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
        }

        // Keep composing state (committing marked text)
        let wasComposing = isComposingText

        // Replace text
        let replaceTextRange: STTextRange
        if let markedTextRange = markedSTTextRange, !markedTextRange.isEmpty {
            replaceTextRange = markedTextRange
        }
        else {
            replaceTextRange = selectedSTTextRange
        }
        replaceText(text, textRange: replaceTextRange)

        // Clear marked text range
        markedTextRange = nil
        markedRanges = nil

        // Commit composed text as a single undo group
        if wasComposing {
            isComposingText = false
            _undoManager.register()
            undoEditKind = .none
        }
    }
    
    override public func doCommand(by selector: Selector) {
        // Invoke super
        super.doCommand(by: selector)
    }
    
    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        // Check text. The input method hands over an NSAttributedString while it
        // carries clause attributes, but a plain NSString once it has none - which
        // is what it sends when the composition is cleared by a delete
        guard let markedAttrStr = normalizedAttributedString(string) else { return }

        // Begin composition (close any pending typing group first)
        if !isComposingText {
            _undoManager.register()
            undoEditKind = .none
            isComposingText = true
        }

        // Get marked text
        let markedText = markedAttrStr.string
        
        // Normalize selected range
        let normalizedSlectedRange = normalizeNSRange(selectedRange, text: markedText)
        
        // Replace text
        let replaceTextRange: STTextRange
        if let markedTextRange = markedSTTextRange, !markedTextRange.isEmpty {
            replaceTextRange = markedTextRange
        }
        else {
            replaceTextRange = selectedSTTextRange
        }
        replaceText(markedText, textRange: replaceTextRange)
        
        // Set marked text
        let replaceLowerIndex = replaceTextRange.range.lowerBound
        if markedText.count == 0 {
            markedTextRange = nil
        }
        else {
            markedTextRange = STTextRange(range: replaceLowerIndex ..< replaceLowerIndex + markedText.count)
        }
        
        // Set selected range
        selectedTextRange = STTextRange(range: replaceLowerIndex + normalizedSlectedRange.lowerBound ..< replaceLowerIndex + normalizedSlectedRange.upperBound)
        
        // Set marked ranges
        var markedRanges = [(Range<Int>, Bool)]()
        markedAttrStr.enumerateAttributes(in: NSRange(location: 0, length: markedAttrStr.length), using: { attr, range, finished in
            // Add marked range
            var isSelected: Bool = false
            if attr[.backgroundColor] != nil {
                isSelected = true
            }
            else if let underline = attr[.underlineStyle] as? Int, underline == NSUnderlineStyle.thick.rawValue {
                isSelected = true
            }
            
            let range = alignNSRange(range, text: markedAttrStr.string)
            markedRanges.append((replaceLowerIndex + range.lowerBound ..< replaceLowerIndex + range.upperBound, isSelected))
        })
        if markedRanges.first(where: { $0.1 }) == nil {
            if var markedRange = markedRanges.first {
                markedRange.1 = true
                markedRanges[0] = markedRange
            }
        }
        self.markedRanges = markedRanges.isEmpty ? nil : markedRanges
    }
    
    public func unmarkText() {
        // Clear marked text range
        markedTextRange = nil
        markedRanges = nil

        // End composition and register undo
        isComposingText = false
        _undoManager.register()
        undoEditKind = .none
    }
    
    public func selectedRange() -> NSRange {
        // Get selected range
        return selectedSTTextRange.nsRange
    }
    
    public func markedRange() -> NSRange {
        // Get marked range
        return markedSTTextRange?.nsRange ?? NSRange(location: NSNotFound, length: 0)
    }
    
    public func hasMarkedText() -> Bool {
        // Check marked range
        guard let markedRanges = markedRanges else { return false }
        return markedRanges.count > 0
    }
    
    public func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        return nil
    }
    
    public func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        // Get attributes
        return [
            NSAttributedString.Key.font, 
            NSAttributedString.Key.underlineStyle, 
            NSAttributedString.Key.foregroundColor, 
            NSAttributedString.Key.backgroundColor, 
            NSAttributedString.Key.underlineColor, 
            NSAttributedString.Key.markedClauseSegment, 
        ]
    }
    
    static let underlineMargin: CGFloat = 4
    static let caretWidth: CGFloat = 2
    
    public func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        // Get run
        let runs = label.context.runs
        let index = range.location == NSNotFound ? 0 : range.location
        guard index >= 0, index < runs.count else { return .zero }
        let run = runs[index]

        // Union the runs in the range on the first run's line, so the input method
        // places its candidate window beside the whole composition, not over it
        var frame = run.frame
        let upperIndex = range.location == NSNotFound ? index + 1 : min(index + range.length, runs.count)
        var lastIndex = index
        for i in index ..< upperIndex {
            let r = runs[i]
            guard r.line == run.line else { break }
            lastIndex = i
            guard !r.isNewline, !r.isHidden else { continue }
            frame = frame.union(r.frame)
        }
        actualRange?.pointee = NSRange(location: index, length: range.length == 0 ? 0 : lastIndex - index + 1)

        // Leave room for the underline, below in horizontal and left in vertical
        switch direction {
        case .lrTb:
            frame.size.height += Self.underlineMargin
        case .tbRl:
            frame.origin.x -= Self.underlineMargin
            frame.size.width += Self.underlineMargin
        }

        // Convert from label, where run frames live, so insets and scrolling count
        frame = label.convert(frame, to: nil)
        if let window = window {
            frame = window.convertToScreen(frame)
        }
        
        return frame
    }
    
    public func drawsVerticallyForCharacter(at charIndex: Int) -> Bool {
        // Tell the input method about vertical writing, so it puts its candidate
        // window beside the column instead of below it
        return direction == .tbRl
    }

    public func characterIndex(for point: NSPoint) -> Int {
        return 0
    }
    
    //--------------------------------------------------------------//
    // MARK: - Marked and selected
    //--------------------------------------------------------------//
    
    public var selectedTextRange: STTextRange? {
        get {
            return selectedSTTextRange
        }
        set {
            // Set selected text range
            selectedSTTextRange = newValue ?? STTextRange(range: 0 ..< 0)
            
            // Set needs display
            label.needsDisplay = true
            
            // Set needs layout
            needsLayout = true
        }
    }
    
    public var selectedText: String? {
        // Get range
        guard let range = selectedTextRange else { return nil }
        guard range.range.lowerBound < range.range.upperBound else { return nil }
        
        // Decide selected text
        guard let text = text else { return nil }
        return String(text[range.range(text: text)])
    }
    
    public var markedTextRange: STTextRange? {
        get {
            return markedSTTextRange
        }
        set {
            markedSTTextRange = newValue
        }
    }
    
    private func alignNSRange(_ nsRange: NSRange, text: String?) -> Range<Int> {
        // Check text
        guard let text = text else { return nsRange.lowerBound ..< nsRange.upperBound }
        
        // Align range
        var lower = 0
        var upper = 0
        var index = 0
        var unicodeIndex = 0
        for c in text {
            if unicodeIndex <= nsRange.lowerBound {
                lower = index
                upper = index
            }
            else if unicodeIndex <= nsRange.upperBound {
                upper = index
            }
            else { break }
            
            index += 1
            unicodeIndex += c.utf16.count
        }
        
        // Check last
        if unicodeIndex == nsRange.lowerBound {
            lower = index
            upper = index
        }
        if unicodeIndex == nsRange.upperBound {
            upper = index
        }
        
        return lower ..< upper
    }
}
#endif
