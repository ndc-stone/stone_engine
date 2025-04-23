/*
STLabel.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center. All rights reserved.
This software is licensed under the MIT License. See LICENSE for details.
*/

import UIKit

open class STLabel: UIView {
    // Text input
    open weak var textInput: UITextInput?

    // Text
    open var text: String? {
        didSet {
            // Set needs layout
            setNeedsLayout()
        }
    }
    
    // Layout
    open var fontSize: CGFloat {
        get { context.fontSize }
        set {
            context.fontSize = newValue
            setNeedsLayout()
        }
    }
    open var lineHeightScale: CGFloat {
        get { context.lineHeightScale }
        set {
            context.lineHeightScale = newValue
            setNeedsLayout()
        }
    }
    open var textAlign: STTextAlign {
        get { context.textAlign }
        set {
            context.textAlign = newValue
            setNeedsLayout()
        }
    }
    open var directionAlign: STDirectionAlign {
        get { context.directionAlign }
        set {
            context.directionAlign = newValue
            setNeedsLayout()
        }
    }
    open var direction: STDirection {
        get { context.direction }
        set {
            context.direction = newValue
            setNeedsLayout()
        }
    }
    open var isAllowedTateChuYoko: Bool {
        get { context.isAllowedTateChuYoko }
        set {
            context.isAllowedTateChuYoko = newValue
            setNeedsLayout()
        }
    }
    open var adjustsFontSizeToFitWidth: Bool {
        get { context.adjustsFontSizeToFitWidth }
        set {
            context.adjustsFontSizeToFitWidth = newValue
            setNeedsLayout()
        }
    }
    open var minimumScaleFactor: CGFloat {
        get { context.minimumScaleFactor }
        set {
            context.minimumScaleFactor = newValue
            setNeedsLayout()
        }
    }
    
    // Color
    open var textColor: UIColor {
        get { context.textColor }
        set {
            context.textColor = newValue
            setNeedsLayout()
        }
    }
    open var selectedAreaColor: UIColor {
        get { context.selectedAreaColor }
        set {
            context.selectedAreaColor = newValue
            setNeedsLayout()
        }
    }
    
    // Features
    open var punctuationMode: STPunctuationMode {
        get { context.punctuationMode }
        set {
            context.punctuationMode = newValue
            setNeedsLayout()
        }
    }
    open var isKinsokuAvailable: Bool {
        get { context.isKinsokuAvailable }
        set {
            context.isKinsokuAvailable = newValue
            setNeedsLayout()
        }
    }
    open var isDividedByWords: Bool {
        get { context.isDividedByWords }
        set {
            context.isDividedByWords = newValue
            setNeedsLayout()
        }
    }
    
    // Context
    public let context = STContext()

    private var needsToLayout: Bool = false
    
    //--------------------------------------------------------------//
    // MARK: - Layer
    //--------------------------------------------------------------//
    
    class open override var layerClass: AnyClass {
        // Use tiled layer
        return STTiledLayer.self
    }
    
    //--------------------------------------------------------------//
    // MARK: - Initialize
    //--------------------------------------------------------------//
    
    private func _init() {
        // Configure itself
        backgroundColor = .systemBackground
        layer.contentsGravity = .right
        (layer as? STTiledLayer)?.context = context
    }
    
    public override init(frame: CGRect) {
        // Invoke super
        super.init(frame: frame)
        
        // Common init
        _init()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        // Common init
        _init()
    }
    
    //--------------------------------------------------------------//
    // MARK: - Font
    //--------------------------------------------------------------//
    
    open func fontNames(script: STScript) -> [String] {
        // Pass to font manager
        return context.fontManager.fontNames(script: script)
    }
    
    open func setFontNames(_ fontNames: [String], script: STScript) {
        // Pass to font manager
        context.fontManager.setFontNames(fontNames, script: script)
        
        // Set needs layout
        setNeedsLayout()
    }
    
