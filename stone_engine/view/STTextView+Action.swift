/*
STTextView+Action.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center. All rights reserved.
This software is licensed under the MIT License. See LICENSE for details.
*/

import UIKit

extension STTextView {
    //--------------------------------------------------------------//
    // MARK: - Action
    //--------------------------------------------------------------//
    
    @objc func tapAction(_ recognizer: UITapGestureRecognizer) {
        // For not first responder
        if !isFirstResponder {
            // Make itself first responder
            let _ = becomeFirstResponder()
        }
        
        // Get point and index
        let point = recognizer.location(in: label)
        let index = label.context.closestRunIndex(to: point)
        let hitIndex = label.context.hitRunIndex(to: point)
        
        // Get modifiers
        let shift = recognizer.modifierFlags.contains(.shift)
        
        // For shift modifier
        if shift {
            if index < selectedSTTextRange.range.lowerBound {
                selectedSTTextRange = STTextRange(range: index ..< selectedSTTextRange.range.upperBound)
            }
            else if index > selectedSTTextRange.range.upperBound {
                selectedSTTextRange = STTextRange(range: selectedSTTextRange.range.lowerBound ..< index)
            }
        }
        // For other
        else {
            // For same with selected text range
            if selectedSTTextRange.range.lowerBound == hitIndex, selectedSTTextRange.range.upperBound == hitIndex, selectedSTTextRange.range.count == 0 {
                // Needs to show menu
                setNeedsToUpdateMenu(true)
            }
            // For other
            else {
                // Needs to hide menu
                setNeedsToUpdateMenu(false)
                
                // Set new selected text range
                selectedSTTextRange = STTextRange(range: index ..< index)
            }
        }
    }
    
    @objc func longPressAction(_ recognizer: UITapGestureRecognizer) {
        // Get text position
        let point = recognizer.location(in: self)
        guard let closestTextPosition = closestPosition(to: point) as? STTextPosition else { return }
        let hitTextPosition = hitPosition(to: point) as? STTextPosition
        let textCount = text?.count ?? 0
        
        // Switch by state
        switch recognizer.state {
        case .began:
            // Set long press point
            longPressPoint = point
            
            // Select text
            if textCount > 0, hitTextPosition != nil, closestTextPosition.index <= textCount {
                if closestTextPosition.index == textCount {
                    selectedTextRange = STTextRange(range: closestTextPosition.index - 1 ..< closestTextPosition.index)
                }
                else {
                    selectedTextRange = STTextRange(range: closestTextPosition.index ..< closestTextPosition.index + 1)
                }
            }
            
            // Needs to show lens
            setNeedsToUpdateLens(true)
        case .changed:
            // Set long press point
            longPressPoint = point
            
            // Select text
            if textCount > 0, hitTextPosition != nil, closestTextPosition.index <= textCount {
                if closestTextPosition.index == textCount {
                    selectedTextRange = STTextRange(range: closestTextPosition.index - 1 ..< closestTextPosition.index)
                }
                else {
                    selectedTextRange = STTextRange(range: closestTextPosition.index ..< closestTextPosition.index + 1)
                }
            }
            
            // Needs to show lens
            setNeedsToUpdateLens(true)
        case .ended, .cancelled:
            // Clear long press point
            longPressPoint = nil
            
            // Needs to hide lens
            setNeedsToUpdateLens(false)
            
            // Needs to show menu
            setNeedsToUpdateMenu(true)
        default: break
        }
    }
    
    @objc func trackpadPanAction(_ recognizer: UITapGestureRecognizer) {
    }
    
    @objc func knobPanAction(_ recognizer: UIPanGestureRecognizer) {
        // Get text position
        let point = recognizer.location(in: self)
        guard let textRange = selectedTextRange as? STTextRange else { return }
        guard let textPosition = closestPosition(to: point) as? STTextPosition else { return }
        
        // Switch by state
        switch recognizer.state {
        case .began:
            // Set knob dragging
            if recognizer.view === beginKnobView {
                isBeginKnobDragging = true
                dragPivotIndex = textRange.range.upperBound
            }
            else {
                isBeginKnobDragging = false
                dragPivotIndex = textRange.range.lowerBound
            }
            
            // Needs to show lens
            setNeedsToUpdateLens(true)
        case .changed:
            // Check with pivot
            guard let pivotIndex = dragPivotIndex else { return }
            if textPosition.index < pivotIndex {
                // Set selected text range
                isBeginKnobDragging = true
                selectedTextRange = STTextRange(range: textPosition.index ..< pivotIndex)
            }
            else if textPosition.index > pivotIndex {
                // Set selected text range
                isBeginKnobDragging = false
                selectedTextRange = STTextRange(range: pivotIndex ..< textPosition.index)
            }
            
            // Needs to show lens
            setNeedsToUpdateLens(true)
        case .ended, .cancelled:
            // Clear knob dragging
            isBeginKnobDragging = nil
            
            // Needs to show menu
            setNeedsToUpdateMenu(true)
            
            // Needs to hide lens
            setNeedsToUpdateLens(false)
        default: break
        }
    }
}

extension STTextView {
    //--------------------------------------------------------------//
    // MARK: - Menu
    //--------------------------------------------------------------//
    
    func setNeedsToUpdateMenu(_ needsToShowMenu: Bool) {
        /*
        // Check flag
        guard self.needsToShowMenu != needsToShowMenu else { return }
        self.needsToShowMenu = needsToShowMenu
        
        // Wait a moment
        DispatchQueue.main.async {
            // Update appearance
            //self.updateMenu()
            
            // Clear flag
            self.needsToShowMenu = nil
        }
        */
    }
}

extension STTextView: UIGestureRecognizerDelegate {
    //--------------------------------------------------------------//
    // MARK: - UIGestureRecognizerDelegate
    //--------------------------------------------------------------//
}

