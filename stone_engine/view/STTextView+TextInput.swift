/*
STTextView+TextInput.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center. All rights reserved.
This software is licensed under the MIT License. See LICENSE for details.
*/

import UIKit

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
    // MARK: - Replace
    //--------------------------------------------------------------//
    
    private func replaceText(_ replaceText: String, textRange: STTextRange) {
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
            
            // Register undo
            /*
            _undoManager._registerUndo(withTarget: self, handler: { target in
                // Replace text
                target._replaceText(replacedText, textRange: insertedRange)
                
                // Set selected range
                self._selectedTextRange = oldSelectedRange
                
                // Clear marked text range
                self._markedTextRange = nil
            })
            */
        }
        
        // Set selected text range
        let selectedStart = index + replaceText.count
        selectedTextRange = STTextRange(range: selectedStart ..< selectedStart)
        
        // Set flag
        needsToScrollToShowCurosr = true
    }
}

extension STTextView: UITextInput {
    //--------------------------------------------------------------//
    // MARK: - Text
    //--------------------------------------------------------------//
    
    var hasText: Bool {
        // Check text
        return text != nil
    }
    
    func text(in range: UITextRange) -> String? {
        // Get substring
        guard let range = range as? STTextRange, let text = text else { return nil }
        return String(text[range.range(text: text)])
    }
    
    func insertText(_ text: String) {
        // Replace text
        let replaceTextRange: STTextRange
        if let markedTextRange = markedSTTextRange, !markedTextRange.isEmpty {
            replaceTextRange = markedTextRange
        }
        else {
            replaceTextRange = selectedSTTextRange
        }
        replaceText(text, textRange: replaceTextRange)
    }
    
    func replace(_ range: UITextRange, withText text: String) {
    }
    
    func deleteBackward() {
        // For marked
        if let markedTextRange = markedSTTextRange, !markedTextRange.isEmpty {
            // Delete one character at marked text range
            let index = markedTextRange.range.upperBound
            guard index > 0 else { return }
            replaceText("", textRange: STTextRange(range: index - 1 ..< index))
        }
        // Delete one character at selected text range
        else if selectedSTTextRange.range.count == 0 {
            let index = selectedSTTextRange.range.lowerBound
            guard index > 0 else { return }
            replaceText("", textRange: STTextRange(range: index - 1 ..< index))
        }
        // Delete selected text range
        else {
            replaceText("", textRange: selectedSTTextRange)
        }
    }
    
    //--------------------------------------------------------------//
    // MARK: - Marked and selected
    //--------------------------------------------------------------//
    
    var selectedTextRange: UITextRange? {
        get { selectedSTTextRange }
        set {
            // Set selected text range
            selectedSTTextRange = newValue as! STTextRange
            
            // Set needs display
            label.setNeedsDisplay()
            
            // Set needs layout
            setNeedsLayout()
        }
    }
    
    var markedTextRange: UITextRange? {
        get { markedSTTextRange }
        set { markedSTTextRange = newValue as? STTextRange }
    }
    
    var markedTextStyle: [NSAttributedString.Key: Any]? {
        get {
            return nil
        }
        set (markedTextStyle) {
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
    
    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        // Do not use this method
    }
    
    func setAttributedMarkedText(_ markedAttrStr: NSAttributedString?, selectedRange: NSRange) {
        // Get marked text
        let markedText = markedAttrStr?.string ?? ""
        
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
        markedAttrStr?.enumerateAttributes(in: NSRange(location: 0, length: markedAttrStr?.length ?? 0), using: { attr, range, finished in
            // Add marked range
            var isSelected: Bool = false
            if attr[.backgroundColor] != nil {
                isSelected = true
            }
            else if let underline = attr[.underlineStyle] as? Int, underline == NSUnderlineStyle.thick.rawValue {
                isSelected = true
            }
            
            let range = alignNSRange(range, text: markedAttrStr?.string)
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
    
    func unmarkText() {
        // Clear marked text range
        markedTextRange = nil
        markedRanges = nil
    }
    
    //--------------------------------------------------------------//
    // MARK: - Range and positions
    //--------------------------------------------------------------//
    
    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        return nil
    }
    
    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        return nil
    }
    
    func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        return nil
    }
    
    var beginningOfDocument: UITextPosition {
        // Create text position
        return STTextPosition(index: 0)
    }
    
    var endOfDocument: UITextPosition {
        // Create text position
        return STTextPosition(index: label.text?.count ?? 0)
    }
    
    //--------------------------------------------------------------//
    // MARK: - Range and positions
    //--------------------------------------------------------------//
    
    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        return .orderedSame
    }
    
    func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        return 0
    }
    
    //--------------------------------------------------------------//
    // MARK: - Layout and writing direction
    //--------------------------------------------------------------//
    
    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        return nil
    }
    
    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        return nil
    }
    
    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        return .natural
    }
    
    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {
    }
    
    //--------------------------------------------------------------//
    // MARK: - Geometry and hit-testing
    //--------------------------------------------------------------//
    
    static let underlineMargin: CGFloat = 4
    static let caretWidth: CGFloat = 2
    
    func firstRect(for range: UITextRange) -> CGRect {
        // Get run
        let index = (range as! STTextRange).range.lowerBound
        guard index >= 0, index < label.context.runs.count else { return .zero }
        let run = label.context.runs[index]
        
        // Decide rect
        var frame = run.frame
        frame.size.height += Self.underlineMargin
        
        return convert(frame, from: label)
    }
    
    func caretRect(for position: UITextPosition) -> CGRect {
        // Get run at position
        let index = (position as! STTextPosition).index
        guard label.context.runs.count > 0 else {
            let runFrame = label.context.firstRunFrame(line: 0)
            switch direction {
            case .lrTb: return .init(x: runFrame.maxX, y: runFrame.minY, width: 2, height: runFrame.height)
            case .tbRl: return .init(x: runFrame.minX, y: runFrame.maxY, width: runFrame.width, height: 2)
            }
        }
        let run = label.context.runs[min(index, label.context.runs.count - 1)]
        
        // Decide rect
        return .init(origin: run.position, size: .init(width: Self.caretWidth, height: fontSize + Self.underlineMargin))
    }
    
    func closestPosition(to point: CGPoint) -> UITextPosition? {
        // Convert point
        let point = convert(point, to: label)
        
        // Get closest run ID
        let runId = label.context.closestRunIndex(to: point)
        return STTextPosition(index: runId)
    }
    
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        return []
    }
    
    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        return nil
    }
    
    func characterRange(at point: CGPoint) -> UITextRange? {
        return nil
    }
    
    func hitPosition(to point: CGPoint) -> UITextPosition? {
        // Get hit postion
        guard let text = text else { return nil }
        return hitPosition(to: point, within: STTextRange(range: 0 ..< text.count))
    }
    
    func hitPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        // Convert point
        let point = convert(point, to: label)
        
        // Get hit run index
        guard let index = label.context.hitRunIndex(to: point) else { return nil }
        return STTextPosition(index: index)
    }
    
    //--------------------------------------------------------------//
    // MARK: - Tokenizer
    //--------------------------------------------------------------//
    
    var tokenizer: any UITextInputTokenizer {
        return UITextInputStringTokenizer(textInput: self)
    }
    
    var inputDelegate: UITextInputDelegate? {
        get { nil }
        set (inputDelegate) {}
    }
}
