/*
STTextView+TextInput.swift

Author: Makoto Kinoshita

Copyright 2024 HMDT. All rights reserved.
*/

import UIKit

class STTextPosition: UITextPosition, Comparable {
    // Index
    var index: Int
    
    // Initialize
    init(index: Int) {
        self.index = index
    }
    
    init(position: STTextPosition, offset: Int){
        index = position.index + offset
    }
    
    override var description: String {
        return "\(index)"
    }
    
    // Comparable
    static func <(lhs: STTextPosition, rhs: STTextPosition) -> Bool {
        return lhs.index < rhs.index
    }
}

class STTextRange: UITextRange {
    // Range
    var range: Range<Int>
    
    // Initialize
    init(range: Range<Int>) {
        self.range = range
    }
    
    init(start: STTextPosition, end: STTextPosition) {
        range = start.index ..< end.index
    }
    
    override var description: String {
        return "(\(range.lowerBound), \(range.upperBound))"
    }
    
    // UITextRange
    override var start: STTextPosition { STTextPosition(index: range.lowerBound) }
    override var end: STTextPosition { STTextPosition(index: range.upperBound) }
    override var isEmpty: Bool { range.isEmpty }
    
    // String.Index
    func range(text: String) -> Range<String.Index> {
        if range.upperBound >= text.count {
            return text.index(text.startIndex, offsetBy: range.lowerBound) ..< text.endIndex
        }
        
        return text.index(text.startIndex, offsetBy: range.lowerBound) ..< text.index(text.startIndex, offsetBy: range.upperBound)
    }
    
    func nsRange(in text: String) -> NSRange? {
        // Convert to NSRange
        return NSRange(range(text: text), in: text)
    }
}

class STTextSelectionRect: UITextSelectionRect {
    var _rect: CGRect
    var _isVertical: Bool
    
    var rectContainsStart: Bool
    var rectContainsEnd: Bool
    
    init(rect: CGRect, isVertical: Bool) {
        _rect = rect
        _isVertical = isVertical
        rectContainsStart = false
        rectContainsEnd = false
    }
    
    init(rect: CGRect, containsStart: Bool = false, containsEnd: Bool = false) {
        _rect = rect
        rectContainsStart = containsStart
        rectContainsEnd = containsEnd
        _isVertical = false
    }
    
    override var rect: CGRect { _rect }
    
    override var writingDirection: NSWritingDirection { .leftToRight }
    override var isVertical: Bool { _isVertical }
    
    override var containsStart: Bool { true }
    override var containsEnd: Bool { true }
}
