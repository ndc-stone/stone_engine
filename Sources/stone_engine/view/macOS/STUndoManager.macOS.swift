/*
STUndoManager.swift

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
        // Close the pending group, so the edits made since the last boundary
        // become one undo step
        register()

        // Invoke super
        super.undo()
    }

    open override func redo() {
        // Edits made after an undo are still pending here, so UndoManager has
        // not seen them and would keep a stale redo action alive. Registering
        // them now clears the redo stack, exactly as a fresh edit should.
        register()

        // Invoke super
        super.redo()
    }

    func stackTextReplacement(replacedText: String, insertedRange: STTextRange, selectedRanage: STTextRange) {
        // Add text replacement.
        //
        // This is also called while undoing or redoing, from inside the block
        // registered below. What piles up there is the inverse of the edit being
        // applied, and register() at the end of that block hands it to
        // UndoManager, which files it on the opposite stack. That is what makes
        // redo work.
        stackedTextReplacements.append(.init(
            replacedText: replacedText, insertedRange: insertedRange, selectedRanage: selectedRanage
        ))
    }

    func register() {
        // Register undo
        guard let textView else { return }
        guard stackedTextReplacements.count > 0 else { return }
        let textReplacements = stackedTextReplacements

        // Clear before registering. The block below calls register() again for
        // the inverse, and it must not see this batch.
        stackedTextReplacements.removeAll()

        registerUndo(withTarget: textView) { [weak self] textView in
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

            // Register the inverse, collected by replaceText above.
            // Called while undoing it lands on the redo stack, and while redoing
            // it lands back on the undo stack.
            self?.register()
        }
    }
}
#endif
