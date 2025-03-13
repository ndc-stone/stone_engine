/*
STTextView+TextInput.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center. All rights reserved.
This software is licensed under the MIT License. See LICENSE for details.
*/

import UIKit

public class STTextPosition: UITextPosition, Comparable {
    // Index
    public var index: Int

    // Initialize
    public init(index: Int) {
        self.index = index
    }
    
    public init(position: STTextPosition, offset: Int){
        index = position.index + offset
    }
    
    public override var description: String {
        return "\(index)"
    }
    
    // Comparable
    public static func <(lhs: STTextPosition, rhs: STTextPosition) -> Bool {
        return lhs.index < rhs.index
    }
}

public class STTextRange: UITextRange {
    // Range
    var range: Range<Int>
    
    // Initialize
    public init(range: Range<Int>) {
        self.range = range
    }
    
    public init(start: STTextPosition, end: STTextPosition) {
        range = start.index ..< end.index
    }
    
    public override var description: String {
        return "(\(range.lowerBound), \(range.upperBound))"
    }
    
    // UITextRange
    public override var start: STTextPosition { STTextPosition(index: range.lowerBound) }
    public override var end: STTextPosition { STTextPosition(index: range.upperBound) }
    public override var isEmpty: Bool { range.isEmpty }

    // String.Index
    public func range(text: String) -> Range<String.Index> {
        if range.upperBound >= text.count {
            return text.index(text.startIndex, offsetBy: range.lowerBound) ..< text.endIndex
        }
        
        return text.index(text.startIndex, offsetBy: range.lowerBound) ..< text.index(text.startIndex, offsetBy: range.upperBound)
    }
    
    public func nsRange(in text: String) -> NSRange? {
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
