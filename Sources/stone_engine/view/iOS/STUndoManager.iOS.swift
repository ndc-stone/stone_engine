/*
STUndoManager.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(iOS)
import UIKit

open class STUndoManager: UndoManager {
    struct STTextReplacement {
        let replacedText: String
        let insertedRange: STTextRange
        let selectedRanage: STTextRange
    }
    
    weak var textView: STTextView?
    
    var stackedTextReplacements: [STTextReplacement] = []
    
    open override var canUndo: Bool {
        // Invoke super
        if super.canUndo { return true }
        
        // Check stacked text replacements
        return stackedTextReplacements.count > 0
    }
    
    open override func undo() {
        // Register
        register()
        
        // Invoke super
        super.undo()
    }
    
    func stackTextReplacement(replacedText: String, insertedRange: STTextRange, selectedRanage: STTextRange) {
        // Check undoing
        guard !isUndoing && !isRedoing else { return }
        
        // Add text replacement
        stackedTextReplacements.append(.init(
            replacedText: replacedText, insertedRange: insertedRange, selectedRanage: selectedRanage
        ))
    }
    
    func register() {
        // Register undo
        guard let textView else { return }
        guard stackedTextReplacements.count > 0 else { return }
        let textReplacements = stackedTextReplacements
        registerUndo(withTarget: textView) { textView in
            // Get text replace ment
            for textReplacement in textReplacements.reversed() {
                // Replace text
                textView.replaceText(
                    textReplacement.replacedText, 
                    textRange: textReplacement.insertedRange
                )
                
                // Set selected range
                textView.selectedTextRange = textReplacement.selectedRanage
                
                // Clear marked text range
                textView.markedTextRange = nil
            }
        }
        
        // Clear stacked text replacements
        stackedTextReplacements.removeAll()
    }
}
#endif
