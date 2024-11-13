/*
STCursorView.swift

Author: Makoto Kinoshita

Copyright 2024 HMDT. All rights reserved.
*/

import UIKit

class STCursorView: UIView {
    // Views
    var cursorLayer: CALayer!
    
    //--------------------------------------------------------------//
    // MARK: - Initialize
    //--------------------------------------------------------------//
    
    private func _init() {
        // Create cursor layer
        cursorLayer = CALayer()
        layer.addSublayer(cursorLayer)
    }
    
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
    
    //--------------------------------------------------------------//
    // MARK: - Appearance
    //--------------------------------------------------------------//
    
    private func updateLayerColor() {
        // Set layer background color
        cursorLayer.backgroundColor = UIColor.label.cgColor
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
