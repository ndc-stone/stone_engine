/*
STTextView+Lens.swift

Author: Makoto Kinoshita

Copyright 2024 HMDT. All rights reserved.
*/

import UIKit

extension STTextView {
    //--------------------------------------------------------------//
    // MARK: - Lens
    //--------------------------------------------------------------//

    var lensCenter: CGPoint? {
        // For knob view
        if beginKnobView.superview != nil && endKnobView.superview != nil {
            // Get begin and end frame
            let beginFrame = beginKnobView.frame
            let endFrame = endKnobView.frame
            
            // Decide point
            var point: CGPoint?
            if let isBeginKnobDragging = isBeginKnobDragging {
                if isBeginKnobDragging { point = CGPoint(x: beginFrame.midX, y: beginFrame.midY) }
                else { point = CGPoint(x: endFrame.midX, y: endFrame.midY) }
            }
            else if isLongPressing {
                let x = beginFrame.midX + (endFrame.midX - beginFrame.midX) * 0.5
                let y = beginFrame.midY
                point = CGPoint(x: x, y: y)
            }
            
            return point
        }
        // For cursor
        else if !cursorView.isHidden {
            // Get cursor frame
            let frame = cursorView.frame
            
            // Decide point
            return .init(x: frame.midX, y: frame.midY)
        }
        
        return nil
    }
    
    var lensFrame: CGRect? {
        // Get lens center
        guard let center = lensCenter else { return nil }
        
        // Decide frame
        var rect = CGRect.zero
        switch direction {
        case .lrTb:
            rect.size.width = 180
            rect.size.height = 60
            rect.origin.x = center.x - rect.width * 0.5
            rect.origin.y = center.y - label.context.fontSize * 0.5 - 24 - rect.height
        case .tbRl:
            rect.size.width = 60
            rect.size.height = 180
            rect.origin.x = center.x - label.context.fontSize * 0.5 - 20 - rect.width
            rect.origin.y = center.y - rect.height * 0.5
        }
        
        return rect
    }
    
    var lensImage: UIImage? {
        // Get point for lens image
        guard let center = lensCenter else { return nil }
        let point = convert(center, to: label)
        
        // Create context
        let scale: CGFloat = 2
        let width = Int(256 * scale)
        let height = Int(256 * scale)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let rawData = malloc(height * bytesPerRow)
        let bitsPerComponent = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: rawData, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return nil }
        
        // Transform context
        context.translateBy(x: CGFloat(width) * 0.5, y: CGFloat(height) * 0.5)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -point.x, y: -point.y)
        
        // Draw label
        label.layer.draw(in: context)
        
        // Draw cursor
        context.setFillColor(UIColor.label.cgColor)
        var frame = cursorView.frame
        switch direction {
        case .lrTb:
            frame.origin.x -= 120
        case .tbRl:
            frame.origin.y -= 52
        }
        context.fill(frame)
        
        // Get image
        guard let cgImage = context.makeImage() else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .downMirrored)
    }
}

extension STTextView {
    //--------------------------------------------------------------//
    // MARK: - Appeanrace for lens
    //--------------------------------------------------------------//
    
    private var isLensShown: Bool { lensView.superview != nil }
    
    private func showLensView() {
        // Add subview
        window?.addSubview(lensView)
        
        // Set lens frame
        guard let frame = lensFrame else { return }
        lensView.frame = lensView.superview!.convert(frame, from: self)
        
        // Do animation
        lensView.transform = .init(scaleX: 0.001, y: 0.001)
        lensView.alpha = 0
        UIView.animate(withDuration: 0.15, delay: 0) { 
            self.lensView.transform = .identity
            self.lensView.alpha = 1
        }
    }
    
    private func moveLensView() {
        // Get lens frame
        guard let frame = lensFrame else { return }
        
        // Do animation
        UIView.animate(withDuration: 0.1) { 
            // Set lens frame
            self.lensView.frame = self.lensView.superview!.convert(frame, from: self)
        }
    }
    
    private func hideLensView() {
        // Do animation
        UIView.animate(withDuration: 0.15, delay: 0) { 
            self.lensView.transform = .init(scaleX: 0.001, y: 0.001)
            self.lensView.alpha = 0
        } completion: { success in
            // Remove subview
            self.lensView.transform = .identity
            self.lensView.alpha = 1
            self.lensView.removeFromSuperview()
        }
    }
    
    func updateLens() {
        // For needs to show lens
        let needsToShowLens = needsToShowLens ?? false
        if needsToShowLens {
            // Update lens image
            lensView.labelImageView.image = lensImage
            
            // Show lens
            if !isLensShown { showLensView() }
            // Move lens
            else { moveLensView() }
        }
        // For needs to hide lens
        else {
            // Hide lens
            if isLensShown { hideLensView() }
        }
    }
    
    func setNeedsToUpdateLens(_ needsToShowLens: Bool) {
        // Check flag
        guard needsToShowLens || self.needsToShowLens != needsToShowLens else { return }
        self.needsToShowLens = needsToShowLens
        
        // Wait a moment
        DispatchQueue.main.async {
            // Update appearance
            self.updateLens()
        }
    }
}

