/*
STLensView.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center. All rights reserved.
This software is licensed under the MIT License. See LICENSE for details.
*/

import UIKit

class STLensView: UIView {
    // Views
    var labelImageView: UIImageView!
    
    //--------------------------------------------------------------//
    // MARK: - Initialize
    //--------------------------------------------------------------//
    
    private func _init() {
        // Configure itself
        layer.borderWidth = 1
        layer.cornerRadius = 30
        
        // Create label image view
        labelImageView = UIImageView(frame: .zero)
        labelImageView.contentMode = .center
        labelImageView.clipsToBounds = true
        labelImageView.layer.cornerRadius = 30
        addSubview(labelImageView)
        
        // Update appearance
        updateLayerColor()
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
        // Set layer border color
        layer.borderColor = UIColor.light.cgColor
        labelImageView.backgroundColor = .lightest
    }
    
    //--------------------------------------------------------------//
    // MARK: - Layout
    //--------------------------------------------------------------//
    
    override func layoutSublayers(of layer: CALayer) {
        var rect = CGRect.zero
        
        // Invoke super
        super.layoutSublayers(of: layer)
        
        // Layout label image view
        rect = bounds
        labelImageView.frame = rect
    }
}