    open func fontScale(script: STScript) -> CGFloat {
        // Pass to font manager
        return context.fontManager.fontScale(script: script)
    }
    
    open func setFontScale(_ fontScale: CGFloat, script: STScript) {
        // Pass to font manager
        context.fontManager.setFontScale(fontScale, script: script)
        
        // Set needs layout
        setNeedsLayout()
    }
    
    //--------------------------------------------------------------//
    // MARK: - Layout
    //--------------------------------------------------------------//
    
    private func adjustWithScale(_ scale: CGFloat) -> Bool {
        // Set adjust font scale
        context.adjustFontScale = scale
        
        // Parse and layout
        STParser(context: context).parse(text: text)
        STLayout(context: context).layout()
        
        // Check truncated
        return !context.isTruncated
    }
    
    private func adjust() {
        // Check max and min scale
        guard minimumScaleFactor > 0 else { return }
        var maxScale: CGFloat = 1
        guard !adjustWithScale(maxScale) else { return }
        var minScale = minimumScaleFactor
        guard adjustWithScale(minScale) else { return }
        
        // Adjust scale
        var prevScale = minScale
        var scale = minScale + (maxScale - minScale) * 0.5
        var isAdjusted = false
        while abs(1.0 - prevScale / scale) > 0.05 || !isAdjusted {
            // Set prev scale
            prevScale = scale
            
            // Adjust with scale
            isAdjusted = adjustWithScale(scale)
            
            // Decide next scale
            if isAdjusted {
                scale = scale + (maxScale - scale) * 0.5
                minScale = prevScale
            }
            else {
                scale = minScale + (scale - minScale) * 0.5
                maxScale = prevScale
            }
        }
    }
    
    private func parseAndLayout() {
        // Set render size
        context.renderSize = bounds.size
        context.adjustFontScale = 1.0
        
        // Refresh font manager
        context.fontManager.refresh()
        
        // For adjust
        if adjustsFontSizeToFitWidth {
            adjust()
        }
        // For not adjust
        else {
            // Parse and layout
            STParser(context: context).parse(text: text)
            STLayout(context: context).layout()
        }
    }
    
    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        // Create copied context
        let context = STContext()
        context.fontSize = fontSize
        context.lineHeightScale = lineHeightScale
        context.textAlign = textAlign
        context.directionAlign = directionAlign
        context.direction = direction
        context.isAllowedTateChuYoko = isAllowedTateChuYoko
        context.adjustsFontSizeToFitWidth = adjustsFontSizeToFitWidth
        context.minimumScaleFactor = minimumScaleFactor
        context.isKinsokuAvailable = isKinsokuAvailable
        context.isDividedByWords = isDividedByWords
        
        // Set render size
        context.renderSize = size
        context.adjustFontScale = 1.0
        
        // Refresh font manager
        context.fontManager.refresh()
        
        // Parse and layout
        STParser(context: context).parse(text: text)
        STLayout(context: context).layout()
        
