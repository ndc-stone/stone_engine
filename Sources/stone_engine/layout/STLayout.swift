/*
STLayout.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center. All rights reserved.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(iOS)
import UIKit
#elseif os(macOS)
import Cocoa
#endif

class STLayout {
    static let willLayout = Notification.Name("STLayoutWillLayout")
    static let didLayout = Notification.Name("STLayoutDidLayout")
    
    // Context
    let context: STContext
    
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

    // The ascent the line's em box is measured from, for this layout pass
    private var emAscent: CGFloat = 0
    
    //--------------------------------------------------------------//
    // MARK: - Initialize
    //--------------------------------------------------------------//
    
    init(context: STContext) {
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
            
            // Extend geometry with hanging
            switch context.direction {
            case .lrTb: context.renderSize.width += context.fontSize * 0.25
            case .tbRl: context.renderSize.height += context.fontSize * 0.25
            }
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
        // Calc total width
        var total: CGFloat = 0
        var tokenCount = 0
        var prevTokeId: Int = .max
        for i in runIdRange {
            // Add width
            total += context.runs[i].frame.width
            
            // Check token ID
            if context.runs[i].tokenId != prevTokeId {
                tokenCount += 1
                prevTokeId = context.runs[i].tokenId
            }
        }
        
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
        // Decide max X and max Y
        var maxX: CGFloat = 0
        var maxY: CGFloat = 0
        context.runs.withUnsafeBufferPointer { runs in
            for i in 0 ..< runs.count {
                maxX = max(maxX, runs[i].frame.maxX)
                maxY = max(maxY, runs[i].frame.maxY)
            }
        }

        // Set rendered size
        let height = max(context.lineHeight * CGFloat(context.lineCount), maxY)
        context.renderedSize = .init(width: maxX, height: height)
    }
    
    private func updateVisibility() {
        // Set visibility. Multi-line text grows along the block axis to fit its
        // content, so only the inline axis can ever clip it. Leaving the block
        // axis bounded would hide runs whenever the render size lags the content.
        var renderFrame = CGRect(origin: .zero, size: context.renderSize)
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
        // Walk the runs in place
        context.runs.withUnsafeMutableBufferPointer { runs in
            let runCount = runs.count
            for i in 0 ..< runCount {
                // Decide shown
                let isShown = renderFrame.intersects(runs[i].frame)
                let nextIsShown: Bool
                if i < runCount - 1 {
                    nextIsShown = renderFrame.contains(runs[i + 1].frame)
                }
                else {
                    nextIsShown = true
                }

                // Decide visibility
                if isShown && !nextIsShown {
                    runs[i].visibility = .visible
                }
                else {
                    runs[i].visibility = isShown ? .visible : .invisible
                }
            }
        }
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
        // Calc total height
        var total: CGFloat = 0
        var tokenCount = 0
        var prevTokeId: Int = .max
        for i in runIdRange {
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
        context.runs.withUnsafeBufferPointer { runs in
            for i in 0 ..< runs.count {
                minX = min(minX, runs[i].frame.minX)
                maxX = max(maxX, runs[i].frame.maxX)
                minY = min(minY, runs[i].frame.minY)
                maxY = max(maxY, runs[i].frame.maxY)
            }
        }

        // Set rendered size
        if minX < .greatestFiniteMagnitude && maxX > 0 {
            context.renderedSize.width = max(context.lineHeight * CGFloat(context.lineCount), maxX - minX)
        }
        else {
            context.renderedSize.width = context.lineHeight * CGFloat(context.lineCount)
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
    // MARK: - Layout
    //--------------------------------------------------------------//
    
    func layout() {
        // Notify it
        NotificationCenter.default.post(name: Self.willLayout, object: self)
        
        // Initialize
        emAscent = context.fontManager.primaryAscent(size: context.adjustFontSize)
        context.lineCount = 0
        x = minX
        y = minY
        tmpX = nil
        runId = 0
        lineStartRunId = 0
        
        // Layout
        while runId < context.runs.count {
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
