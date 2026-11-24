/*
STLabel.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(macOS)
import Cocoa
import QuartzCore

open class STLabel: NSView {
    // Text input
    open weak var textInput: NSTextInputClient?

    // Text
    open var text: String? {
        didSet {
            // Check with old value
            guard oldValue != text else { return }
            
            // Set needs layout
            setNeedsParseAndLayout()
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
            setNeedsParseAndLayout()
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
            setNeedsParseAndLayout()
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
            setNeedsParseAndLayout()
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
            setNeedsParseAndLayout()
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
            setNeedsParseAndLayout()
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
            setNeedsParseAndLayout()
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
            setNeedsParseAndLayout()
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
            setNeedsParseAndLayout()
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
            setNeedsParseAndLayout()
        }
    }
    
    open var isSingleLine: Bool {
        get {
            context.isSingleLine
        }
        set {
            // Check new value
            guard newValue != isSingleLine else { return }
            context.isSingleLine = newValue

            // Set needs layout
            setNeedsParseAndLayout()
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
            setNeedsParseAndLayout()
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
            setNeedsParseAndLayout()
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
            setNeedsParseAndLayout()
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
            setNeedsParseAndLayout()
        }
    }

    open var hasSelectedAreaLineGap: Bool = true

    open var punctuationMode: STPunctuationMode {
        get {
            context.punctuationMode
        }
        set {
            // Check new value
            guard newValue != punctuationMode else { return }
            context.punctuationMode = newValue

            // Set needs layout
            setNeedsParseAndLayout()
        }
    }

    // Color
    open var textColor: NSColor {
        get {
            context.textColor
        }
        set {
            // Check new value
            guard newValue != textColor else { return }
            context.textColor = newValue

            // Set needs display. A color is what the glyphs are filled with,
            // not where they fall, so nothing has to be laid out again
            needsDisplay = true
        }
    }

    open var selectedTextColor: NSColor {
        get {
            context.selectedTextColor
        }
        set {
            // Check new value
            guard newValue != selectedTextColor else { return }
            context.selectedTextColor = newValue

            // Set needs display
            needsDisplay = true
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
            needsDisplay = true
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
            needsDisplay = true
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
            needsDisplay = true
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
            needsDisplay = true
        }
    }

    /// How many characters there are to come out.
    ///
    /// Said once the text has been laid out, the readings being no characters
    /// of their own: it is the length of what somebody reads rather than of
    /// the string, which carries the readings in it
    open var revealCharacterCount: Int {
        // Lay the text out first, there being no runs to count before it
        layoutSubtreeIfNeeded()
        context.prepareReveal()
        return context.revealCharacterCount
    }

    /// What draws the label again while a character is on its way.
    ///
    /// Held only while there is one. A text that is simply there is drawn when
    /// something asks for it, as any other view is, and a clock left running
    /// over it would wake the screen for nothing
    private var revealDisplayLink: CADisplayLink?

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

        // Already running, and nothing to run it on before the view is in a
        // window
        guard revealDisplayLink == nil, window != nil else { return }

        // Start the clock
        let displayLink = displayLink(
            target: self, selector: #selector(revealDisplayLinkFired)
        )
        displayLink.add(to: .main, forMode: .common)
        revealDisplayLink = displayLink
    }

    @objc private func revealDisplayLinkFired() {
        // Draw what there is now
        needsDisplay = true

        // And stop once the last one has landed
        updateRevealDisplayLink()
    }

    /// Keeps the clock to the time the label is on screen.
    ///
    /// A display link holds what it calls, so one left running holds the label
    /// after everything else has let go of it — and a label off the screen has
    /// nothing to show for the frames it is woken for. It is also asked of the
    /// view's own display, which a view in no window has not got, so this is
    /// where one can first be made at all
    open override func viewDidMoveToWindow() {
        // Invoke super
        super.viewDidMoveToWindow()

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

    open var borderColor: NSColor {
        get {
            context.borderColor
        }
        set {
            // Check new value
            guard newValue != borderColor else { return }
            context.borderColor = newValue

            // Set needs display. A border is stroked around what is laid out
            // already, so nothing has to be laid out again.
            needsDisplay = true
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
            needsDisplay = true
        }
    }

    // Context
    public let context = STContext()

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
        setNeedsParseAndLayout()
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

        // Set needs layout
        setNeedsParseAndLayout()
    }

    //--------------------------------------------------------------//
    // MARK: - Layout
    //--------------------------------------------------------------//

    // Glyphs and metrics depend on the text and the font, never on the render
    // size, so a resize only has to run the layout again.
    private var isParseDirty = true
    private var isLayoutDirty = true

    // The font configuration the current runs were parsed with.
    // A font family change does not go through our own setters, so the parse
    // has to be invalidated from what the font manager reports.
    private var parsedFontConfigurationVersion = -1

    open func setNeedsParseAndLayout() {
        // Invalidate the current parse and layout
        isParseDirty = true
        isLayoutDirty = true

        // Set needs layout
        needsLayout = true
    }

    open func needsToLayout(size: CGSize) -> Bool {
        // Compare the axis that constrains line breaking. The cross axis matters
        // only where the layout actually reads it, so ignoring it elsewhere lets a
        // measuring pass and the real pass share one layout.
        switch direction {
        case .lrTb:
            if context.renderSize.width != size.width { return true }
            // Only a middle/end aligned block is positioned from the height
            if directionAlign != .start && context.renderSize.height != size.height { return true }
        case .tbRl:
            if context.renderSize.height != size.height { return true }
            // Vertical text is laid out from the right edge, so the width is read
            // for every alignment
            if context.renderSize.width != size.width { return true }
        }

        return false
    }

    private func performParseAndLayout(renderSize: CGSize) {
        // Set render size
        context.renderSize = renderSize
        context.adjustFontScale = 1.0

        // Refresh font manager
        context.fontManager.refresh()

        // Glyphs and advances were resolved against the fonts in use at parse
        // time, so a changed font configuration invalidates them. Laying out
        // again without parsing would keep the previous font's advances and set
        // the text too tight or too loose — visible in Latin text, where the
        // advances differ between families, and invisible in full-width
        // Japanese, where every family advances by one em.
        if parsedFontConfigurationVersion != context.fontManager.configurationVersion {
            isParseDirty = true
        }

        // Parse only when the text or the font changed; a resize reuses the runs
        if isParseDirty {
            STParser(context: context).parse(text: text)
            parsedFontConfigurationVersion = context.fontManager.configurationVersion
            isParseDirty = false
        }

        // Layout
        STLayout(context: context).layout()

        // Clear dirty flag
        isLayoutDirty = false
    }

    // Whether the fonts changed since the current runs were parsed.
    // The font family is changed through the font manager, not through our own
    // setters, so nothing marks the parse dirty on its own.
    private var isFontConfigurationStale: Bool {
        return parsedFontConfigurationVersion != context.fontManager.configurationVersion
    }

    open func parseAndLayout() {
        // Check needs to layout
        guard isParseDirty || isLayoutDirty || isFontConfigurationStale
            || needsToLayout(size: bounds.size) else { return }

        // Parse and layout
        performParseAndLayout(renderSize: bounds.size)
    }

    private func matchesOwnConstrainingSize(_ size: CGSize) -> Bool {
        // Check the axis that constrains line breaking against our own bounds
        switch direction {
        case .lrTb: return size.width == bounds.width
        case .tbRl: return size.height == bounds.height
        }
    }

    open func sizeThatFits(_ size: CGSize) -> CGSize {
        // When the requested size constrains the text the same way our own bounds
        // do, lay out our own context so the work is shared with parseAndLayout()
        // instead of being thrown away
        if matchesOwnConstrainingSize(size) {
            if isParseDirty || isLayoutDirty || needsToLayout(size: bounds.size) {
                performParseAndLayout(renderSize: bounds.size)
            }

            return context.renderedSize
        }

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
        context.isSingleLine = isSingleLine
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
    
    open override func layout() {
        // Invoke super
        super.layout()

        // Parse and layout
        parseAndLayout()

        // Set needs to display
        needsDisplay = true
    }
    
    //--------------------------------------------------------------//
    // MARK: - Draw
    //--------------------------------------------------------------//
    
    open override var isFlipped: Bool {
        true
    }
    
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

    private func runFrameWithLineGap(at index: Int) -> CGRect {
        // For line 0
        if context.runs[index].line == 0 { return context.runs[index].frame }

        // Swtich by direction
        let lineGapHeight = context.lineGapHeight

        var runFrame: CGRect = .zero
        switch direction {
        case .lrTb:
            runFrame.origin.x = context.runs[index].frame.minX
            runFrame.origin.y = context.runs[index].frame.minY - lineGapHeight
            runFrame.size.width = context.runs[index].frame.width
            runFrame.size.height = context.runs[index].frame.height + lineGapHeight
        case .tbRl:
            runFrame.origin.x = context.runs[index].frame.minX
            runFrame.origin.y = context.runs[index].frame.minY
            runFrame.size.width = context.runs[index].frame.width + lineGapHeight
            runFrame.size.height = context.runs[index].frame.height
        }

        return runFrame
    }

    private func uniteRunRects(range: Range<Int>, hasLineGap: Bool, extendsNewlineToLineEnd: Bool = false) -> [CGRect] {
        // Unite run rects
        var unitedRect = CGRect.zero
        var rects = [CGRect]()
        var prevLine = -1
        for i in range {
            // Get run and rect
            guard i < context.runs.count else { break }
            let run = context.runs[i]
            var rect = hasLineGap ? runFrameWithLineGap(at: i) : run.frame

            // A newline carries no width of its own, so on its own it would leave
            // the rest of the line unpainted. Fill out to the end of the line.
            if extendsNewlineToLineEnd && run.isNewline {
                switch direction {
                case .lrTb: rect.size.width = max(0, context.renderSize.width - rect.minX)
                case .tbRl: rect.size.height = max(0, context.renderSize.height - rect.minY)
                }
            }

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
    
    private func drawSelectedArea(_ dirtyRect: CGRect, runRange: Range<Int>) {
        // Get selected text range
        guard let range = (textInput as? STTextView)?.selectedSTTextRange else { return }

        // Clip to the visible runs, so selecting the whole document does not make
        // every draw walk it end to end
        let clipped = range.range.clamped(to: runRange)
        guard !clipped.isEmpty else { return }

        // Get CG context
        guard let cgContext = NSGraphicsContext.current?.cgContext else { return }

        // Set selected area color
        cgContext.setFillColor(context.selectedAreaColor.cgColor)

        // Unite selected run rects
        let rects = uniteRunRects(range: clipped, hasLineGap: hasSelectedAreaLineGap, extendsNewlineToLineEnd: true)

        // Fill rects
        for rect in rects {
            cgContext.fill(rect)
        }
    }

    // Returns the runs that can intersect the given rect. Runs are laid out in
    // line order, so their position along the block axis is monotonic and can be
    // binary searched instead of scanning the document from the start.
    private func visibleRunRange(in rect: CGRect) -> Range<Int> {
        // Check runs
        let count = context.runs.count
        guard count > 0 else { return 0 ..< 0 }

        // Pad by a line, so glyphs overhanging their line box are not clipped away
        let lineHeight = context.lineHeight
        let searchRect = rect.insetBy(dx: -lineHeight, dy: -lineHeight)

        // Find the first run that can intersect
        var low = 0
        var high = count
        while low < high {
            let mid = (low + high) / 2
            let reached: Bool
            switch direction {
            case .lrTb: reached = context.runs[mid].frame.maxY >= searchRect.minY
            case .tbRl: reached = context.runs[mid].frame.minX <= searchRect.maxX
            }
            if reached { high = mid }
            else { low = mid + 1 }
        }
        guard low < count else { return count ..< count }

        // Back up to the start of the line, since one line's runs share a block
        // position but may differ in size
        var lower = low
        let line = context.runs[low].line
        while lower > 0 && context.runs[lower - 1].line >= line { lower -= 1 }

        // Walk forward over the runs that still intersect
        var upper = lower
        while upper < count {
            let intersects: Bool
            switch direction {
            case .lrTb: intersects = context.runs[upper].frame.minY <= searchRect.maxY
            case .tbRl: intersects = context.runs[upper].frame.maxX >= searchRect.minX
            }
            if !intersects { break }
            upper += 1
        }

        return lower ..< upper
    }

    private func createDrawBuckets(runRange: Range<Int>) -> [DrawBucket] {
        // Work out which character each run is drawn with, where the text has
        // been laid out again since it was last worked out
        context.prepareReveal()

        // Get selected text range
        let range = (textInput as? STTextView)?.selectedSTTextRange ?? STTextRange(range: 0 ..< 0)

        // Create draw buckets
        var drawBuckets = [DrawBucket]()
        for index in runRange {
            // Check visibility
            let run = context.runs[index]
            guard !run.isHidden else { continue }
            let isClockwise = context.isClockwise(run: run)
            let needsToFlip = context.fontManager.needsToFlip(fontId: run.fontId, glyph: run.glyph)
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
                drawBuckets[bucketIndex].characterIndexes.append(characterIndex)
                drawBuckets[bucketIndex].anchors.append(anchor)
            }
            // For visible
            else if run.visibility == .visible {
                // Add glyph and position
                drawBuckets[bucketIndex].glyphs.append(run.glyph)
                drawBuckets[bucketIndex].positions.append(run.position)
                drawBuckets[bucketIndex].characterIndexes.append(characterIndex)
                drawBuckets[bucketIndex].anchors.append(anchor)
            }
        }

        return drawBuckets
    }

    private func drawMarkedArea(_ dirtyRect: CGRect, runRange: Range<Int>) {
        // Get CG context
        guard let cgContext = NSGraphicsContext.current?.cgContext else { return }

        // Get marked ranges
        guard let markedRanges = (textInput as? STTextView)?.markedRanges else { return }
        for markedRange in markedRanges {
            // Clip to the visible runs
            let clipped = markedRange.0.clamped(to: runRange)
            guard !clipped.isEmpty else { continue }

            // Set fill color
            let color = markedRange.1 ? context.markedTextColor : context.markedTextColor.withAlphaComponent(0.5)
            cgContext.setFillColor(color.cgColor)

            // Unite marked run rects
            let rects = uniteRunRects(range: clipped, hasLineGap: false)

            // Fill rects
            for rect in rects {
                let lineRect: CGRect
                switch direction {
                case .lrTb: lineRect = CGRect(x: rect.minX + 1, y: rect.maxY, width: rect.width - 2, height: 2)
                case .tbRl: lineRect = CGRect(x: rect.minX, y: rect.minY + 1, width: 2, height: rect.height - 2)
                }
                cgContext.fill(lineRect)
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
    private func drawGlyphs(bucket: DrawBucket, cgContext: CGContext, time: TimeInterval) {
        // For a font drawn from color bitmaps, each glyph is turned back over
        // on its own
        if bucket.needsToFlip {
            for i in 0 ..< bucket.glyphs.count {
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
            // The ones that are simply there, drawn in the one go
            var glyphs = [CGGlyph]()
            var positions = [CGPoint]()
            for i in 0 ..< bucket.glyphs.count {
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

    private func drawGlyphBorders(drawBuckets: [DrawBucket], cgContext: CGContext, time: TimeInterval) {
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
            drawGlyphs(bucket: bucket, cgContext: cgContext, time: time)
        }

        cgContext.restoreGState()
    }

    private func drawGlyphs(_ dirtyRect: CGRect, runRange: Range<Int>) {
        // Get CG context
        guard let cgContext = NSGraphicsContext.current?.cgContext else { return }

        // Create draw buckets for the visible runs
        let drawBuckets = createDrawBuckets(runRange: runRange)

        // The moment this is being drawn at, read once. Asked of each glyph in
        // turn it would move down the text, and the characters on their way
        // would be at different points of the same step
        let time = CACurrentMediaTime()

        // Draw borders, all of them before any fill
        drawGlyphBorders(drawBuckets: drawBuckets, cgContext: cgContext, time: time)

        // Draw buckets
        for bucket in drawBuckets {
            // Set text color
            cgContext.setFillColor(bucket.isSelected ? context.selectedTextColor.cgColor : context.textColor.cgColor)
            
            // Draw glyphs
            drawGlyphs(bucket: bucket, cgContext: cgContext, time: time)
        }
    }
    
    private func drawFrames(_ dirtyRect: CGRect) {
    }
    
    
    open override func draw(_ dirtyRect: NSRect) {
        // Decide the runs to draw
        let runRange = visibleRunRange(in: dirtyRect)

        // Draw
        drawSelectedArea(dirtyRect, runRange: runRange)
        drawMarkedArea(dirtyRect, runRange: runRange)
        drawGlyphs(dirtyRect, runRange: runRange)

        // For test
        //drawFrames(dirtyRect)
    }
}
#endif
