/*
STLayout.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(iOS)
import UIKit
#elseif os(macOS)
import Cocoa
#endif

public class STLayout {
    public static let willLayout = Notification.Name("STLayoutWillLayout")
    public static let didLayout = Notification.Name("STLayoutDidLayout")
    
    // Context
    public let context: STContext
    
    // Current position
    private var runId: Int = 0
    private var lineStartRunId: Int = 0
    
    // Geometry
    private var x: CGFloat = 0
    private var y: CGFloat = 0
    private var minX: CGFloat { 0 }
    private var minY: CGFloat { 0 }
    // For single line, never break by width/height so the text stays on one line
    private var maxX: CGFloat { context.isSingleLine ? .greatestFiniteMagnitude : context.renderSize.width }
    private var maxY: CGFloat { context.isSingleLine ? .greatestFiniteMagnitude : context.renderSize.height }
    private var tmpX: CGFloat?

    // How far a punctuation mark hung at the end of a line reaches past it, for
    // the fixed width layout. Zero when nothing hangs
    private var hangingOverhang: CGFloat = 0

    // The ascent the line's em box is measured from, for this layout pass
    private var emAscent: CGFloat = 0

    /// How many of the lines laid out are drawn — all of them, unless the
    /// text is held to a count
    private var shownLineCount: Int {
        // Decide shown line count
        guard context.maxLineCount > 0 else { return context.lineCount }
        return min(context.lineCount, context.maxLineCount)
    }
    
    //--------------------------------------------------------------//
    // MARK: - Initialize
    //--------------------------------------------------------------//
    
    public init(context: STContext) {
        self.context = context
    }
    
    //--------------------------------------------------------------//
    // MARK: - Run
    //--------------------------------------------------------------//
    
    private func layoutRunLrTb() {
        // Get local reference to current run
        var currentRun = context.runs[runId]
        
        // Set line
        currentRun.line = context.lineCount
        
        // For new line
        if currentRun.isNewline {
            // Layout run with 0 width
            currentRun.position = .init(x: x, y: y)
            currentRun.frame = .init(
                x: x, 
                y: y - context.fontManager.ascent(fontId: currentRun.fontId, size: context.adjustFontSize), 
                width: 0, 
                height: context.fontSize)
        }
        // For other
        else {
            // Cache frequently accessed values
            let advanceWidth = currentRun.advance.width
            let punctuation = currentRun.punctuation
            
            // Decide position x and frame width
            var posX: CGFloat = x
            var width: CGFloat = advanceWidth
            if context.isFixedWidth {
                posX += (context.fontSize - width) * 0.5
                width = context.fontSize
            }
            else {
                switch context.punctuationMode {
                case .whole:
                    // Do nothing
                    break
                case .half:
                    // Set position x and frame
                    switch punctuation {
                    case .whole:
                        break
                    case .firstHalf:
                        width = advanceWidth * 0.5
                    case .secondHalf:
                        posX = x - advanceWidth * 0.5
                        width = advanceWidth * 0.5
                    case .quarter:
                        posX = x - advanceWidth * 0.25
                        width = advanceWidth * 0.5
                    }
                case .stone:
                    // Check with prev run.
                    //
                    // Only within the line. The run before the first one of a line
                    // sits on the line above, where it is no neighbour: squeezing
                    // against it here and then again in goNextLine(), which has its
                    // own rule for an opening bracket at the start of a line, pulls
                    // the line half an em too far left. It then ends short of the
                    // measure, and the bracket is drawn half outside the block.
                    if runId > lineStartRunId {
                        let prevPunctuation = context.runs[runId - 1].punctuation
                        // For first half and second half, like '」「'
                        if prevPunctuation == .firstHalf && punctuation == .secondHalf {
                            posX = x - advanceWidth * 0.5
                            width = advanceWidth * 0.5
                        }
                        // For second half and second half, like '「「'
                        else if prevPunctuation == .secondHalf && punctuation == .secondHalf {
                            posX = x - advanceWidth * 0.5
                            width = advanceWidth * 0.5
                        }
                        // For quater and second half, like '・「'
                        else if prevPunctuation == .quarter && punctuation == .secondHalf {
                            posX = x - advanceWidth * 0.5
                            width = advanceWidth * 0.5
                        }
                    }
                    
                    // Check with next run
                    if runId + 1 < context.runs.count {
                        let nextPunctuation = context.runs[runId + 1].punctuation
                        // For first half and first half, like '。」'
                        if punctuation == .firstHalf && nextPunctuation == .firstHalf {
                            width = advanceWidth * 0.5
                        }
                        // For first half and quarter, like '」・'
                        else if punctuation == .firstHalf && nextPunctuation == .quarter {
                            width = advanceWidth * 0.5
                        }
                    }
                }
            }
            
            // Layout run
            if context.fontManager.needsToFlip(fontId: currentRun.fontId, glyph: currentRun.glyph) {
                // An emoji is drawn from its own font at its own scale, so neither
                // its advance nor its bounding box matches the text around it, and
                // its ascent reaches far above the baseline - AppleColorEmoji sets
                // it at about 1.25 em. Measuring its frame from that ascent puts
                // the frame where the glyph is not: the ink lands lower and taller
                // than the frame says, the line's runs no longer share a box, and
                // the box the line occupies spills into the next one.
                //
                // Give it the line's em box instead, and centre its ink in it, the
                // way the vertical layout already does. The flipped draw path puts
                // the ink at
                // [position.y - boundingRect.maxY - boundingRect.height,
                //  position.y - boundingRect.maxY], hence the y below.
                let boundingRect = currentRun.boundingRect
                let emTop = y - emAscent
                let inkTop = emTop + (context.adjustFontSize - boundingRect.height) * 0.5
                currentRun.position = .init(
                    x: posX,
                    y: inkTop + boundingRect.height + boundingRect.maxY)
                currentRun.frame = .init(
                    x: x,
                    y: emTop,
                    width: width,
                    height: context.adjustFontSize)
            }
            else {
                currentRun.position = .init(x: posX, y: y)
                currentRun.frame = .init(
                    x: x, 
                    y: y - context.fontManager.ascent(fontId: currentRun.fontId, size: context.adjustFontSize), 
                    width: width, 
                    height: context.adjustFontSize * context.fontManager.fontScale(fontId: currentRun.fontId))
            }
        }
        
        // Update the run in the array
        context.runs[runId] = currentRun
    }
    
    private func layoutRunTbRl() {
        // Get local reference to current run
        var currentRun = context.runs[runId]
        
        // Set line
        currentRun.line = context.lineCount
        
        // For new line
        if currentRun.isNewline {
            // Layout run with 0 height
            currentRun.position = .init(
                x: x, 
                y: y + context.adjustFontSize - context.fontManager.descent(fontId: currentRun.fontId, size: context.adjustFontSize))
            currentRun.frame = .init(
                x: x, 
                y: y, 
                width: context.fontSize, 
                height: 0)
        }
        // For clockwise
        else if context.isClockwise(run: currentRun) {
            // Cache frequently accessed values
            let advanceWidth = currentRun.advance.width
            
            // Layout run in clockwise
            var posY = y
            var height = advanceWidth
            if context.isFixedWidth {
                posY += (context.fontSize - advanceWidth) * 0.5
                height = context.fontSize
            }
            
            currentRun.position = .init(
                x: x + context.fontManager.descent(fontId: currentRun.fontId, size: context.adjustFontSize), 
                y: posY)
            currentRun.frame = .init(
                x: x, 
                y: y, 
                width: context.adjustFontSize, 
                height: height)
        }
        // For not clockwise
        else {
            // Cache frequently accessed values
            let punctuation = currentRun.punctuation
            let fontId = currentRun.fontId
            let adjustFontSize = context.adjustFontSize
            
            // Decide position y and frame height
            var posY = y + adjustFontSize - context.fontManager.descent(fontId: fontId, size: adjustFontSize)
            var height = adjustFontSize
            switch context.punctuationMode {
            case .whole:
                // Do nothing
                break
            case .half:
                // Set position y and frame
                switch punctuation {
                case .whole:
                    break
                case .firstHalf:
                    height = adjustFontSize * 0.5
                case .secondHalf:
                    posY -= adjustFontSize * 0.5
                    height = adjustFontSize * 0.5
                case .quarter:
                    posY -= adjustFontSize * 0.25
                    height = adjustFontSize * 0.5
                }
            case .stone:
                // Check with prev run. Only within the line - see layoutRunLrTb.
                if runId > lineStartRunId {
                    let prevPunctuation = context.runs[runId - 1].punctuation
                    // For first half and second half, like '」「'
                    if prevPunctuation == .firstHalf && punctuation == .secondHalf {
                        posY -= adjustFontSize * 0.5
                        height = adjustFontSize * 0.5
                    }
                    // For second half and second half, like '「「'
                    else if prevPunctuation == .secondHalf && punctuation == .secondHalf {
                        posY -= adjustFontSize * 0.5
                        height = adjustFontSize * 0.5
                    }
                    // For quater and second half, like '・「'
                    else if prevPunctuation == .quarter && punctuation == .secondHalf {
                        posY -= adjustFontSize * 0.5
                        height = adjustFontSize * 0.5
                    }
                }
                
                // Check with next run
                if runId + 1 < context.runs.count {
                    let nextPunctuation = context.runs[runId + 1].punctuation
                    // For first half and first half, like '。」'
                    if punctuation == .firstHalf && nextPunctuation == .firstHalf {
                        height = adjustFontSize * 0.5
                    }
                    // For first half and quarter, like '」・'
                    else if punctuation == .firstHalf && nextPunctuation == .quarter {
                        height = adjustFontSize * 0.5
                    }
                }
            }
            
            // Layout run
            if context.fontManager.needsToFlip(fontId: fontId, glyph: currentRun.glyph) {
                // An emoji is drawn from its own font at its own scale, so neither
                // its advance nor its bounding box matches the text around it and
                // putting it on the baseline would leave it off the grid. Centre
                // its bounding box in the em box instead, on both axes.
                // The flipped draw path puts the ink at
                // [position.y - boundingRect.maxY - boundingRect.height,
                //  position.y - boundingRect.maxY], hence the y below.
                let boundingRect = currentRun.boundingRect
                currentRun.position = .init(
                    x: x + (adjustFontSize - currentRun.advance.width) * 0.5,
                    y: y + (adjustFontSize + boundingRect.height) * 0.5 + boundingRect.maxY)
            }
            else {
                currentRun.position = .init(
                    x: x, 
                    y: posY)
            }
            currentRun.frame = .init(
                x: x, 
                y: y, 
                width: currentRun.advance.width, 
                height: height)
        }
        
        // Update the run in the array
        context.runs[runId] = currentRun
    }
    
    private func layoutRun() {
        // Switch by direction
        switch context.direction {
        case .lrTb: layoutRunLrTb()
        case .tbRl: layoutRunTbRl()
        }
    }
    
    //--------------------------------------------------------------//
    // MARK: - Char and line
    //--------------------------------------------------------------//
    
    private func goNextLineLrTb() {
        // For not fixed width
        if !context.isFixedWidth {
            // Swtich by punctuation mode
            switch context.punctuationMode {
            case .stone:
                // For second half begin run, like '「'
                if context.runs[lineStartRunId].punctuation == .secondHalf {
                    // Set position and frame
                    let dx = context.runs[lineStartRunId].advance.width * 0.5
                    var position = context.runs[lineStartRunId].position
                    position.x -= dx
                    context.runs[lineStartRunId].position = position
                    var frame = context.runs[lineStartRunId].frame
                    frame.size.width = context.runs[lineStartRunId].advance.width * 0.5
                    context.runs[lineStartRunId].frame = frame
                    
                    // Shift rest runs
                    if lineStartRunId + 1 < self.runId {
                        for runId in lineStartRunId + 1 ..< self.runId + 1 {
                            position = context.runs[runId].position
                            position.x -= dx
                            context.runs[runId].position = position
                            frame = context.runs[runId].frame
                            frame.origin.x -= dx
                            context.runs[runId].frame = frame
                        }
                    }
                }
                
                // For first half end run, link '。'
                if context.runs[runId].punctuation == .firstHalf {
                    // Set frame
                    var frame = context.runs[runId].frame
                    frame.size.width = context.runs[runId].advance.width * 0.5
                    context.runs[runId].frame = frame
                }
            default: break
            }
        }
        
        // Go next line
        x = minX
        y += context.adjustLineHeight
        tmpX = nil
    }
    
    private func goNextLineTbRl() {
        // For not fixed width
        if !context.isFixedWidth {
            // Swtich by punctuation mode
            switch context.punctuationMode {
            case .stone:
                // For second half begin run, like '「'
                if context.runs[lineStartRunId].punctuation == .secondHalf {
                    // Set position and frame
                    let dy = context.adjustFontSize * 0.5
                    var position = context.runs[lineStartRunId].position
                    position.y -= dy
                    context.runs[lineStartRunId].position = position
                    var frame = context.runs[lineStartRunId].frame
                    frame.size.height = context.adjustFontSize * 0.5
                    context.runs[lineStartRunId].frame = frame
                    
                    // Shift rest runs
                    if lineStartRunId + 1 < self.runId {
                        for runId in lineStartRunId + 1 ..< self.runId + 1 {
                            position = context.runs[runId].position
                            position.y -= dy
                            context.runs[runId].position = position
                            frame = context.runs[runId].frame
                            frame.origin.y -= dy
                            context.runs[runId].frame = frame
                        }
                    }
                }
                
                // For first half end run, link '。'
                if context.runs[runId].punctuation == .firstHalf {
                    // Set frame
                    var frame = context.runs[runId].frame
                    frame.size.height = context.adjustFontSize * 0.5
                    context.runs[runId].frame = frame
                }
            default: break
            }
        }
        
        // Go next line
        x -= context.adjustLineHeight
        y = 0
        tmpX = nil
    }
    
    private func goNextLine() {
        // Process kinsoku
        processNotEndingAndStarting()
        
        // Switch by direction
        switch context.direction {
        case .lrTb: goNextLineLrTb()
        case .tbRl: goNextLineTbRl()
        }
        
        // Increment line count
        context.lineCount += 1
        lineStartRunId = runId + 1
    }
    
    private func goNextCharLrTb() {
        // Cache current run reference
        let currentRun = context.runs[runId]
        
        // Move position
        if context.isFixedWidth {
            x += context.fontSize
        }
        else {
            x += currentRun.frame.width
        }
        
        // Check next run
        if runId + 1 < context.runs.count {
            // Cache current and next run data
            let tokenId = currentRun.tokenId
            let nextRun = context.runs[runId + 1]
            let nextTokenId = nextRun.tokenId
            
            // Check with token advance
            if tokenId != nextTokenId {
                if x + context.advance(token: context.tokens[nextTokenId]) > maxX {
                    // Go next line
                    goNextLine()
                }
            }
            // Check with run advance
            else {
                if x + nextRun.advance.width > maxX {
                    // Go next line
                    goNextLine()
                }
            }
        }
    }
    
    private func goNextCharTbRl() {
        // Cache current run reference
        let currentRun = context.runs[runId]
        
        // Check tate chu yoko
        if context.isTateChuYoko(run: currentRun) {
            // For not last
            guard context.isLastInToken(run: currentRun) else {
                // Keep current x
                if tmpX == nil { tmpX = x }
                
                // Move position
                x += currentRun.frame.width
                return
            }
            
            // Restore x
            if tmpX != nil {
                x = tmpX!
                tmpX = nil
            }
        }
        
        // Move position
        if context.isFixedWidth {
            y += context.fontSize
        }
        else {
            y += currentRun.frame.height
        }
        
        // For new line
        if currentRun.isNewline {
            // Go next line
            goNextLine()
            return
        }
        
        // Check next run
        if runId + 1 < context.runs.count {
            // Cache current and next run data
            let tokenId = currentRun.tokenId
            let nextRun = context.runs[runId + 1]
            let nextTokenId = nextRun.tokenId
            
            // Check with token advance
            if tokenId != nextTokenId {
                if y + context.advance(token: context.tokens[nextTokenId]) > maxY {
                    // Go next line
                    goNextLine()
                }
            }
            // Check with font size
            else {
                if y + context.adjustFontSize > maxY {
                    // Go next line
                    goNextLine()
                }
            }
        }
    }
    
    private func goNextChar() {
        // Switch by direction
        switch context.direction {
        case .lrTb: goNextCharLrTb()
        case .tbRl: goNextCharTbRl()
        }
    }
    
    //--------------------------------------------------------------//
    // MARK: - Process kinshoku
    //--------------------------------------------------------------//
    
    private func processNotEndingAndStartingForHanging() {
        // For new line
        guard !context.runs[runId].isNewline else { return }
        
        // Decide next line start run
        var nextStartRun: STRun?
        if runId < context.runs.count {
            if runId + 1 < context.runs.count {
                nextStartRun = context.runs[runId + 1]
            }
        }
        
        // For hanging
        if let run = nextStartRun, run.flags.contains(.hanging) {
            // Increment run ID
            runId += 1
            
            // Layout run
            layoutRun()
            
            // Let the hanging run be drawn past the end of the line. The render
            // size is left alone: it is what the following lines break at, and
            // growing it for every hanging run let them take more characters as
            // the text went on, out of the grid of the manuscript paper
            hangingOverhang = context.fontSize * 0.25
        }
    }
    
    private func processNotEndingAndStarting() {
        // Check features
        guard !context.isFixedWidth else {
            processNotEndingAndStartingForHanging()
            return
        }
        guard context.isKinsokuAvailable else { return }
        
        // For new line
        guard !context.runs[runId].isNewline else { return }
        
        // Declare closure for decrease run ID
        let decreaseRunId: (() -> Void) = {
            // Get token at prev run ID
            let tokenId = self.context.runs[self.runId - 1].tokenId
            let token = self.context.tokens[tokenId]
            
            // Decrease run ID
            self.runId = token.runIdRange.lowerBound - 1
            if self.runId < self.lineStartRunId {
                self.runId = self.lineStartRunId
            }
        }
        
        // Process not ending and stataring
        while runId > lineStartRunId {
            // Decide line end and next line start run
            var endRun: STRun?
            var nextStartRun: STRun?
            if runId < context.runs.count {
                endRun = context.runs[runId]
                if runId + 1 < context.runs.count {
                    nextStartRun = context.runs[runId + 1]
                }
            }
            
            // For not ending or starting
            if let run = endRun, run.flags.contains(.notEnding) {
                // Decrease run ID
                decreaseRunId()
                continue
            }
            
            // For not starting
            if let run = nextStartRun, run.flags.contains(.notStarting) {
                // Decrease run ID
                decreaseRunId()
                continue
            }
            
            break
        }
    }
    
    //--------------------------------------------------------------//
    // MARK: - Post layout
    //--------------------------------------------------------------//
    
    private func shiftPositionLrTb() {
        // Shift against the grid the lines sit on, not against the run frames.
        //
        // A run's frame is its own font's ascent above the shared baseline, and
        // fonts do not agree on that. A newline run carries no glyph at all and
        // only inherits the font of the character before it. Measuring the block
        // from those means the whole document moves depending on which fonts
        // happen to land on the first line, and the text stops sitting on the
        // grid the visible area is sized to - a line then reaches into the next
        // line's box, and a scroll cannot show both edges whole.
        let lineHeight = context.adjustLineHeight
        let renderHeight = context.renderSize.height

        // The grid the lines sit on
        let gridTop = -emAscent
        let gridBottom = gridTop + lineHeight * CGFloat(context.lineCount)

        // How far the glyphs actually reach. A font whose ascent is taller than
        // the one the grid is measured from would otherwise be cut at the top, so
        // the block has to hold both. Shifting by one amount keeps the lines a
        // line height apart whichever it turns out to be.
        var inkTop = CGFloat.greatestFiniteMagnitude
        var inkBottom = -CGFloat.greatestFiniteMagnitude
        for run in context.runs {
            // Skip the runs that carry no glyph of their own. A newline only
            // inherits the font of the character before it.
            guard !run.isNewline else { continue }
            inkTop = min(inkTop, run.frame.minY)
            inkBottom = max(inkBottom, run.frame.maxY)
        }

        let blockTop = min(gridTop, inkTop)
        let blockBottom = max(gridBottom, inkBottom == -CGFloat.greatestFiniteMagnitude ? gridBottom : inkBottom)
        let blockHeight = blockBottom - blockTop

        // Decide dy. Every case is expressed against the pre-shift coordinates.
        let dy: CGFloat
        switch context.directionAlign {
        case .start: dy = -blockTop
        case .middle: dy = -blockTop + (renderHeight - blockHeight) * 0.5
        case .end: dy = renderHeight - blockBottom
        }

        // Walk the runs in place. Going through context.runs for every element
        // costs a uniqueness check and a bounds check on each access.
        context.runs.withUnsafeMutableBufferPointer { runs in
            // Shift y
            for i in 0 ..< runs.count {
                runs[i].position.y += dy
                runs[i].frame = runs[i].frame.shift(dx: 0, dy: dy)
            }
        }
    }
    
    private func alignTextLrTb(runIdRange: Range<Int>) {
        // Calc total width. A reading is set over the word rather than beside
        // it, so it adds nothing to the length of the line and counts as none
        // of its tokens
        var total: CGFloat = 0
        var tokenCount = 0
        var prevTokeId: Int = .max
        for i in runIdRange {
            // Check the reading
            guard !context.runs[i].flags.contains(.rubyText) else { continue }
            
            // Add width
            total += context.runs[i].frame.width
            
            // Check token ID
            if context.runs[i].tokenId != prevTokeId {
                tokenCount += 1
                prevTokeId = context.runs[i].tokenId
            }
        }
        
        // Add what the readings reach past the words they are set over
        total += rubyOverhang(runIdRange: runIdRange)
        
        // Calc gap and diff
        let diff = context.renderSize.width - total
        let gap = diff / CGFloat(max(tokenCount - 1, 1))
        
        // Switch by text align
        switch context.textAlign {
        case .leading:
            // Do nothing
            break
        case .center:
            // Align to center
            for i in runIdRange {
                context.runs[i].position.x += diff * 0.5
                context.runs[i].frame = context.runs[i].frame.shift(dx: diff * 0.5, dy: 0)
            }
        case .trailng:
            // Align to trailing
            let diff = context.renderSize.width - total
            for i in runIdRange {
                context.runs[i].position.x += diff
                context.runs[i].frame = context.runs[i].frame.shift(dx: diff, dy: 0)
            }
        case .justify:
            // Check last run
            guard runIdRange.upperBound < context.runs.count else { return }
            guard !context.runs[runIdRange.upperBound - 1].isNewline else { break }
            
            // Align to justify. Only the gaps are added, and the runs keep the
            // spacing the layout gave them - which is what `total` above was
            // measured from, so the line comes out exactly the measure wide.
            //
            // Rebuilding every position from a running cursor instead, advancing
            // by frame.maxX - position.x, counts the overhang of a squeezed
            // opening bracket twice: stone mode draws such a bracket half an em
            // left of its cell, so that difference is not the cell's width. Two
            // of them on one line pushed it a whole character past the measure.
            var dx: CGFloat = 0
            var prevTokeId = context.runs[runIdRange.lowerBound].tokenId
            for index in 0 ..< runIdRange.count {
                // For first
                if index == 0 { continue }
                
                // Get run ID
                let i = runIdRange.lowerBound + index
                
                // A reading opens no gap of its own. It goes where the word it
                // is read from went, which is wherever the gaps before it left
                // that word
                if context.runs[i].flags.contains(.rubyText) {
                    context.runs[i].position.x += dx
                    context.runs[i].frame = context.runs[i].frame.shift(dx: dx, dy: 0)
                    continue
                }
                
                // Check token ID
                if context.runs[i].tokenId != prevTokeId {
                    // Increase dx
                    dx += gap
                    
                    // Set token ID
                    prevTokeId = context.runs[i].tokenId
                }
                
                // Shift x
                context.runs[i].position.x += dx
                context.runs[i].frame = context.runs[i].frame.shift(dx: dx, dy: 0)
            }
        }
    }
    
    private func alignTextLrTb() {
        // Check fixed width
        guard !context.isFixedWidth else { return }
        
        // Get runs
        var line = 0
        var lowerRunId = -1
        var upperRunId = 0
        for runId in 0 ..< context.runs.count {
            // Decide range for line
            if context.runs[runId].line == line {
                if lowerRunId == -1 { lowerRunId = runId }
                upperRunId = runId
                continue
            }
            
            // Align text
            if lowerRunId != -1 {
                alignTextLrTb(runIdRange: lowerRunId ..< upperRunId + 1)
            }
            
            // Set next line
            line = context.runs[runId].line
            lowerRunId = runId
            upperRunId = runId
        }
        
        // Align last
        if lowerRunId != -1 {
            alignTextLrTb(runIdRange: lowerRunId ..< upperRunId + 1)
        }
    }
    
    private func updateRenderedSizeLrTb() {
        // Decide max X and max Y. Lines the text is not allowed are left out
        // of it: they are not drawn, and a size measured with them in would be
        // the size of a text that is not there
        var maxX: CGFloat = 0
        var maxY: CGFloat = 0
        let context = self.context
        context.runs.withUnsafeBufferPointer { runs in
            for i in 0 ..< runs.count {
                guard context.isShownLine(runs[i].line) else { continue }
                maxX = max(maxX, runs[i].frame.maxX)
                maxY = max(maxY, runs[i].frame.maxY)
            }
        }

        // Set rendered size
        let height = max(context.lineHeight * CGFloat(shownLineCount), maxY)
        context.renderedSize = .init(width: maxX, height: height)
    }
    
    private func updateVisibility() {
        // Set visibility. Multi-line text grows along the block axis to fit its
        // content, so only the inline axis can ever clip it. Leaving the block
        // axis bounded would hide runs whenever the render size lags the content.
        var renderFrame = CGRect(origin: .zero, size: context.renderSize)

        // A hanging punctuation mark sits past the end of the line, and is shown
        switch context.direction {
        case .lrTb: renderFrame.size.width += hangingOverhang
        case .tbRl: renderFrame.size.height += hangingOverhang
        }

        if !context.isSingleLine {
            let unbounded = CGFloat.greatestFiniteMagnitude
            switch context.direction {
            case .lrTb:
                renderFrame.origin.y = -unbounded * 0.25
                renderFrame.size.height = unbounded * 0.5
            case .tbRl:
                renderFrame.origin.x = -unbounded * 0.25
                renderFrame.size.width = unbounded * 0.5
            }
        }
        /// The last run drawn where what came after it was left out
        var lastShownRunId: Int = -1

        // Walk the runs in place
        let context = self.context
        context.runs.withUnsafeMutableBufferPointer { runs in
            let runCount = runs.count
            for i in 0 ..< runCount {
                // Check the lines the text is allowed. A run on a line past
                // them is not drawn, whether it fell inside the room or not:
                // it is the count that says it is not to be there
                guard context.isShownLine(runs[i].line) else {
                    runs[i].visibility = .invisible
                    continue
                }

                // Decide shown. What comes next counts as shown only if it is
                // on a line the text is allowed as well as inside the room:
                // the run before a line that is not to be there is the last
                // one shown
                let isShown = renderFrame.intersects(runs[i].frame)
                let nextIsShown: Bool
                if i < runCount - 1 {
                    nextIsShown = context.isShownLine(runs[i + 1].line)
                        && renderFrame.contains(runs[i + 1].frame)
                }
                else {
                    nextIsShown = true
                }

                // Decide visibility
                if isShown && !nextIsShown {
                    runs[i].visibility = .visible
                    lastShownRunId = i
                }
                else {
                    runs[i].visibility = isShown ? .visible : .invisible
                }
            }
        }

        // Mark what is left out
        applyEllipsis(lastShownRunId: lastShownRunId)
    }
    
    private func postLayoutLrTb() {
        // Post layout
        shiftPositionLrTb()
        alignTextLrTb()
        updateRenderedSizeLrTb()
        updateVisibility()
    }
    
    private func shiftPositionTbRl() {
        // Hoist everything read from the context
        let lastLine = context.lineCount - 1
        let renderWidth = context.renderSize.width
        let adjustFontSize = context.adjustFontSize
        let directionAlign = context.directionAlign

        // Walk the runs in place
        context.runs.withUnsafeMutableBufferPointer { runs in
            // Decide min x and max x
            var minX: CGFloat = .greatestFiniteMagnitude
            for i in (0 ..< runs.count).reversed() {
                minX = min(minX, runs[i].frame.minX)
                guard runs[i].line == lastLine else { break }
            }
            var maxX: CGFloat = 0
            for i in 0 ..< runs.count {
                maxX = max(maxX, runs[i].frame.maxX)
                guard runs[i].line == 0 else { break }
            }
            guard minX < .greatestFiniteMagnitude && maxX > .greatestFiniteMagnitude * -1 else { return }

            // Decide dx
            let dx: CGFloat
            switch directionAlign {
            case .start: dx = renderWidth - maxX
            case .middle: dx = renderWidth - adjustFontSize - (renderWidth - (maxX - minX)) * 0.5
            case .end: dx = -minX
            }

            // Shift x
            for i in 0 ..< runs.count {
                runs[i].position.x += dx
                runs[i].frame = runs[i].frame.shift(dx: dx, dy: 0)
            }
        }
    }
    
    private func applyTateChuYokoTbRl() {
        // For tate chu yoko
        for token in context.tokens {
            // Check tate chu yoko
            guard context.isTateChuYoko(token: token) else { continue }
            
            // Calc total advance
            var total: CGFloat = 0
            for runId in token.runIdRange {
                total += context.runs[runId].advance.width
            }
            
            // Shift x
            let dx = (context.adjustFontSize - total) * 0.5
            for runId in token.runIdRange {
                context.runs[runId].position.x += dx
                context.runs[runId].frame = context.runs[runId].frame.shift(dx: dx, dy: 0)
            }
        }
    }
    
    private func lineMaxHeight() -> CGFloat {
        var maxHeight: CGFloat = 0
        
        // Get runs
        var line = 0
        var lowerRunId = -1
        var upperRunId = 0
        for runId in 0 ..< context.runs.count {
            // Decide range for line
            if context.runs[runId].line == line {
                if lowerRunId == -1 { lowerRunId = runId }
                upperRunId = runId
                continue
            }
            
            // Calc height
            let height = context.runs[upperRunId].frame.maxY - context.runs[lowerRunId].frame.minY
            maxHeight = max(maxHeight, height)
            
            // Set next line
            line = context.runs[runId].line
            lowerRunId = runId
            upperRunId = runId
        }
        
        // Calc last height
        if lowerRunId != -1 {
            let height = context.runs[upperRunId].frame.maxY - context.runs[lowerRunId].frame.minY
            maxHeight = max(maxHeight, height)
        }
        
        return maxHeight
    }
    
    private func alignTextTbRl(runIdRange: Range<Int>) {
        // Calc total height. A reading is set beside the word rather than
        // after it, so it adds nothing to the length of the line and counts
        // as none of its tokens
        var total: CGFloat = 0
        var tokenCount = 0
        var prevTokeId: Int = .max
        for i in runIdRange {
            // Check the reading
            guard !context.runs[i].flags.contains(.rubyText) else { continue }
            
            // For tate chu yoko
            if context.isTateChuYoko(run: context.runs[i]) {
                // For first one
                if context.runs[i].tokenRunIndex == 0 {
                    // Add height
                    total += context.runs[i].frame.height
                }
            }
            // For other
            else {
                // Add height
                total += context.runs[i].frame.height
            }
            
            // Check token ID
            if context.runs[i].tokenId != prevTokeId {
                tokenCount += 1
                prevTokeId = context.runs[i].tokenId
            }
        }
        
        // Add what the readings reach past the words they are set over
        total += rubyOverhang(runIdRange: runIdRange)
        
        // Calc gap and diff
        let diff = context.renderSize.height - total
        let gap = diff / CGFloat(max(tokenCount - 1, 1))
        
        // Switch by text align
        switch context.textAlign {
        case .leading:
            // Do nothing
            break
        case .center:
            // Shift y
            let dy = (maxY - minY - total) * 0.5
            for runId in runIdRange {
                context.runs[runId].position.y += dy
                context.runs[runId].frame = context.runs[runId].frame.shift(dx: 0, dy: dy)
            }
        case .trailng:
            // Align to trailing
            for i in runIdRange {
                context.runs[i].position.y += diff
                context.runs[i].frame = context.runs[i].frame.shift(dx: 0, dy: diff)
            }
        case .justify:
            // Check last run
            guard runIdRange.upperBound < context.runs.count else { return }
            guard !context.runs[runIdRange.upperBound - 1].isNewline else { break }
            
            // Align to justify
            var dy: CGFloat = 0
            var prevTokeId = context.runs[runIdRange.lowerBound].tokenId
            for index in 0 ..< runIdRange.count {
                // For first
                if index == 0 { continue }
                
                // Get run ID
                let i = runIdRange.lowerBound + index
                
                // A reading opens no gap of its own. It goes where the word it
                // is read from went, which is wherever the gaps before it left
                // that word
                if context.runs[i].flags.contains(.rubyText) {
                    context.runs[i].position.y += dy
                    context.runs[i].frame = context.runs[i].frame.shift(dx: 0, dy: dy)
                    continue
                }
                
                // Check token ID
                if context.runs[i].tokenId != prevTokeId {
                    // Increase dy
                    dy += gap
                    
                    // Set token ID
                    prevTokeId = context.runs[i].tokenId
                }
                
                // Shift y
                context.runs[i].position.y += dy
                context.runs[i].frame = context.runs[i].frame.shift(dx: 0, dy: dy)
            }
        }
    }
    
    private func alignTextTbRl() {
        // Check fixed width
        guard !context.isFixedWidth else { return }
        
        // Get runs
        var line = 0
        var lowerRunId = -1
        var upperRunId = 0
        for runId in 0 ..< context.runs.count {
            // Decide range for line
            if context.runs[runId].line == line {
                if lowerRunId == -1 { lowerRunId = runId }
                upperRunId = runId
                continue
            }
            
            // Align text
            if lowerRunId != -1 {
                alignTextTbRl(runIdRange: lowerRunId ..< upperRunId + 1)
            }
            
            // Set next line
            line = context.runs[runId].line
            lowerRunId = runId
            upperRunId = runId
        }
        
        // Align last
        if lowerRunId != -1 {
            alignTextTbRl(runIdRange: lowerRunId ..< upperRunId + 1)
        }
    }
    
    private func updateRenderedSizeTbRl() {
        // Decide min X, max X, min Y and max Y
        var minX: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = 0
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxY: CGFloat = 0
        let context = self.context
        context.runs.withUnsafeBufferPointer { runs in
            for i in 0 ..< runs.count {
                guard context.isShownLine(runs[i].line) else { continue }
                minX = min(minX, runs[i].frame.minX)
                maxX = max(maxX, runs[i].frame.maxX)
                minY = min(minY, runs[i].frame.minY)
                maxY = max(maxY, runs[i].frame.maxY)
            }
        }

        // Set rendered size
        if minX < .greatestFiniteMagnitude && maxX > 0 {
            context.renderedSize.width = max(context.lineHeight * CGFloat(shownLineCount), maxX - minX)
        }
        else {
            context.renderedSize.width = context.lineHeight * CGFloat(shownLineCount)
        }
        if minY < .greatestFiniteMagnitude && maxY > 0 {
            context.renderedSize.height = maxY - minY
        }
        else {
            context.renderedSize.height = 0
        }
    }
    
    private func postLayoutTbRl() {
        // Post layout
        shiftPositionTbRl()
        applyTateChuYokoTbRl()
        alignTextTbRl()
        updateRenderedSizeTbRl()
        updateVisibility()
    }
    
    private func postLayout() {
        // Switch by direction
        switch context.direction {
        case .lrTb: postLayoutLrTb()
        case .tbRl: postLayoutTbRl()
        }
    }
    
    //--------------------------------------------------------------//
    // MARK: - Ruby
    //--------------------------------------------------------------//

    /// The ruby a run belongs to, whether it is one of the word's own runs or
    /// one of the reading's
    private func ruby(containing runId: Int) -> STRuby? {
        // Find the ruby this run is part of
        return context.rubies.first {
            $0.rbcRunIdRange.contains(runId) || $0.rtcRunIdRange.contains(runId)
        }
    }

    /// How far the readings on a line reach past the words they are set over.
    ///
    /// A reading is set over the word rather than beside it, so it lengthens
    /// the line only by what it cannot fit above. A line is as long as its
    /// words, unless a reading is wider than the word it belongs to: the
    /// layout then sets the word in from the edge to make room, and the line
    /// is as long as the reading.
    ///
    /// Counted for the readings that begin on this line. A reading is never
    /// split from its word, so the pair is always on the one line.
    private func rubyOverhang(runIdRange: Range<Int>) -> CGFloat {
        // Measure along the way the line runs
        func length(of run: STRun) -> CGFloat {
            switch context.direction {
            case .lrTb: return run.frame.width
            case .tbRl: return run.frame.height
            }
        }

        // Add up what each reading reaches past its word
        var overhang: CGFloat = 0
        for ruby in context.rubies {
            // Check the line
            guard runIdRange.contains(ruby.rtcRunIdRange.lowerBound) else { continue }

            // Measure the word and the reading
            var baseLength: CGFloat = 0
            for i in ruby.rbcRunIdRange where runIdRange.contains(i) {
                baseLength += length(of: context.runs[i])
            }
            var readingLength: CGFloat = 0
            for i in ruby.rtcRunIdRange where runIdRange.contains(i) {
                readingLength += length(of: context.runs[i])
            }

            // A reading that fits above the word adds nothing
            overhang += max(0, readingLength - baseLength)
        }

        return overhang
    }

    /// Takes the layout back to the start of a ruby where it is about to begin
    /// in the middle of one.
    ///
    /// A reading and the word it is set over are laid out together, by the
    /// word: the reading is never laid out on its own. Laying out can begin
    /// part way through a ruby all the same — a line broken and then laid
    /// again begins wherever the break left it — and the reading would then
    /// be set as ordinary text, in the line beside the word instead of over it
    private func rewindToRuby() {
        // Check the run
        guard let ruby = ruby(containing: runId) else { return }
        guard runId != ruby.rbcRunIdRange.lowerBound else { return }

        // Take it back to the word
        runId = ruby.rbcRunIdRange.lowerBound
    }

    /// Moves to the next line because a reading will not fit on this one.
    ///
    /// Not `goNextLine()`, which is the end of a line reached by setting text
    /// into it: that one works the kinsoku over the run it stopped at and
    /// takes the next line to begin after it. Nothing has been set here. The
    /// line is left as it stands and the ruby begins the next one
    private func goNextLineForRuby() {
        // Switch by direction
        switch context.direction {
        case .lrTb:
            x = minX
            y += context.adjustLineHeight
        case .tbRl:
            x -= context.adjustLineHeight
            y = minY
        }
        tmpX = nil

        // Begin a line at the ruby itself
        context.lineCount += 1
        lineStartRunId = runId
    }

    /// Sets a reading over the word it belongs to, going across the page.
    ///
    /// The word and the reading are each set as a run of their own glyphs and
    /// the wider of the two decides how much room the pair takes; the narrower
    /// is centred in it. A reading is never broken away from its word, so the
    /// pair is carried to the next line whole.
    ///
    /// - Returns: whether a ruby began here and was laid out
    @discardableResult
    private func applyRubyLrTb() -> Bool {
        // Find a ruby starting at current runId
        guard let ruby = context.rubies.first(where: { $0.rbcRunIdRange.lowerBound == runId }) else {
            return false
        }

        // Calculate rbc width
        var rbcWidth: CGFloat = 0
        for i in ruby.rbcRunIdRange {
            rbcWidth += context.runs[i].advance.width
        }

        // Calculate rtc width
        var rtcWidth: CGFloat = 0
        for i in ruby.rtcRunIdRange {
            rtcWidth += context.runs[i].advance.width
        }

        // Ruby width is the larger of the two (don't break inside ruby)
        let rubyWidth = max(rbcWidth, rtcWidth)

        // Wrap to next line first if ruby would exceed line end
        if x + rubyWidth > maxX, runId > lineStartRunId {
            goNextLineForRuby()
        }

        // Layout rbc runs as normal text, centered within rubyWidth
        var rbcX = x + (rubyWidth - rbcWidth) * 0.5
        var rbcTotalHeight: CGFloat = 0
        for i in ruby.rbcRunIdRange {
            var run = context.runs[i]
            run.line = context.lineCount
            let runFontSize = context.adjustFontSize * run.fontScale
            let ascent = context.fontManager.ascent(fontId: run.fontId, size: runFontSize)
            run.position = .init(x: rbcX, y: y)
            run.frame = .init(
                x: rbcX,
                y: y - ascent,
                width: run.advance.width,
                height: runFontSize * context.fontManager.fontScale(fontId: run.fontId)
            )
            context.runs[i] = run
            rbcX += run.advance.width
            rbcTotalHeight += run.frame.height
        }
        let rbcHeight = rbcTotalHeight / CGFloat(ruby.rbcRunIdRange.count)

        // Layout rtc runs above rbc, centered within rubyWidth
        var rtcX = x + (rubyWidth - rtcWidth) * 0.5
        for i in ruby.rtcRunIdRange {
            var run = context.runs[i]
            run.line = context.lineCount
            let runFontSize = context.adjustFontSize * run.fontScale
            let ascent = context.fontManager.ascent(fontId: run.fontId, size: runFontSize)
            let rtcBaselineY = y - rbcHeight + context.fontManager.descent(fontId: run.fontId, size: runFontSize)
            run.position = .init(x: rtcX, y: rtcBaselineY)
            run.frame = .init(
                x: rtcX,
                y: rtcBaselineY - ascent,
                width: run.advance.width,
                height: runFontSize * context.fontManager.fontScale(fontId: run.fontId)
            )
            context.runs[i] = run
            rtcX += run.advance.width
        }

        // Advance x past ruby
        x += rubyWidth

        // Move runId
        runId = ruby.rtcRunIdRange.upperBound

        return true
    }

    /// Sets a reading beside the word it belongs to, going down the page.
    ///
    /// - Returns: whether a ruby began here and was laid out
    @discardableResult
    private func applyRubyTbRl() -> Bool {
        // Find a ruby starting at current runId
        guard let ruby = context.rubies.first(where: { $0.rbcRunIdRange.lowerBound == runId }) else {
            return false
        }

        // Calculate rbc height. Down a column a character is sent on by its em
        // box rather than by the width of its glyph, and a reading is sent on
        // by an em box of its own size.
        var rbcHeight: CGFloat = 0
        for i in ruby.rbcRunIdRange {
            rbcHeight += context.adjustFontSize * context.runs[i].fontScale
        }

        // Calculate rtc height
        var rtcHeight: CGFloat = 0
        for i in ruby.rtcRunIdRange {
            rtcHeight += context.adjustFontSize * context.runs[i].fontScale
        }

        // Ruby height is the larger of the two (don't break inside ruby)
        let rubyHeight = max(rbcHeight, rtcHeight)

        // Wrap to next line first if ruby would exceed line end
        if y + rubyHeight > maxY, runId > lineStartRunId {
            goNextLineForRuby()
        }

        // Layout rbc runs as normal text, centered within rubyHeight
        var rbcY = y + (rubyHeight - rbcHeight) * 0.5
        var rbcTotalWidth: CGFloat = 0
        for i in ruby.rbcRunIdRange {
            var run = context.runs[i]
            run.line = context.lineCount
            let runFontSize = context.adjustFontSize * run.fontScale
            let descent = context.fontManager.descent(fontId: run.fontId, size: runFontSize)
            run.position = .init(x: x, y: rbcY + runFontSize - descent)
            run.frame = .init(
                x: x,
                y: rbcY,
                width: run.advance.width,
                height: runFontSize
            )
            context.runs[i] = run
            rbcY += runFontSize
            rbcTotalWidth += run.frame.width
        }
        let rbcWidth = rbcTotalWidth / CGFloat(ruby.rbcRunIdRange.count)

        // Layout rtc runs to the right of rbc, centered within rubyHeight. A
        // column is read down the page and the lines run right to left, so the
        // room beside a column on its right is the gap the line before it left.
        var rtcY = y + (rubyHeight - rtcHeight) * 0.5
        for i in ruby.rtcRunIdRange {
            var run = context.runs[i]
            run.line = context.lineCount
            let runFontSize = context.adjustFontSize * run.fontScale
            let descent = context.fontManager.descent(fontId: run.fontId, size: runFontSize)
            run.position = .init(x: x + rbcWidth, y: rtcY + runFontSize - descent)
            run.frame = .init(
                x: x + rbcWidth,
                y: rtcY,
                width: run.advance.width,
                height: runFontSize
            )
            context.runs[i] = run
            rtcY += runFontSize
        }

        // Advance y past ruby
        y += rubyHeight

        // Move runId
        runId = ruby.rtcRunIdRange.upperBound

        return true
    }

    /// - Returns: whether a ruby began here and was laid out
    @discardableResult
    private func applyRuby() -> Bool {
        // Nothing to look for in a text that carries no reading, which is most
        // of them
        guard !context.rubies.isEmpty else { return false }

        // Switch by direction
        switch context.direction {
        case .lrTb: return applyRubyLrTb()
        case .tbRl: return applyRubyTbRl()
        }
    }

    //--------------------------------------------------------------//
    // MARK: - Ellipsis
    //--------------------------------------------------------------//

    /// Where a glyph begins, along the way the lines run
    private func runStart(_ run: STRun) -> CGFloat {
        // Switch by direction
        switch context.direction {
        case .lrTb: return run.frame.minX
        case .tbRl: return run.frame.minY
        }
    }

    /// Where a glyph ends, along the way the lines run
    private func runEnd(_ run: STRun) -> CGFloat {
        // Switch by direction
        switch context.direction {
        case .lrTb: return run.frame.maxX
        case .tbRl: return run.frame.maxY
        }
    }

    /// How far the mark may reach: the end of the room the text is drawn in,
    /// along the way the lines run
    private var ellipsisLimit: CGFloat {
        // Switch by direction
        switch context.direction {
        case .lrTb: return context.renderSize.width
        case .tbRl: return context.renderSize.height
        }
    }

    /// Where the mark set in place of a glyph would end
    private func ellipsisEnd(of run: STRun, advance: CGFloat) -> CGFloat {
        // Switch by direction
        switch context.direction {
        case .lrTb: return run.frame.minX + advance
        case .tbRl: return run.frame.minY + advance
        }
    }

    /// Whether a glyph is drawn wholly inside the room, along the way the
    /// lines run. A glyph that is only partly in it is cut through by the edge
    private func isInsideRoom(_ run: STRun) -> Bool {
        // Switch by direction
        switch context.direction {
        case .lrTb: return run.frame.maxX <= ellipsisLimit
        case .tbRl: return run.frame.maxY <= ellipsisLimit
        }
    }

    /// Sets the mark that says the text goes on, in place of the last glyphs
    /// shown.
    ///
    /// The mark is a glyph of its own, and a wider one than most of those it
    /// stands in for: set in place of a single narrow glyph it would be drawn
    /// past the end of the line and cut off there. The glyphs at the end of
    /// the line are given up one by one until the room they leave takes it
    private func applyEllipsis(lastShownRunId: Int) {
        // Check whether anything is to be marked
        guard context.isShownEllipsis else { return }
        guard lastShownRunId >= 0, lastShownRunId < context.runs.count else { return }

        // The line the text stops on. The mark says that line goes on, and
        // moving it to the line before would say it of the wrong one
        let line = context.runs[lastShownRunId].line

        // Find the glyph the mark is set in place of, before anything is given
        // up: a line with nowhere to put the mark keeps the words it has,
        // which is better than a line left with nothing on it at all
        var runId = lastShownRunId
        var markRunId: Int?
        while runId >= 0, context.runs[runId].line == line {
            // A reading is passed over for the text it is set above. The mark
            // stands in for a glyph of the line, in the size the line is set
            // in: set on a reading it would be drawn small and above the line,
            // where it reads as a reading of the word below rather than as the
            // text going on
            if let ruby = ruby(containing: runId), ruby.rtcRunIdRange.contains(runId) {
                runId = ruby.rbcRunIdRange.upperBound - 1
                continue
            }

            // Check the mark fits where that glyph is set. The room, rather
            // than the width of what is given up: a line can be set past the
            // end of the room it was given — a word with nowhere to break, a
            // mark hung past the edge — and a mark put where that glyph was
            // would be drawn outside the room and cut off by it
            let candidate = context.runs[runId]
            let ellipsisAdvance = context.fontManager.ellipsisAdvance(
                fontId: candidate.fontId,
                size: context.adjustFontSize * candidate.fontScale,
                direction: context.direction
            )
            if ellipsisEnd(of: candidate, advance: ellipsisAdvance) <= ellipsisLimit {
                markRunId = runId
                break
            }

            // Look further back
            runId -= 1
        }

        // For nowhere to put the mark, the line stands as it is
        guard let markRunId = markRunId else { return }

        // The reading of a word the mark cuts into is not given up with the
        // rest: it is set over the word as a whole, above the line, and what
        // of it falls in the room reads as much as the text under it does. It
        // is held to the room on its own, below
        let markRuby = ruby(containing: markRunId)

        // Give up the glyphs the mark stands in for. There may be none: the
        // mark can stand in for the last glyph of the line and no more
        if markRunId < lastShownRunId {
            for i in (markRunId + 1) ... lastShownRunId
                where context.runs[i].line == line
                    && !(markRuby?.rtcRunIdRange.contains(i) ?? false)
            {
                context.runs[i].visibility = .invisible
            }
        }

        // Set what is left of the word's reading over what is left of the word
        if let ruby = markRuby {
            for i in ruby.rbcRunIdRange where i > markRunId {
                context.runs[i].visibility = .invisible
            }
            shiftEllipsisRuby(ruby, markRunId: markRunId)
        }

        // Set the mark
        context.runs[markRunId].visibility = .ellipsis
    }

    /// Sets a reading over what is left of the word it belongs to.
    ///
    /// A reading is set over the whole of a word, and a word the mark has cut
    /// into is no longer the word it was set over: left where it was, the
    /// reading stands over the glyphs that went — past the mark, and as often
    /// as not outside the room altogether, where none of it is read at all.
    /// Moved over the text still shown, it goes on reading for it, as far as
    /// the room takes it
    private func shiftEllipsisRuby(_ ruby: STRuby, markRunId: Int) {
        // Get what is left of the word. The mark is not part of it: it stands
        // for what went, and a reading set over it would read for nothing
        let shownRbcIds = ruby.rbcRunIdRange.filter { $0 < markRunId }
        guard let firstRbcId = shownRbcIds.first, let lastRbcId = shownRbcIds.last else {
            // Nothing of the word is left, so neither is its reading
            for i in ruby.rtcRunIdRange { context.runs[i].visibility = .invisible }
            return
        }

        // Measure the word and its reading along the way the line runs
        let wordStart = runStart(context.runs[firstRbcId])
        let wordEnd = runEnd(context.runs[lastRbcId])
        var rtcStart: CGFloat = .greatestFiniteMagnitude
        var rtcEnd: CGFloat = -.greatestFiniteMagnitude
        for i in ruby.rtcRunIdRange {
            rtcStart = min(rtcStart, runStart(context.runs[i]))
            rtcEnd = max(rtcEnd, runEnd(context.runs[i]))
        }
        guard rtcStart < .greatestFiniteMagnitude else { return }

        // Set it over the middle of what is left where it fits, and from the
        // beginning of it where it does not: a reading with less room than it
        // needs is read from its start, as the text is
        let word = wordEnd - wordStart
        let reading = rtcEnd - rtcStart
        let shift = (reading <= word ? wordStart + (word - reading) * 0.5 : wordStart) - rtcStart

        // Move the reading, and give up what the room does not take
        for i in ruby.rtcRunIdRange {
            switch context.direction {
            case .lrTb:
                context.runs[i].position.x += shift
                context.runs[i].frame = context.runs[i].frame.shift(dx: shift, dy: 0)
            case .tbRl:
                context.runs[i].position.y += shift
                context.runs[i].frame = context.runs[i].frame.shift(dx: 0, dy: shift)
            }
            context.runs[i].visibility = isInsideRoom(context.runs[i]) ? .visible : .invisible
        }
    }

    //--------------------------------------------------------------//
    // MARK: - Layout
    //--------------------------------------------------------------//
    
    public func layout() {
        // Notify it
        NotificationCenter.default.post(name: Self.willLayout, object: self)
        
        // Update layout version
        context.layoutVersion += 1
        
        // Initialize
        emAscent = context.fontManager.primaryAscent(size: context.adjustFontSize)
        context.lineCount = 0
        x = minX
        y = minY
        tmpX = nil
        runId = 0
        lineStartRunId = 0
        hangingOverhang = 0
        
        // Layout
        while runId < context.runs.count {
            // Begin at the word a reading belongs to, never inside the pair
            rewindToRuby()

            // Set the reading over its word.
            //
            // One reading may be followed straight away by another, in a word
            // where every character carries its own, so where the last one
            // left off is offered to the next rather than being laid out as
            // ordinary text
            if applyRuby() {
                continue
            }
            guard runId < context.runs.count else { break }

            // Layout run
            layoutRun()
            
            // For new line
            if context.runs[runId].isNewline {
                // Get next line
                goNextLine()
            }
            // For other
            else {
                // Go next char
                goNextChar()
            }
            
            // Increment run ID
            runId += 1
        }
        
        // Increment line count
        context.lineCount += 1
        
        // Post layout
        postLayout()
        
        // Notify it
        NotificationCenter.default.post(name: Self.didLayout, object: self)
    }
}

extension CGRect {
    func shift(dx: CGFloat, dy: CGFloat) -> CGRect {
        // Shift itself
        return .init(x: minX + dx, y: minY + dy, width: width, height: height)
    }
}
