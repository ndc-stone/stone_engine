/*
STTextViewLensSupport.swift

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
open class STTextViewLensSupport {
    //--------------------------------------------------------------//
    // MARK: - Properties
    //--------------------------------------------------------------//
    
    weak var textView: STTextView?
    
    //--------------------------------------------------------------//
    // MARK: - Initialization
    //--------------------------------------------------------------//
    
    public init(textView: STTextView) {
        self.textView = textView
    }
    
    //--------------------------------------------------------------//
    // MARK: - Lens
    //--------------------------------------------------------------//

    open var lensCenter: CGPoint? {
        guard let textView = textView else { return nil }
        
        // For knob view
        if let isBeginKnobDragging = textView.isBeginKnobDragging, textView.beginKnobView.superview != nil, textView.endKnobView.superview != nil {
            // Get begin and end frame
            let beginFrame = textView.beginKnobView.frame
            let endFrame = textView.endKnobView.frame
            
            // Decide point
            let point: CGPoint
            if isBeginKnobDragging { point = CGPoint(x: beginFrame.midX, y: beginFrame.midY) }
            else { point = CGPoint(x: endFrame.midX, y: endFrame.midY) }
            
            return point
        }
        
        // Get rect at index
        guard let range = (textView.selectedTextRange as? STTextRange)?.range else { return nil }
        let startIndex = range.lowerBound
        let endIndex = range.upperBound < textView.label.context.runs.count ? range.upperBound : range.upperBound - 1
        let startFrame = textView.convert(textView.label.context.runs[startIndex].frame, from: textView.label)
        let endFrame = textView.convert(textView.label.context.runs[endIndex].frame, from: textView.label)
        
        // Decide point
        return .init(x: (startFrame.midX + endFrame.midX) * 0.5, y: (startFrame.midY + endFrame.midY) * 0.5)
    }
    
    open var lensFrame: CGRect? {
        guard let textView = textView else { return nil }
        
        // Get lens center
        guard let center = lensCenter else { return nil }
        
        // Decide frame
        var rect = CGRect.zero
        switch textView.direction {
        case .lrTb:
            rect.size.width = 180
            rect.size.height = 60
            rect.origin.x = center.x - rect.width * 0.5
            rect.origin.y = center.y - textView.label.context.fontSize * 0.5 - 24 - rect.height
        case .tbRl:
            rect.size.width = 60
            rect.size.height = 180
            rect.origin.x = center.x - textView.label.context.fontSize * 0.5 - 20 - rect.width
            rect.origin.y = center.y - rect.height * 0.5
        }
        
        return rect
    }
    
    open var lensBackgroundColor: UIColor {
        // Decide background color
        var backgroundColor = UIColor.systemBackground
        var view: UIView? = textView?.label
        while view != nil {
            // Check background color
            if let color = view?.backgroundColor {
                var alpha: CGFloat = 1
                color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
                if alpha > 0.001 {
                    backgroundColor = color
                    break
                }
            }
            
            // Set parent
            view = view?.superview
        }
        
        return backgroundColor
    }
    
    open var lensImage: UIImage? {
        guard let textView = textView else { return nil }
        
        // Get point for lens image
        guard let center = lensCenter else { return nil }
        let point = textView.convert(center, to: textView.label)
        
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
        
        /*
        // Decide background color
        var backgroundColor = UIColor.systemBackground
        var view: UIView? = textView.label
        while view != nil {
            // Check background color
            if let color = view?.backgroundColor {
                var alpha: CGFloat = 1
                color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
                if alpha > 0.001 {
                    backgroundColor = color
                    break
                }
            }
            
            // Set parent
            view = view?.superview
        }
        */
        
        // Fill context
        context.setFillColor(lensBackgroundColor.cgColor)
        context.fill(.init(x: 0, y: 0, width: width, height: height))
        
        // Transform context
        context.translateBy(x: CGFloat(width) * 0.5, y: CGFloat(height) * 0.5)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -point.x, y: -point.y)
        
        // Draw label
        textView.label.layer.draw(in: context)
        
        // For selected
        if let range = (textView.selectedTextRange as? STTextRange)?.range {
            // Draw cursor
            context.setFillColor(textView.label.textColor.cgColor)
            context.fill(textView.label.context.cursorFrame(at: range.lowerBound))
            context.fill(textView.label.context.cursorFrame(at: range.upperBound))
        }
        
        // Get image
        guard let cgImage = context.makeImage() else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .downMirrored)
    }
    
    //--------------------------------------------------------------//
    // MARK: - Appeanrace for lens
    //--------------------------------------------------------------//
    
    open var isLensShown: Bool {
        guard let textView = textView else { return false }
        return textView.lensView.superview != nil
    }
    
    open func showLensView() {
        guard let textView = textView else { return }
        
        // Add subview
        textView.window?.addSubview(textView.lensView)
        
        // Set initial geometry
        guard let frame = lensFrame else { return }
        textView.lensView.frame = textView.lensView.superview!.convert(frame, from: textView)
        textView.lensView.transform = .init(scaleX: 0.001, y: 0.001)
        textView.lensView.alpha = 0
        textView.lensView.layoutIfNeeded()
        
        // Do animation
        UIView.animate(withDuration: 0.15, delay: 0) { 
            textView.lensView.transform = .identity
            textView.lensView.alpha = 1
        }
    }
    
    open func moveLensView() {
        guard let textView = textView else { return }
        
        // Get lens frame
        guard let frame = lensFrame else { return }
        
        // Do animation
        UIView.animate(withDuration: 0.2) { 
            // Set lens frame
            textView.lensView.frame = textView.lensView.superview!.convert(frame, from: textView)
        }
    }
    
    open func hideLensView() {
        guard let textView = textView else { return }
        
        // Do animation
        UIView.animate(withDuration: 0.15, delay: 0) { 
            textView.lensView.transform = .init(scaleX: 0.001, y: 0.001)
            textView.lensView.alpha = 0
        } completion: { success in
            // Remove subview
            textView.lensView.transform = .identity
            textView.lensView.alpha = 1
            textView.lensView.removeFromSuperview()
        }
    }
    
    open func updateLens() {
        guard let textView = textView else { return }
        
        // For needs to show lens
        let needsToShowLens = textView.needsToShowLens ?? false
        if needsToShowLens {
            // Update lens image
            textView.lensView.labelImageView.image = lensImage
            
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
    
    open func setNeedsToUpdateLens(_ needsToShowLens: Bool) {
        guard let textView = textView else { return }
        
        // Check flag
        guard needsToShowLens || textView.needsToShowLens != needsToShowLens else { return }
        textView.needsToShowLens = needsToShowLens
        
        // Wait a moment
        DispatchQueue.main.async {
            // Update appearance
            self.updateLens()
        }
    }
}
#endif
#endif
