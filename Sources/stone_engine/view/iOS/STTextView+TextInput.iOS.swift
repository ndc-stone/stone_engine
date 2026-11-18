/*
STTextView+TextInput.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center. All rights reserved.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(iOS)
import UIKit

public extension STTextView {
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
    
    func replaceText(_ replaceText: String, textRange: STTextRange) {
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
            
            // Stack text replacement
            _undoManager.stackTextReplacement(
                replacedText: replacedText, 
                insertedRange: insertedRange, 
                selectedRanage: oldSelectedRange
            )
            
            // For new line
            if replaceText == "\n" {
                // Register undo
                _undoManager.register()
            }
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
    
    public var hasText: Bool {
        // Check text
        guard let text = text else { return false }
        return !text.isEmpty
    }
    
    public func text(in range: UITextRange) -> String? {
        // Get substring
        guard let range = range as? STTextRange, let text = text else { return nil }
        return String(text[range.range(text: text)])
    }
    
    public func insertText(_ text: String) {
        // Replace text
        let replaceTextRange: STTextRange
        if let markedTextRange = markedSTTextRange, !markedTextRange.isEmpty {
            replaceTextRange = STTextRange(start: markedTextRange.start, end: markedTextRange.start)
        }
        else {
            replaceTextRange = selectedSTTextRange
        }
        replaceText(text, textRange: replaceTextRange)
        
        // Update marked text range
        if let markedTextRange = markedSTTextRange, !markedTextRange.isEmpty {
            self.markedTextRange = STTextRange(
                range: markedTextRange.range.lowerBound + text.count ..< markedTextRange.range.upperBound + text.count
            )
        }
    }
    
    public func replace(_ range: UITextRange, withText replaceText: String) {
        // Check range
        guard var text = text else { return }
        guard let range = (range as? STTextRange)?.range else { return }
        guard range.upperBound <= text.count else { return }
        
        // Replace
        text.replaceSubrange(text.index(text.startIndex, offsetBy: range.lowerBound) ..< text.index(text.startIndex, offsetBy: range.upperBound), with: replaceText)
        
        // Set text
        self.text = text
        
        // Set selected text range
        let lastIndex = range.lowerBound + replaceText.count
        selectedSTTextRange = STTextRange(range: lastIndex ..< lastIndex)
    }
    
    func replaceAll(_ ranges: [UITextRange], withText replaceText: String) {
        // Check text
        guard var text = text else { return }
        
        // Sort ranges
        let ranges = ranges.compactMap({ ($0 as? STTextRange)?.range })
        let sortedRanges = ranges.sorted { range0, range1 in
            return range0.lowerBound < range1.lowerBound
        }
        
        // Replace
        for range in sortedRanges.reversed() {
            guard range.upperBound <= text.count else { continue }
            text.replaceSubrange(text.index(text.startIndex, offsetBy: range.lowerBound) ..< text.index(text.startIndex, offsetBy: range.upperBound), with: replaceText)
        }
        
        // Set text
        self.text = text
        
        // Clear selected text range
        selectedTextRange = nil
    }
    
    public func deleteBackward() {
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
    
    public var selectedTextRange: UITextRange? {
        get {
            return selectedSTTextRange
        }
        set {
            // Set selected text range
            if let range = newValue as? STTextRange {
                selectedSTTextRange = range
            }
            else {
                selectedSTTextRange = STTextRange(range: 0 ..< 0)
            }
            
            // Set needs display
            label.setNeedsDisplay()
            
            // Set needs layout
            setNeedsLayout()
        }
    }
    
    public var selectedText: String? {
        // Get range
        guard let range = selectedTextRange as? STTextRange else { return nil }
        guard range.range.lowerBound < range.range.upperBound else { return nil }
        
        // Decide selected text
        guard let text = text else { return nil }
        return String(text[range.range(text: text)])
    }
    
    public var markedTextRange: UITextRange? {
        get {
            return markedSTTextRange
        }
        set {
            markedSTTextRange = newValue as? STTextRange
        }
    }
    
    public var markedTextStyle: [NSAttributedString.Key: Any]? {
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
    
    public func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        // Do not use this method
    }
    
    public func setAttributedMarkedText(_ markedAttrStr: NSAttributedString?, selectedRange: NSRange) {
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
    
    public func unmarkText() {
        // Clear marked text range
        markedTextRange = nil
        markedRanges = nil
        
        // Register undo
        _undoManager.register()
    }
    
    //--------------------------------------------------------------//
    // MARK: - Range and positions
    //--------------------------------------------------------------//
    
    public func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        // Create range
        guard let fromIndex = (fromPosition as? STTextPosition)?.index else { return nil }
        guard let toIndex = (toPosition as? STTextPosition)?.index else { return nil }
        return fromIndex < toIndex ? STTextRange(range: fromIndex ..< toIndex) : STTextRange(range: toIndex ..< fromIndex)
    }
    
    public func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        // Create position
        guard let index = (position as? STTextPosition)?.index else { return nil }
        guard let text = text else { return nil }
        var shiftedIndex = index + offset
        if shiftedIndex < 0 { shiftedIndex = 0 }
        else if shiftedIndex >= text.count { shiftedIndex = text.count }
        return STTextPosition(index: shiftedIndex)
    }
    
    public func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        return nil
    }
    
    public var beginningOfDocument: UITextPosition {
        // Create text position
        return STTextPosition(index: 0)
    }
    
    public var endOfDocument: UITextPosition {
        // Create text position
        return STTextPosition(index: label.text?.count ?? 0)
    }
    
    //--------------------------------------------------------------//
    // MARK: - Range and positions
    //--------------------------------------------------------------//
    
    public func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        // Compare index
        guard let index = (position as? STTextPosition)?.index, let otherInex = (other as? STTextPosition)?.index else { return .orderedSame }
        if index < otherInex { return .orderedAscending }
        else if index > otherInex { return .orderedDescending }
        else { return .orderedSame }
    }
    
    public func offset(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> Int {
        // Calc offset
        guard let fromIndex = (fromPosition as? STTextPosition)?.index else { return 0 }
        guard let toIndex = (toPosition as? STTextPosition)?.index else { return 0 }
        return toIndex - fromIndex 
    }
    
    //--------------------------------------------------------------//
    // MARK: - Layout and writing direction
    //--------------------------------------------------------------//
    
    public func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        return nil
    }
    
    public func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        return nil
    }
    
    public func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        return .leftToRight
    }
    
    public func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {
    }
    
    //--------------------------------------------------------------//
    // MARK: - Geometry and hit-testing
    //--------------------------------------------------------------//
    
    static let underlineMargin: CGFloat = 4
    static let caretWidth: CGFloat = 2
    
    public func firstRect(for range: UITextRange) -> CGRect {
        // Get run
        let index = (range as! STTextRange).range.lowerBound
        guard index >= 0, index < label.context.runs.count else { return .zero }
        let run = label.context.runs[index]
        
        // Decide rect
        var frame = run.frame
        frame.size.height += Self.underlineMargin
        
        return convert(frame, from: label)
    }
    
    public func caretRect(for position: UITextPosition) -> CGRect {
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
    
    public func closestPosition(to point: CGPoint) -> UITextPosition? {
        // Convert point
        let point = convert(point, to: label)
        
        // Get closest run ID
        let runId = label.context.closestRunIndex(to: point)
        return STTextPosition(index: runId)
    }
    
    public func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        // Get range
        var selectionRects = [STTextSelectionRect]()
        let range = (range as! STTextRange).range
        
        // For length 0
        if range.lowerBound == range.upperBound {
            // Decide selection rect
            let index = range.lowerBound
            if index >= label.context.runs.count, label.context.runs.count > 0 {
                // Use at end
                var runRect = label.context.runs[label.context.runs.count - 1].frame
                runRect.size.height += Self.underlineMargin
                switch direction {
                case .lrTb: selectionRects.append(.init(rect: .init(x: runRect.maxX, y: runRect.minY, width: 1, height: runRect.height), isVertical: false))
                case .tbRl: selectionRects.append(.init(rect: .init(x: runRect.minX, y: runRect.maxY, width: runRect.width, height: 1), isVertical: true))
                }
            }
            else if index < label.context.runs.count {
                // Use at begin
                var runRect = label.context.runs[index].frame
                runRect.size.height += Self.underlineMargin
                switch direction {
                case .lrTb: selectionRects.append(.init(rect: .init(x: runRect.minX, y: runRect.minY, width: 1, height: runRect.height), isVertical: false))
                case .tbRl: selectionRects.append(.init(rect: .init(x: runRect.minX, y: runRect.minY, width: runRect.width, height: 1), isVertical: true))
                }
            }
        }
        // For larger than runs
        else if range.lowerBound >= label.context.runs.count, label.context.runs.count > 0 {
            // Use at end
            var runRect = label.context.runs[label.context.runs.count - 1].frame
            runRect.size.height += Self.underlineMargin
            switch direction {
            case .lrTb: selectionRects.append(.init(rect: .init(x: runRect.maxX, y: runRect.minY, width: 1, height: runRect.height), isVertical: false))
            case .tbRl: selectionRects.append(.init(rect: .init(x: runRect.minX, y: runRect.maxY, width: runRect.width, height: 1), isVertical: true))
            }
        }
        // For other
        else {
            // Get selection rects
            for index in range.lowerBound ..< range.upperBound {
                // Add selection rect
                guard index >= 0, index < label.context.runs.count else { continue }
                var runRect = label.context.runs[index].frame
                runRect.size.height += Self.underlineMargin
                selectionRects.append(.init(rect: runRect, isVertical: direction == .tbRl))
            }
        }
        
        return selectionRects
    }
    
    public func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        // Convert point
        let point = convert(point, to: label)
        
        // Get closest run index
        let index = label.context.closestRunIndex(to: point)
        return STTextPosition(index: index)
    }
    
    public func characterRange(at point: CGPoint) -> UITextRange? {
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
    
    public var tokenizer: any UITextInputTokenizer {
        // Create tokenizer
        if _tokenizer == nil {
            _tokenizer = UITextInputStringTokenizer(textInput: self)
        }
        
        return _tokenizer!
    }
    
    public var inputDelegate: UITextInputDelegate? {
        get {
            return self
        }
        set (inputDelegate) {
        }
    }
}

extension STTextView: UITextInputDelegate {
    public func selectionWillChange(_ textInput: UITextInput?) {
    }
    
    public func selectionDidChange(_ textInput: UITextInput?) {
    }
    
    public func textWillChange(_ textInput: UITextInput?) {
    }
    
    public func textDidChange(_ textInput: UITextInput?) {
    }
    
    @available(iOS 18.4, *)
    public func conversationContext(_ context: UIConversationContext?, didChange textInput: (any UITextInput)?) {
    }
}
#endif