        // Get rendered size
        return context.renderedSize
    }
    
    open override func layoutSubviews() {
        // Invoke super
        super.layoutSubviews()
        
        // Parse and layout
        parseAndLayout()
        
        // Create draw buckets
        createDrawBcukets()
        
        // Set needs to display
        setNeedsDisplay()
    }
    
    private func alignLayerToRight(layer: CALayer) {
        // Check direction
        guard context.direction == .tbRl else { return }
        
        // Get content size
        guard let contentSize = (layer as? STTiledLayer)?.contentSize else { return }
        guard contentSize.width < frame.width && contentSize.height == frame.height else {
            layer.setAffineTransform(.identity)
            return
        }
        
        // Transform layer
        layer.setAffineTransform(.init(translationX: frame.width - contentSize.width, y: 0))
    }
    
    open override func layoutSublayers(of layer: CALayer) {
        // Invoke super
        super.layoutSublayers(of: layer)
        
        #if ALIGN_LAYER
        // Align layer to right
        alignLayerToRight(layer: layer)
        
        // Wait a moment
        DispatchQueue.main.async {
            // Align layer to right again
            self.alignLayerToRight(layer: layer)
        }
        #endif
    }
    
    open func layoutThatFits(_ size: CGSize) -> CGSize {
        // Check needs to layout
        guard needsToLayout || context.renderSize != size else { return context.renderedSize }
        
        // Layout
        context.renderSize = size
        STLayout(context: context).layout()
        
        // Clear flag
        needsToLayout = false
        
        // Get rendered size
        return context.renderedSize
    }
    
    //--------------------------------------------------------------//
    // MARK: - Draw
    //--------------------------------------------------------------//
    
    private func uniteRunRects(range: STTextRange, hasLineGap: Bool) -> [CGRect] {
        // Unite run rects
        var unitedRect = CGRect.zero
        var rects = [CGRect]()
        var prevLine = -1
        for i in range.range {
            // Get run and rect
            guard i < context.runs.count else { break }
            let run = context.runs[i]
            let rect = hasLineGap ? context.runFrameWithLineGap(at: i) : run.frame
            
            // For in same line
            if prevLine == run.line {
                // Unite rect
                if unitedRect.isEmpty { unitedRect = rect }
                else { unitedRect = unitedRect.union(rect) }
            }
            // For next line
            else {
                // Add united rect
                if !unitedRect.isEmpty { rects.append(unitedRect) }
                unitedRect = rect
            }
            
            // Set prev line
            prevLine = run.line
        }
        
        // Add last united rect
        if !unitedRect.isEmpty { rects.append(unitedRect) }
        
        // Adjust rects
        for i in 0 ..< rects.count {
            // Check min Y with prev max Y
            guard i > 0 else { continue }
            if abs(rects[i].minY - rects[i - 1].maxY) < 1 {
                var rect = rects[i]
                let maxY = rect.maxY
                rect.origin.y = rects[i - 1].maxY - 1
                rect.size.height = maxY - rect.origin.y
                rects[i] = rect
            }
            
            // Check max X and prev min X
            if abs(rects[i].maxX - rects[i - 1].minX) < 1 {
                var rect = rects[i]
                rect.size.width = rects[i - 1].minX - rect.minX + 1
                rects[i] = rect
            }
        }
        
        return rects
    }
    
    private func drawSelectedArea(_ dirtyRect: CGRect) {
        // Get selected text range
        guard let range = textInput?.selectedTextRange as? STTextRange else { return }
        
        // Get CG context
        guard let cgContext = UIGraphicsGetCurrentContext() else { return }
        
        // Set selected area color
        cgContext.setFillColor(selectedAreaColor.cgColor)
        
        // Unite selected run rects
        let rects = uniteRunRects(range: range, hasLineGap: true)
        
        // Fill rects
        for rect in rects {
            cgContext.fill(rect)
        }
    }
    
    struct DrawBucket {
        let fontId: Int
        let isClockwise: Bool
        let needsToFlip: Bool
        let ctFont: CTFont
        var glyphs: [CGGlyph]
        var positions: [CGPoint]
        var frames: [CGRect]
    }
    
    var drawBuckets = [DrawBucket]()
    
    private func createDrawBcukets() {
        // Create draw buckets
        var drawBuckets = [DrawBucket]()
        for run in context.runs {
            // Check visibility
            guard !run.isHidden else { continue }
            let isClockwise = context.isClockwise(run: run)
            let needsToFlip = context.fontManager.needsToFlip(fontId: run.fontId)
            
            // Find bucket
            let bucketIndex: Int
            if let index = drawBuckets.firstIndex(where: { $0.fontId == run.fontId && $0.isClockwise == isClockwise && $0.needsToFlip == needsToFlip }) {
                bucketIndex = index
            }
            else {
                // Get CT font
                let ctFont = context.fontManager.ctFont(fontId: run.fontId, size: context.adjustFontSize, isClockwise: isClockwise)
                
                // Add bucket
                drawBuckets.append(DrawBucket(fontId: run.fontId, isClockwise: isClockwise, needsToFlip: needsToFlip, ctFont: ctFont, glyphs: [], positions: [], frames: []))
                bucketIndex = drawBuckets.count - 1
            }
            
            // For ellipsis
            if run.visibility == .ellipsis {
                // Add ellipsis
                drawBuckets[bucketIndex].glyphs.append(context.fontManager.ellipsisGlyph(fontId: run.fontId, direction: context.direction))
                drawBuckets[bucketIndex].positions.append(run.position)
                drawBuckets[bucketIndex].frames.append(run.frame)
            }
            // For visible
            else if run.visibility == .visible {
                // Add glyph and position
                drawBuckets[bucketIndex].glyphs.append(run.glyph)
                drawBuckets[bucketIndex].positions.append(run.position)
                drawBuckets[bucketIndex].frames.append(run.frame)
            }
        }
        
        // Set draw buckets
        self.drawBuckets = drawBuckets
    }
    
    private func drawMarkedArea(_ dirtyRect: CGRect) {
        // Get CG context
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Get marked ranges
        guard let markedRanges = (textInput as? STTextView)?.markedRanges else { return }
        for markedRange in markedRanges {
            // Set fill color
            let color = markedRange.1 ? UIColor.label : UIColor.label.withAlphaComponent(0.5)
            context.setFillColor(color.cgColor)
            
            // Unite marked run rects
            let rects = uniteRunRects(range: STTextRange(range: markedRange.0), hasLineGap: false)
            
            // Fill rects
            for rect in rects {
                let lineRect: CGRect
                switch direction {
                case .lrTb: lineRect = CGRect(x: rect.minX + 1, y: rect.maxY, width: rect.width - 2, height: 2)
                case .tbRl: lineRect = CGRect(x: rect.minX, y: rect.minY + 1, width: 2, height: rect.height - 2)
                }
                context.fill(lineRect)
            }
        }
    }
    
    private func drawGlyphs(_ dirtyRect: CGRect) {
        // Get CG context
        guard let cgContext = UIGraphicsGetCurrentContext() else { return }
        
        // Set text color
        cgContext.setFillColor(context.textColor.cgColor)
        
        // Draw buckets
        for bucket in drawBuckets {
            // Draw glyphs
            if bucket.needsToFlip {
                for i in 0 ..< bucket.glyphs.count {
                    var transform: CGAffineTransform = .identity
                    transform = transform.translatedBy(x: 0, y: bucket.positions[i].y * 2)
                    transform = transform.scaledBy(x: 1, y: -1)
                    cgContext.saveGState()
                    cgContext.concatenate(transform)
                    CTFontDrawGlyphs(bucket.ctFont, [bucket.glyphs[i]], [bucket.positions[i]], 1, cgContext)
                    cgContext.restoreGState()
                }
            }
            else {
                CTFontDrawGlyphs(bucket.ctFont, bucket.glyphs, bucket.positions, bucket.glyphs.count, cgContext)
            }
        }
    }
    
    private func drawFrames(_ dirtyRect: CGRect) {
        // Get CG context
        guard let cgContext = UIGraphicsGetCurrentContext() else { return }
        
        // Set frame color
        cgContext.setStrokeColor(UIColor.blue.cgColor)
        
        // Draw frames
        for run in context.runs {
            cgContext.stroke(run.frame)
        }
    }
    
    open override func draw(_ dirtyRect: CGRect) {
        // Draw
        drawSelectedArea(dirtyRect)
        drawMarkedArea(dirtyRect)
        drawGlyphs(dirtyRect)
        
        // For test
        //drawFrames(dirtyRect)
    }
}
