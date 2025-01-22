/*
STCursorView.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center. All rights reserved.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if os(iOS)
class STCursorView: UIView {
    // Views
    var cursorLayer: CALayer!
    
    override init(frame: CGRect) {
        // Invoke super
        super.init(frame: frame)
        
        // Common init
        _init()
    }
    
    required init?(coder: NSCoder) {
        // Invoke super
        super.init(coder: coder)
        
        // Common init
        _init()
    }
}
#elseif os(macOS)
class STCursorView: NSView {
    // Views
    var cursorLayer: CALayer!
    
    override init(frame: CGRect) {
        // Invoke super
        super.init(frame: frame)
        
        // Common init
        _init()
    }
    
    required init?(coder: NSCoder) {
        // Invoke super
        super.init(coder: coder)
        
        // Common init
        _init()
    }
}
#endif

extension STCursorView {
    //--------------------------------------------------------------//
    // MARK: - Initialize
    //--------------------------------------------------------------//
    
    private func _init() {
        // Create cursor layer
        cursorLayer = CALayer()
        #if os(iOS)
        layer.addSublayer(cursorLayer)
        #elseif os(macOS)
        layer?.addSublayer(cursorLayer)
        #endif
    }
}

#if os(iOS)
extension STCursorView {
    //--------------------------------------------------------------//
    // MARK: - View
    //--------------------------------------------------------------//
    
    override func didMoveToWindow() {
        // Invoke super
        super.didMoveToWindow()
        
        // Update appearance
        updateLayerColor()
        updateHeartBeat()
    }
}
#endif

extension STCursorView {
    //--------------------------------------------------------------//
    // MARK: - Appearance
    //--------------------------------------------------------------//
    
    private func updateLayerColor() {
        // Set layer background color
        #if os(iOS)
        cursorLayer.backgroundColor = UIColor.label.cgColor
        #elseif os(macOS)
        cursorLayer.backgroundColor = NSColor.labelColor.cgColor
        #endif
    }
    
    private func updateHeartBeat() {
        // For window
        if window != nil {
            // Add opacity animation
            let opacityAnimation = CABasicAnimation()
            opacityAnimation.fromValue = 1
            opacityAnimation.toValue = 0
            opacityAnimation.duration = 0.75
            opacityAnimation.repeatCount = MAXFLOAT
            opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeIn)
            opacityAnimation.autoreverses = true
            cursorLayer.add(opacityAnimation, forKey: "opacity")
        }
        // For no window
        else {
            // Remove animation
            cursorLayer.removeAllAnimations()
        }
    }
}

#if os(iOS)
extension STCursorView {
    //--------------------------------------------------------------//
    // MARK: - Layout
    //--------------------------------------------------------------//
    
    override func layoutSublayers(of layer: CALayer) {
        // Invoke super
        super.layoutSublayers(of: layer)
        
        // Layout cursor layer without animation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        cursorLayer.frame = bounds
        CATransaction.commit()
    }
}
#endif
