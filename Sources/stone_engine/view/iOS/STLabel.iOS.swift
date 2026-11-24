/*
STLabel.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(iOS)
import UIKit
import QuartzCore

open class STLabel: UIView {
    // Text input
    open weak var textInput: UITextInput?

    // Text
    open var text: String? {
        didSet {
            // Check with old value
            guard oldValue != text else { return }
            
            // Set needs layout
            needsToLayout = true
            setNeedsLayout()
        }
    }
    
    // Layout
    open var fontSize: CGFloat {
        get {
            context.fontSize
        }
        set {
            // Check new value
            guard newValue != fontSize else { return }
            context.fontSize = newValue
            
            // Set needs layout
            needsToLayout = true
            setNeedsLayout()
        }
    }
    open var lineHeightScale: CGFloat {
        get {
            context.lineHeightScale
        }
        set {
            // Check new value
            guard newValue != lineHeightScale else { return }
            context.lineHeightScale = newValue
            
            // Set needs layout
            needsToLayout = true
            setNeedsLayout()
        }
    }
    open var textAlign: STTextAlign {
        get {
            context.textAlign
        }
        set {
            // Check new value
            guard newValue != textAlign else { return }
            context.textAlign = newValue
            
            // Set needs layout
            needsToLayout = true
            setNeedsLayout()
        }
    }
    open var directionAlign: STDirectionAlign {
        get {
            context.directionAlign
        }
        set {
            // Check new value
            guard newValue != directionAlign else { return }
            context.directionAlign = newValue
            
            // Set needs layout
            needsToLayout = true
            setNeedsLayout()
        }
    }
    open var direction: STDirection {
        get {
            context.direction
        }
        set {
            // Check new value
            guard newValue != direction else { return }
            context.direction = newValue
            
            // Set needs layout
            needsToLayout = true
            setNeedsLayout()
        }
    }
    open var isAllowedTateChuYoko: Bool {
        get {
            context.isAllowedTateChuYoko
        }
        set {
            // Check new value
            guard newValue != isAllowedTateChuYoko else { return }
            context.isAllowedTateChuYoko = newValue
            
            // Set needs layout
            needsToLayout = true
            setNeedsLayout()
        }
    }
    open var adjustsFontSizeToFitWidth: Bool {
        get {
            context.adjustsFontSizeToFitWidth
        }
        set {
            // Check new value
            guard newValue != adjustsFontSizeToFitWidth else { return }
            context.adjustsFontSizeToFitWidth = newValue
            
            // Set needs layout
            needsToLayout = true
            setNeedsLayout()
        }
    }
    open var minimumScaleFactor: CGFloat {
        get {
            context.minimumScaleFactor
        }
        set {
            // Check new value
            guard newValue != minimumScaleFactor else { return }
            context.minimumScaleFactor = newValue
            
            // Set needs layout
            needsToLayout = true
            setNeedsLayout()
        }
    }
    open var isFixedWidth: Bool {
        get {
            context.isFixedWidth
        }
        set {
            // Check new value
            guard newValue != isFixedWidth else { return }
            context.isFixedWidth = newValue
            
            // Set needs layout
            needsToLayout = true
            setNeedsLayout()
        }
    }
    open var hasSelectedAreaLineGap: Bool = true
    
    // Color
    open var textColor: UIColor {
        get {
            context.textColor
        }
        set {
            // Check new value
            guard newValue != textColor else { return }
            context.textColor = newValue
            
            // Set needs layout
            needsToLayout = true
            setNeedsLayout()
        }
    }
    open var borderColor: UIColor {
        get {
            context.borderColor
        }
        set {
            // Check new value
            guard newValue != borderColor else { return }
            context.borderColor = newValue
            
            // Set needs display. A border is stroked around what is laid out
            // already, so nothing has to be laid out again.
            setNeedsDisplay()
        }
    }
    open var borderWidth: CGFloat {
        get {
            context.borderWidth
        }
        set {
            // Check new value
            guard newValue != borderWidth else { return }
            context.borderWidth = newValue
            
            // Set needs display
            setNeedsDisplay()
        }
    }
    open var selectedTextColor: UIColor {
        get {
            context.selectedTextColor
        }
        set {
            // Check new value
            guard newValue != selectedTextColor else { return }
            context.selectedTextColor = newValue
            
            // Set needs layout
            needsToLayout = true
            setNeedsLayout()
        }
    }
    open var selectedAreaColor: UIColor {
        get {
            context.selectedAreaColor
        }
        set {
            // Check new value
            guard newValue != selectedAreaColor else { return }
            context.selectedAreaColor = newValue
            
            // Set needs layout
            needsToLayout = true
            setNeedsLayout()
        }
    }
    
    // Reveal. Nothing here is laid out again: the text is set once and whole,
    // and what comes out a character at a time is the drawing of it — which is
    // the whole point of counting characters rather than cutting the string,
    // the line breaks being settled before the first character shows
    open var revealAnimation: STRevealAnimation {
        get {
            context.revealAnimation
        }
        set {
            // Check new value
            guard newValue != revealAnimation else { return }
            context.revealAnimation = newValue
            
            // Set needs display
            setNeedsDisplay()
        }
    }
    open var revealedCharacterCount: Int {
        get {
            context.revealedCharacterCount
        }
        set {
            // Check new value
            guard newValue != revealedCharacterCount else { return }
            context.revealedCharacterCount = newValue
            
            // Follow the ones on their way, and draw what there is now
            updateRevealDisplayLink()
            setNeedsDisplay()
        }
    }
    open var revealDuration: TimeInterval {
        get {
            context.revealDuration
        }
        set {
            // Check new value
            guard newValue != revealDuration else { return }
            context.revealDuration = newValue
            
            // Set needs display
            setNeedsDisplay()
        }
    }
    open var revealOrigin: STRevealOrigin {
        get {
            context.revealOrigin
        }
        set {
            // Check new value
            guard newValue != revealOrigin else { return }
            context.revealOrigin = newValue
            
            // Set needs display
            setNeedsDisplay()
        }
    }
    
    /// How many characters there are to come out.
    ///
    /// Said once the text has been laid out, the readings being no characters
    /// of their own: it is the length of what somebody reads rather than of
    /// the string, which carries the readings in it
    open var revealCharacterCount: Int {
        // Lay the text out first, there being no runs to count before it
        layoutIfNeeded()
        context.prepareReveal()
        return context.revealCharacterCount
    }
    
    /// What draws the label again while a character is on its way.
    ///
    /// Held only while there is one. A text that is simply there is drawn when
    /// something asks for it, as any other view is, and a clock left running
    /// over it would wake the screen for nothing
    private var revealDisplayLink: CADisplayLink?
    
    // Features
    open var punctuationMode: STPunctuationMode {
        get {
            context.punctuationMode
        }
        set {
            // Check new value
            guard newValue != punctuationMode else { return }
            context.punctuationMode = newValue
            
            // Set needs layout
            needsToLayout = true
            setNeedsLayout()
        }
    }
    open var isKinsokuAvailable: Bool {
        get {
            context.isKinsokuAvailable
        }
        set {
            // Check new value
            guard newValue != isKinsokuAvailable else { return }
            context.isKinsokuAvailable = newValue
            
            // Set needs layout
            needsToLayout = true
            setNeedsLayout()
        }
    }
    open var isDividedByWords: Bool {
        get {
            context.isDividedByWords
        }
        set {
            // Check new value
            guard newValue != isDividedByWords else { return }
            context.isDividedByWords = newValue
            
            // Set needs layout
            needsToLayout = true
            setNeedsLayout()
        }
    }

    // Line count

    /// How many lines the text may be set on. Zero leaves it as many as it
    /// takes.
    ///
    /// The lines past the count are left undrawn and out of the size the text
    /// comes back as. A text held this way counts as truncated, so
    /// `adjustsFontSizeToFitWidth` sets it down until it fits the lines it is
    /// allowed, and only what still does not fit is lost
    open var maxLineCount: Int {
        get {
            context.maxLineCount
        }
        set {
            // Check new value
            guard newValue != maxLineCount else { return }
            context.maxLineCount = newValue
            
            // Set needs layout
            needsToLayout = true
            setNeedsLayout()
        }
    }

    /// Whether what is cut off is marked with an ellipsis.
    ///
    /// Off, the text simply stops where the room or the line count stops it.
    /// On, the last glyph still shown is set as the mark, so a reader can tell
    /// a text that goes on from one that ends there
    open var isShownEllipsis: Bool {
        get {
            context.isShownEllipsis
        }
        set {
            // Check new value
            guard newValue != isShownEllipsis else { return }
            context.isShownEllipsis = newValue
            
            // Set needs layout
            needsToLayout = true
            setNeedsLayout()
        }
    }

    // Ruby

    /// How a reading is written into the text, where one is written at all.
    ///
    /// Nothing by default — see `STRubyNotation`. The marks a reading is
    /// written with are then ordinary characters, and the text is set exactly
    /// as it is given
    open var rubyNotation: STRubyNotation {
        get {
            context.rubyNotation
        }
        set {
            // Check new value
            guard newValue != rubyNotation else { return }
            context.rubyNotation = newValue
            
            // Set needs layout
            needsToLayout = true
            setNeedsLayout()
        }
    }
    /// How large a reading is set, against the text it is read from
    open var rubyFontScale: CGFloat {
        get {
            context.rubyFontScale
        }
        set {
            // Check new value
            guard newValue != rubyFontScale else { return }
            context.rubyFontScale = newValue
            
            // Set needs layout
            needsToLayout = true
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

        // Draw again for colors of new appearance (layout is skipped if nothing changed)
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self]) { (label: STLabel, previousTraitCollection: UITraitCollection) in
            label.setNeedsDisplay()
        }
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
        
        // Set needs layout. Said as well as asking for the pass, which on its
        // own is not enough: the pass looks at whether anything has changed
        // before it does the work, and what it looks at is this flag and the
        // size. A face changed while the label stays the size it was would be
        // turned away there, and the text would go on being drawn in the
        // glyphs of the face it was parsed with
        needsToLayout = true
        setNeedsLayout()
    }
    
    /// How tall a line has to be for the faces this label is set in, against
    /// the size it is set at — see `STFontManager.minimumLineHeightScale`,
    /// which is what `lineHeightScale` has to be at the least for the letters
    /// to be drawn whole
    open var minimumLineHeightScale: CGFloat {
        return context.fontManager.minimumLineHeightScale
    }

    open func fontScale(script: STScript) -> CGFloat {
        // Pass to font manager
        return context.fontManager.fontScale(script: script)
    }
    
    open func setFontScale(_ fontScale: CGFloat, script: STScript) {
        // Pass to font manager
        context.fontManager.setFontScale(fontScale, script: script)
        
        // Set needs layout, for the reason setting the faces does
        needsToLayout = true
        setNeedsLayout()
    }
    
    //--------------------------------------------------------------//
    // MARK: - Layout
    //--------------------------------------------------------------//
    
    // Render size used for the last layout. context.renderSize is not compared instead,
    // because layout extends it (e.g. for hanging punctuation).
    private var laidOutRenderSize: CGSize?
    
    open func needsToLayout(size: CGSize) -> Bool {
        // Check flag
        guard !needsToLayout else { return true }
        
        // Check size
        guard let laidOutRenderSize else { return true }
        switch direction {
        case .lrTb:
            if laidOutRenderSize == size { return false }
            if size.height == 0 && laidOutRenderSize.width == size.width { return false }
        case .tbRl:
            if laidOutRenderSize == size { return false }
            if size.width == 0 && laidOutRenderSize.height == size.height { return false }
        }
        
        return true
    }
    
    /// Render size to layout with for bounds size
    open func renderSize(forBounds size: CGSize) -> CGSize {
        return size
    }
    
    open func adjustWithScale(_ scale: CGFloat) -> Bool {
        // Set adjust font scale
        context.adjustFontScale = scale
        
        // Parse and layout
        STParser(context: context).parse(text: text)
        STLayout(context: context).layout()
        
        // Check truncated
        return !context.isTruncated
    }
    
    open func adjust() {
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
    
    open func parseAndLayout() {
        // Check needs to layout
        let renderSize = renderSize(forBounds: bounds.size)
        guard needsToLayout(size: renderSize) else { return }
        
        // Set render size
        context.renderSize = renderSize
        laidOutRenderSize = renderSize
        needsToLayout = false
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
        context.rubyNotation = rubyNotation
        context.rubyFontScale = rubyFontScale
        context.maxLineCount = maxLineCount
        context.isShownEllipsis = isShownEllipsis
        
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
    
    // Inputs of draw buckets, to skip creating them again while scrolling
    private struct DrawBucketsKey: Equatable {
        let layoutVersion: Int
        let selectedRange: Range<Int>
        let size: CGSize
    }
    private var drawBucketsKey: DrawBucketsKey?
    
    open override func layoutSubviews() {
        // Invoke super
        super.layoutSubviews()
        
        // Parse and layout
        parseAndLayout()
        
        // Check layout, selection and size
        let key = DrawBucketsKey(
            layoutVersion: context.layoutVersion, 
            selectedRange: (textInput?.selectedTextRange as? STTextRange)?.range ?? 0 ..< 0, 
            size: bounds.size
        )
        guard key != drawBucketsKey else { return }
        drawBucketsKey = key
        
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
        // Decide render size in the same way as layout with bounds, not to layout again with different size
        let size = renderSize(forBounds: size)
        
        // Check needs to layout
        guard needsToLayout(size: size) else { return context.renderedSize }
        
        // Pares and layout
        context.renderSize = size
        laidOutRenderSize = size
        STParser(context: context).parse(text: text)
        STLayout(context: context).layout()
        
        // Clear flag
        needsToLayout = false
        
        // Get rendered size
        return context.renderedSize
    }
    
    //--------------------------------------------------------------//
    // MARK: - Reveal
    //--------------------------------------------------------------//
    
    /// Starts or stops the clock, by whether anything is on its way.
    ///
    /// Asked after every change that could set one going or let the last one
    /// land. What it draws is the whole label: the characters on their way are
    /// a handful among those already there, but which handful moves every
    /// frame, and finding them costs what drawing them does
    private func updateRevealDisplayLink() {
        // For something on its way
        guard context.isRevealing(at: CACurrentMediaTime()) else {
            // Stop the clock
            revealDisplayLink?.invalidate()
            revealDisplayLink = nil
            return
        }
        
        // Already running
        guard revealDisplayLink == nil else { return }
        
        // Start the clock
        let displayLink = CADisplayLink(
            target: self, selector: #selector(revealDisplayLinkFired)
        )
        displayLink.add(to: .main, forMode: .common)
        revealDisplayLink = displayLink
    }
    
    @objc private func revealDisplayLinkFired() {
        // Draw what there is now
        setNeedsDisplay()
        
        // And stop once the last one has landed
        updateRevealDisplayLink()
    }
    
    /// Keeps the clock to the time the label is on screen.
    ///
    /// A display link holds what it calls, so one left running holds the label
    /// after everything else has let go of it — and a label off the screen has
    /// nothing to show for the frames it is woken for. Started again where the
    /// label comes back with characters still on their way
    open override func didMoveToWindow() {
        // Invoke super
        super.didMoveToWindow()
        
        // For a label taken off the screen
        guard window != nil else {
            // Stop the clock
            revealDisplayLink?.invalidate()
            revealDisplayLink = nil
            return
        }
        
        // Follow whatever is still on its way
        updateRevealDisplayLink()
    }
    
    //--------------------------------------------------------------//
    // MARK: - Draw
    //--------------------------------------------------------------//
    
    struct DrawBucket {
        let fontId: Int

        /// How large the runs in this bucket are set, against the size the
        /// text as a whole is set at.
        ///
        /// Part of what tells one bucket from another. A bucket draws its
        /// glyphs with the one font it holds, and a font is made at a size, so
        /// runs set smaller than the text around them — a reading over a word
        /// — are drawn from a font of their own
        let fontScaleInt: Int

        let isClockwise: Bool
        let needsToFlip: Bool
        let isSelected: Bool
        let ctFont: CTFont
        var glyphs: [CGGlyph]
        var positions: [CGPoint]
        var frames: [CGRect]

        /// Which character of the text each glyph is drawn with.
        ///
        /// Kept beside the glyphs rather than looked up while drawing. A
        /// bucket holds whichever runs share a font, so what is next to a
        /// glyph here is not what is next to it in the text, and the run it
        /// came from is no longer in hand
        var characterIndexes: [Int]

        /// The place each glyph is coming to, which is what it is moved and
        /// sized against while it is on its way. The word's place rather than
        /// its own where the glyph is a reading
        var anchors: [CGRect]
    }
    
    var drawBuckets = [DrawBucket]()
    var drawRuns = [STRun]()
    
    private func runFrameWithLineGap(at index: Int) -> CGRect {
        // For line 0
        if drawRuns[index].line == 0 { return drawRuns[index].frame }
        
        // Swtich by direction
        let lineGapHeight = context.lineGapHeight
        
        var runFrame: CGRect = .zero
        switch direction {
        case .lrTb:
            runFrame.origin.x = drawRuns[index].frame.minX
            runFrame.origin.y = drawRuns[index].frame.minY - lineGapHeight
            runFrame.size.width = drawRuns[index].frame.width
            runFrame.size.height = drawRuns[index].frame.height + lineGapHeight
        case .tbRl:
            runFrame.origin.x = drawRuns[index].frame.minX
            runFrame.origin.y = drawRuns[index].frame.minY
            runFrame.size.width = drawRuns[index].frame.width + lineGapHeight
            runFrame.size.height = drawRuns[index].frame.height
        }
        
        return runFrame
    }
    
    private func uniteRunRects(range: STTextRange, hasLineGap: Bool) -> [CGRect] {
        // Unite run rects
        var unitedRect = CGRect.zero
        var rects = [CGRect]()
        var prevLine = -1
        for i in range.range {
            // Get run and rect
            guard i < drawRuns.count else { break }
            let run = drawRuns[i]
            let rect = hasLineGap ? runFrameWithLineGap(at: i) : run.frame
            
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
        let rects = uniteRunRects(range: range, hasLineGap: hasSelectedAreaLineGap)
        
        // Fill rects
        for rect in rects {
            cgContext.fill(rect)
        }
    }
    
    private func createDrawBcukets() {
        // Work out which character each run is drawn with, where the text has
        // been laid out again since it was last worked out
        context.prepareReveal()
        
        // Get selected text range
        let range = (textInput?.selectedTextRange as? STTextRange) ?? STTextRange(range: 0 ..< 0)
        
        // Create draw buckets
        var drawBuckets = [DrawBucket]()
        for (index, run) in context.runs.enumerated() {
            // Check visibility
            guard !run.isHidden else { continue }
            let isClockwise = context.isClockwise(run: run)
            let needsToFlip = context.fontManager.needsToFlip(fontId: run.fontId)
            let isSelected = range.range.contains(index)
            
            // Find bucket
            let bucketIndex: Int
            let fontScaleInt = Int(run.fontScale * 1000)
            if let index = drawBuckets.firstIndex(where: {
                $0.fontId == run.fontId && 
                $0.fontScaleInt == fontScaleInt &&
                $0.isClockwise == isClockwise && 
                $0.needsToFlip == needsToFlip &&
                $0.isSelected == isSelected
            }) {
                bucketIndex = index
            }
            else {
                // Get CT font
                let ctFont = context.fontManager.ctFont(
                    fontId: run.fontId, 
                    size: context.adjustFontSize * run.fontScale, 
                    isClockwise: isClockwise
                )
                
                // Add bucket
                let drawBucket = DrawBucket(
                    fontId: run.fontId, 
                    fontScaleInt: fontScaleInt,
                    isClockwise: isClockwise, 
                    needsToFlip: needsToFlip, 
                    isSelected: isSelected, 
                    ctFont: ctFont, 
                    glyphs: [], 
                    positions: [], 
                    frames: [],
                    characterIndexes: [],
                    anchors: []
                )
                drawBuckets.append(drawBucket)
                bucketIndex = drawBuckets.count - 1
            }
            
            // Which character this run is drawn with, and the place it is
            // coming to
            let characterIndex = index < context.revealIndexes.count
                ? context.revealIndexes[index] : 0
            let anchor = index < context.revealAnchors.count
                ? context.revealAnchors[index] : run.frame
            
            // For ellipsis
            if run.visibility == .ellipsis {
                // Add ellipsis
                drawBuckets[bucketIndex].glyphs.append(context.fontManager.ellipsisGlyph(fontId: run.fontId, direction: context.direction))
                drawBuckets[bucketIndex].positions.append(run.position)
                drawBuckets[bucketIndex].frames.append(run.frame)
                drawBuckets[bucketIndex].characterIndexes.append(characterIndex)
                drawBuckets[bucketIndex].anchors.append(anchor)
            }
            // For visible
            else if run.visibility == .visible {
                // Add glyph and position
                drawBuckets[bucketIndex].glyphs.append(run.glyph)
                drawBuckets[bucketIndex].positions.append(run.position)
                drawBuckets[bucketIndex].frames.append(run.frame)
                drawBuckets[bucketIndex].characterIndexes.append(characterIndex)
                drawBuckets[bucketIndex].anchors.append(anchor)
            }
        }
        
        // Set draw buckets
        self.drawBuckets = drawBuckets
        
        // Set current runs for drawing
        drawRuns = context.runs
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
    
    /// Draws one bucket's glyphs, those of them that have come out.
    ///
    /// Each is asked how far into coming out it has got. Nothing where it has
    /// not been reached, the whole of it where it is simply there — which is
    /// every glyph of a text that was never told to come out a character at a
    /// time — and part of the way where it is on its way.
    ///
    /// The ones that are simply there are drawn in the one go, as they always
    /// were. Only those still on their way are drawn on their own, there being
    /// a handful of them at a time and no other way to give each its own
    /// colour
    private func drawGlyphs(bucket: DrawBucket, drawRect: CGRect, cgContext: CGContext, time: TimeInterval) {
        // For a font drawn from color bitmaps, each glyph is turned back over
        // on its own
        if bucket.needsToFlip {
            for i in 0 ..< bucket.glyphs.count {
                guard bucket.frames[i].intersects(drawRect) else { continue }
                
                // How far into coming out this one has got, and what that
                // makes of it
                let progress = context.revealProgress(
                    ofCharacter: bucket.characterIndexes[i], at: time
                )
                guard progress > 0 else { continue }
                let drawing = context.revealAnimation.drawing(
                    progress: progress,
                    anchor: bucket.anchors[i],
                    origin: context.revealOrigin
                )
                
                var transform: CGAffineTransform = .identity
                transform = transform.translatedBy(x: 0, y: bucket.positions[i].y * 2)
                transform = transform.scaledBy(x: 1, y: -1)
                cgContext.saveGState()
                if drawing.alpha < 1 {
                    cgContext.setAlpha(drawing.alpha)
                }
                // Where it is coming to is said first and turned over second,
                // the turning over belonging to the glyph and the moving to
                // the page it is being put on
                cgContext.concatenate(drawing.transform)
                cgContext.concatenate(transform)
                CTFontDrawGlyphs(bucket.ctFont, [bucket.glyphs[i]], [bucket.positions[i]], 1, cgContext)
                cgContext.restoreGState()
            }
        }
        else {
            // Draw only glyphs in rect
            var glyphs = [CGGlyph]()
            var positions = [CGPoint]()
            for i in 0 ..< bucket.glyphs.count where bucket.frames[i].intersects(drawRect) {
                // How far into coming out this one has got
                let progress = context.revealProgress(
                    ofCharacter: bucket.characterIndexes[i], at: time
                )
                
                // Not reached yet
                guard progress > 0 else { continue }
                
                // On its way, and so drawn on its own: it is given a colour
                // and a place of its own, which is the one thing a glyph drawn
                // among others cannot have
                guard progress >= 1 else {
                    let drawing = context.revealAnimation.drawing(
                        progress: progress,
                        anchor: bucket.anchors[i],
                        origin: context.revealOrigin
                    )
                    cgContext.saveGState()
                    cgContext.setAlpha(drawing.alpha)
                    cgContext.concatenate(drawing.transform)
                    CTFontDrawGlyphs(bucket.ctFont, [bucket.glyphs[i]], [bucket.positions[i]], 1, cgContext)
                    cgContext.restoreGState()
                    continue
                }
                
                glyphs.append(bucket.glyphs[i])
                positions.append(bucket.positions[i])
            }
            CTFontDrawGlyphs(bucket.ctFont, glyphs, positions, glyphs.count, cgContext)
        }
    }
    
    private func drawGlyphBorders(drawRect: CGRect, cgContext: CGContext, time: TimeInterval) {
        // Check border
        guard context.borderWidth > 0, context.borderColor.cgColor.alpha > 0 else { return }
        
        // Set border. A stroke sits on the outline, half of it either side, so
        // it is drawn at twice the width and the fill covers the inner half.
        cgContext.saveGState()
        cgContext.setTextDrawingMode(.stroke)
        cgContext.setLineWidth(context.borderWidth * 2)
        cgContext.setLineJoin(.round)
        cgContext.setLineCap(.round)
        cgContext.setStrokeColor(context.borderColor.cgColor)
        
        // Draw every border before any of the fills, so a border never lands
        // over the glyph beside its own
        for bucket in drawBuckets {
            // A glyph drawn from a color bitmap has no outline to stroke
            guard !bucket.needsToFlip else { continue }
            
            // Draw glyphs
            drawGlyphs(bucket: bucket, drawRect: drawRect, cgContext: cgContext, time: time)
        }
        
        cgContext.restoreGState()
    }
    
    private func drawGlyphs(_ dirtyRect: CGRect) {
        // Get CG context
        guard let cgContext = UIGraphicsGetCurrentContext() else { return }
        
        // Decide rect to draw, with margin for glyphs drawn outside of run
        // frame. A border is stroked outside the glyph, so it widens that
        // margin by as much as it reaches
        let margin = context.fontSize + context.borderWidth
        let drawRect = dirtyRect.insetBy(dx: -margin, dy: -margin)
        
        // The moment this is being drawn at, read once. Asked of each glyph in
        // turn it would move down the text, and the characters on their way
        // would be at different points of the same step
        let time = CACurrentMediaTime()
        
        // Draw borders, all of them before any fill
        drawGlyphBorders(drawRect: drawRect, cgContext: cgContext, time: time)
        
        // Draw buckets
        for bucket in drawBuckets {
            // Set text color
            cgContext.setFillColor(bucket.isSelected ? context.selectedTextColor.cgColor : context.textColor.cgColor)
            
            // Draw glyphs
            drawGlyphs(bucket: bucket, drawRect: drawRect, cgContext: cgContext, time: time)
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
#endif
