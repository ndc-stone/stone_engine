/*
STTextView+TextInput.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(macOS)
#if os(iOS)
import UIKit
#elseif os(macOS)
import Cocoa
#endif

#if os(iOS)
open class STTextPosition: UITextPosition, Comparable {
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

open class STTextRange: UITextRange {
    // Range
    public var range: Range<Int>
    
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
        if range.lowerBound >= text.count {
            return text.endIndex ..< text.endIndex
        }
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
#endif
#if os(macOS)
open class STTextPosition: NSObject, Comparable {
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

open class STTextRange: NSObject {
    // Range
    public var range: Range<Int>
    
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
    public var start: STTextPosition {
        STTextPosition(index: range.lowerBound)
    }
    
    public var end: STTextPosition {
        STTextPosition(index: range.upperBound)
    }
    
    public var isEmpty: Bool {
        range.isEmpty
    }
    
    // NSRange
    public var nsRange: NSRange {
        NSRange(location: range.lowerBound, length: range.upperBound - range.lowerBound)
    }

    // String.Index
    public func range(text: String) -> Range<String.Index> {
        if range.lowerBound >= text.count {
            return text.endIndex ..< text.endIndex
        }
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

class STTextSelectionRect: NSObject {
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
    
    // UITextSelectionRect
    var rect: CGRect { _rect }
    
    var writingDirection: NSWritingDirection { .leftToRight }
    var isVertical: Bool { _isVertical }
    
    var containsStart: Bool { true }
    var containsEnd: Bool { true }
}
#endif
#endif
