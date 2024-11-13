/*
STKnobView.swift

Author: Makoto Kinoshita

Copyright 2022 HMDT. All rights reserved.
*/

import UIKit

class STKnobView: UIView {
    static let knobWide: CGFloat = 40
    static let headWide: CGFloat = 10
    static let barWidth: CGFloat = 2
    
    // Properties
    var isHorizontal: Bool = false {
        didSet {
            // Set needs layout
            layer.setNeedsLayout()
        }
    }
    var isAtBegin: Bool = false {
        didSet {
            // Set needs layout
            layer.setNeedsLayout()
        }
    }
    
    // Views
    var headLayer: CALayer!
    var barLayer: CALayer!
    
    //--------------------------------------------------------------//
    // MARK: - Initialize
    //--------------------------------------------------------------//
    
    private func _init() {
        // Create head layer
        headLayer = CALayer()
        headLayer.cornerRadius = Self.headWide * 0.5
        layer.addSublayer(headLayer)
        
        // Create bar layer
        barLayer = CALayer()
        layer.addSublayer(barLayer)
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
    
    //--------------------------------------------------------------//
    // MARK: - View
    //--------------------------------------------------------------//
    
    override func didMoveToWindow() {
        // Invoke super
        super.didMoveToWindow()
        
        // Update appearance
        updateLayerColor()
    }
    
    //--------------------------------------------------------------//
    // MARK: - Appearance
    //--------------------------------------------------------------//
    
    private func updateLayerColor() {
        // Set layer background color
        //headLayer.backgroundColor = UIColor.darkest(userInterfaceStyle: traitCollection.userInterfaceStyle).cgColor
        //barLayer.backgroundColor = UIColor.darkest(userInterfaceStyle: traitCollection.userInterfaceStyle).cgColor
        headLayer.backgroundColor = UIColor.label.cgColor
        barLayer.backgroundColor = UIColor.label.cgColor
    }
    
    //--------------------------------------------------------------//
    // MARK: - Layout
    //--------------------------------------------------------------//
    
    private func layoutSublayersH(of layer: CALayer) {
        var rect = CGRect.zero
        
        // Layout head layer
        rect.size.width = Self.headWide
        rect.size.height = Self.headWide
        rect.origin.x = (bounds.width - rect.width) * 0.5
        if isAtBegin {
            rect.origin.y = 0
        }
        else {
            rect.origin.y = bounds.height - rect.height
        }
        headLayer.frame = rect
        
        // Layout bar layer
        rect.size.width = Self.barWidth
        rect.size.height = bounds.height - Self.headWide * 1.5
        rect.origin.x = (bounds.width - rect.width) * 0.5
        if isAtBegin {
            rect.origin.y = Self.headWide * 0.5
        }
        else {
            rect.origin.y = Self.headWide
        }
        barLayer.frame = rect
    }
    
    private func layoutSublayersV(of layer: CALayer) {
        var rect = CGRect.zero
        
        // Layout head layer
        rect.size.width = Self.headWide
        rect.size.height = Self.headWide
        if isAtBegin {
            rect.origin.x = bounds.width - rect.width
        }
        else {
            rect.origin.x = 0
        }
        rect.origin.y = (bounds.height - rect.height) * 0.5
        headLayer.frame = rect
        
        // Layout bar layer
        rect.size.width = bounds.width - Self.headWide * 1.5
        rect.size.height = Self.barWidth
        if isAtBegin {
            rect.origin.x = Self.headWide
        }
        else {
            rect.origin.x = Self.headWide * 0.5
        }
        rect.origin.y = (bounds.height - rect.height) * 0.5
        barLayer.frame = rect
    }
    
    override func layoutSublayers(of layer: CALayer) {
        // Invoke super
        super.layoutSublayers(of: layer)
        
        // Layout head and bar layer
        if isHorizontal { layoutSublayersH(of: layer) }
        else { layoutSublayersV(of: layer) }
    }
}
