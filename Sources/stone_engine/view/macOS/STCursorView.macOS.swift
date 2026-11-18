/*
STCursorView.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(macOS)
import Cocoa

open class STCursorView: NSView {
    //--------------------------------------------------------------//
    // MARK: - Initialize
    //--------------------------------------------------------------//
    
    private func _init() {
        // Configure itself
        wantsLayer = true
    }
    
    public override init(frame frameRect: NSRect) {
        // Invoke super
        super.init(frame: frameRect)
        
        // Common init
        _init()
    }
    
    public required init?(coder: NSCoder) {
        // Invoke super
        super.init(coder: coder)
        
        // Common init
        _init()
    }
    
    //--------------------------------------------------------------//
    // MARK: - View
    //--------------------------------------------------------------//

    open override func viewDidMoveToWindow() {
        // Invoke super
        super.viewDidMoveToWindow()

        // Start or stop blinking
        if window != nil {
            startBlinking()
        }
        else {
            stopBlinking()
        }
    }

    //--------------------------------------------------------------//
    // MARK: - Blinking
    //--------------------------------------------------------------//

    private static let blinkAnimationKey = "blink"

    open func startBlinking() {
        // Create blinking animation
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [1.0, 1.0, 0.0, 0.0]
        animation.keyTimes = [0.0, 0.5, 0.5, 1.0]
        animation.calculationMode = .discrete
        animation.duration = 1.06
        animation.repeatCount = .greatestFiniteMagnitude

        // Add animation
        layer?.add(animation, forKey: STCursorView.blinkAnimationKey)
    }

    open func stopBlinking() {
        // Remove animation
        layer?.removeAnimation(forKey: STCursorView.blinkAnimationKey)
    }

    open func resetBlinking() {
        // Restart the blink phase only while shown
        guard window != nil else { return }
        startBlinking()
    }

    //--------------------------------------------------------------//
    // MARK: - Drawing
    //--------------------------------------------------------------//

    // Cursor color
    open var color: NSColor = .labelColor {
        didSet {
            // Set needs display
            needsDisplay = true
        }
    }

    open override func draw(_ dirtyRect: NSRect) {
        // Set color
        color.setFill()

        // Fill rect
        bounds.fill()
    }
}
#endif
