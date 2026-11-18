/*
STLabel.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center. All rights reserved.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(macOS)
import Cocoa

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

    open var hasSelectedAreaLineGap: Bool = true

    // Context
    public let context = STContext()

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
        let isClockwise: Bool
        let needsToFlip: Bool
        let isSelected: Bool
        let ctFont: CTFont
        var glyphs: [CGGlyph]
        var positions: [CGPoint]
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
            if let index = drawBuckets.firstIndex(where: {
                $0.fontId == run.fontId && 
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
                    size: context.adjustFontSize, 
                    isClockwise: isClockwise
                )
                
                // Add bucket
                let drawBucket = DrawBucket(
                    fontId: run.fontId, 
                    isClockwise: isClockwise, 
                    needsToFlip: needsToFlip, 
                    isSelected: isSelected, 
                    ctFont: ctFont,
                    glyphs: [],
                    positions: []
                )
                drawBuckets.append(drawBucket)
                bucketIndex = drawBuckets.count - 1
            }
            
            // For ellipsis
            if run.visibility == .ellipsis {
                // Add ellipsis
                drawBuckets[bucketIndex].glyphs.append(context.fontManager.ellipsisGlyph(fontId: run.fontId, direction: context.direction))
                drawBuckets[bucketIndex].positions.append(run.position)
            }
            // For visible
            else if run.visibility == .visible {
                // Add glyph and position
                drawBuckets[bucketIndex].glyphs.append(run.glyph)
                drawBuckets[bucketIndex].positions.append(run.position)
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
    
    private func drawGlyphs(_ dirtyRect: CGRect, runRange: Range<Int>) {
        // Get CG context
        guard let cgContext = NSGraphicsContext.current?.cgContext else { return }

        // Create draw buckets for the visible runs
        let drawBuckets = createDrawBuckets(runRange: runRange)

        // Draw buckets
        for bucket in drawBuckets {
            // Set text color
            cgContext.setFillColor(bucket.isSelected ? context.selectedTextColor.cgColor : context.textColor.cgColor)
            
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
