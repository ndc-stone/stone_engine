/*
STLayout.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center. All rights reserved.
This software is licensed under the MIT License. See LICENSE for details.
*/

import UIKit

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
    private var maxX: CGFloat { context.renderSize.width }
    private var maxY: CGFloat { context.renderSize.height }
    private var tmpX: CGFloat?
    
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
        // Set line
        context.runs[runId].line = context.lineCount
        
        // For new line
        if context.runs[runId].char.isNewline {
            // Layout run with 0 width
            context.runs[runId].position = .init(x: x, y: y)
            context.runs[runId].frame = .init(
                x: x, 
                y: y - context.fontManager.ascent(fontId: context.runs[runId].fontId, size: context.adjustFontSize), 
                width: 0, 
                height: context.fontSize)
        }
        // For other
        else {
            // Decide position x and frame width
            var posX: CGFloat = x
            var width: CGFloat = context.runs[runId].advance.width
            switch context.punctuationMode {
            case .whole:
                break
            case .half:
                // Set position x and frame
                switch context.runs[runId].punctuation {
                case .whole:
                    break
                case .firstHalf:
                    posX = x
                    width = context.runs[runId].advance.width * 0.5
                case .secondHalf:
                    posX = x - context.runs[runId].advance.width * 0.5
                    width = context.runs[runId].advance.width * 0.5
                case .quarter:
                    posX = x - context.runs[runId].advance.width * 0.25
                    width = context.runs[runId].advance.width * 0.5
                }
            case .stone:
                // Check with prev run
                if runId > 0 {
                    // For first half and frist half
                    if context.runs[runId - 1].punctuation == .firstHalf && context.runs[runId].punctuation == .firstHalf {
                        posX = x
                        width = context.runs[runId].advance.width * 0.5
                    }
                }
                
                // Check with next run
                if runId + 1 < context.runs.count {
                    // For first half and frist half
                    if context.runs[runId].punctuation == .firstHalf && context.runs[runId + 1].punctuation == .firstHalf {
                        posX = x
                        width = context.runs[runId].advance.width * 0.5
                    }
                    // For first half and second half
                    else if context.runs[runId].punctuation == .firstHalf && context.runs[runId + 1].punctuation == .secondHalf {
                        posX = x
                        width = context.runs[runId].advance.width
                    }
                    // For second half and second half
                    else if context.runs[runId].punctuation == .secondHalf && context.runs[runId + 1].punctuation == .secondHalf {
                        posX = x
                        width = context.runs[runId].advance.width
                    }
                    // For first half and quarter
                    else if context.runs[runId].punctuation == .firstHalf && context.runs[runId + 1].punctuation == .quarter {
                        posX = x
                        width = context.runs[runId].advance.width
                    }
                    // For quarter and second half
                    else if context.runs[runId].punctuation == .firstHalf && context.runs[runId + 1].punctuation == .quarter {
                        posX = x
                        width = context.runs[runId].advance.width
                    }
                    
                    /*
                    switch context.runs[runId].punctuation {
                    case .whole:
                        posX = x
                        width = context.runs[runId].advance.width
                    case .firstHalf:
                        posX = x
                        width = context.runs[runId].advance.width * 0.5
                    case .secondHalf:
                        posX = x - context.runs[runId].advance.width * 0.5
                        width = context.runs[runId].advance.width * 0.5
                    case .quarter:
                        posX = x - context.runs[runId].advance.width * 0.25
                        width = context.runs[runId].advance.width * 0.5
                    }
                    */
                }
                // For no next run
                else {
                    posX = x
                    width = context.runs[runId].advance.width
                }
            }
            
            // Layout run
            context.runs[runId].position = .init(x: posX, y: y)
            context.runs[runId].frame = .init(
                x: x, 
                y: y - context.fontManager.ascent(fontId: context.runs[runId].fontId, size: context.adjustFontSize), 
                width: width, 
                height: context.adjustFontSize * context.fontManager.fontScale(fontId: context.runs[runId].fontId))
        }
    }
    
    private func layoutRunTbRl() {
        // Set line
        context.runs[runId].line = context.lineCount
        
        // For new line
        if context.runs[runId].char.isNewline {
            // Layout run with 0 height
            context.runs[runId].position = .init(
                x: x, 
                y: y + context.adjustFontSize - context.fontManager.descent(fontId: context.runs[runId].fontId, size: context.adjustFontSize))
            context.runs[runId].frame = .init(
                x: x, 
                y: y, 
                width: context.fontSize, 
                height: 0)
        }
        // For clockwise
        else if context.isClockwise(run: context.runs[runId]) {
            // Layout run in clockwise
            context.runs[runId].position = .init(
                x: x + context.fontManager.descent(fontId: context.runs[runId].fontId, size: context.adjustFontSize), 
                y: y)
            context.runs[runId].frame = .init(
                x: x, 
                y: y, 
                width: context.adjustFontSize, 
                height: context.runs[runId].advance.width)
        }
        // For not clockwise
        else {
            // Decide position y and frame height
            var posY = y + context.adjustFontSize - context.fontManager.descent(fontId: context.runs[runId].fontId, size: context.adjustFontSize)
            let height: CGFloat
            switch context.punctuationMode {
            case .whole:
                height = context.adjustFontSize
            case .half, .stone:
                switch context.runs[runId].punctuation {
                case .whole:
                    height = context.adjustFontSize
                case .firstHalf:
                    height = context.adjustFontSize * 0.5
                case .secondHalf:
                    posY -= context.adjustFontSize * 0.5
                    height = context.adjustFontSize * 0.5
                case .quarter:
                    posY -= context.adjustFontSize * 0.25
                    height = context.adjustFontSize * 0.5
                }
            }
            
            // Layout run
            if context.fontManager.needsToFlip(fontId: context.runs[runId].fontId) {
                context.runs[runId].position = .init(
                    x: x, 
                    y: y + context.adjustFontSize - context.fontManager.descent(fontId: context.runs[runId].fontId, size: context.adjustFontSize) * 0.5)
            }
            else {
                context.runs[runId].position = .init(
                    x: x, 
                    y: posY)
            }
            context.runs[runId].frame = .init(
                x: x, 
                y: y, 
                width: context.runs[runId].advance.width, 
                height: height)
        }
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
        // Go next line
        x = minX
        y += context.adjustLineHeight
    }
    
    private func goNextLineTbRl() {
        // Go next line
        x -= context.adjustLineHeight
        y = 0
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
        // Move position
        x += context.runs[runId].frame.width
        
        // For new line
        if context.runs[runId].char.isNewline {
            // Go next line
            goNextLine()
            return
        }
        
        // Check next run
        if runId + 1 < context.runs.count {
            // Check with token advance
            let tokenId = context.runs[runId].tokenId
            let nextTokenId = context.runs[runId + 1].tokenId
            if tokenId != nextTokenId {
                if x + context.advance(token: context.tokens[nextTokenId]) > maxX {
                    // Go next line
                    goNextLine()
                }
            }
            // Check with run advance
            else {
                if x + context.runs[runId + 1].advance.width > maxX {
                    // Go next line
                    goNextLine()
                }
            }
        }
    }
    
    private func goNextCharTbRl() {
        // Check tate chu yoko
        if context.isTateChuYoko(run: context.runs[runId]) {
            // For not last
            guard context.isLastInToken(run: context.runs[runId]) else {
                // Keep current x
                if tmpX == nil { tmpX = x }
                
                // Move position
                x += context.runs[runId].frame.width
                return
            }
            
            // Restore x
            if tmpX != nil {
                x = tmpX!
                tmpX = nil
            }
        }
        
        // Move position
        y += context.runs[runId].frame.height
        
        // For new line
        if context.runs[runId].char.isNewline {
            // Go next line
            goNextLine()
            return
        }
        
        // Check next run
        if runId + 1 < context.runs.count {
            // Check with token advance
            let tokenId = context.runs[runId].tokenId
            let nextTokenId = context.runs[runId + 1].tokenId
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
    
    private func processNotEndingAndStarting() {
        // Check features
        guard context.isKinsokuAvailable else { return }
        
        // For new line
        guard !context.runs[runId].char.isNewline else { return }
        
        // Declare closure for decrease run ID
        let decreaseRunId: (() -> Void) = {
            // Get token at prev run ID
            let tokenId = self.context.runs[self.runId - 1].tokenId
            let token = self.context.tokens[tokenId]
            
            // Decrease run ID
            self.runId -= token.runIdRange.count
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
            if let run = endRun, let scalr = run.char.unicodeScalars.first, STKinsoku.notEndingCharSet.contains(scalr) {
                // Decrease run ID
                decreaseRunId()
                continue
            }
            
            // For not starting
            if let run = nextStartRun, let scalr = run.char.unicodeScalars.first, STKinsoku.notStartingCharSet.contains(scalr) {
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
        // Decide min y and max y
        var minY: CGFloat = .greatestFiniteMagnitude
        for i in 0 ..< context.runs.count {
            guard context.runs[i].line == 0 else { break }
            minY = min(minY, context.runs[i].frame.minY)
        }
        var maxY: CGFloat = 0
        for i in (0 ..< context.runs.count).reversed() {
            guard context.runs[i].line == context.lineCount - 1 else { break }
            maxY = max(maxY, context.runs[i].frame.maxY)
        }
        guard minY < .greatestFiniteMagnitude && maxY > .greatestFiniteMagnitude * -1 else { return }
        
        // Decide dy
        let dy: CGFloat
        switch context.directionAlign {
        case .start: dy = -minY
        case .middle: dy = (context.renderSize.height - (maxY - minY)) * 0.5
        case .end: dy = context.renderSize.height - maxY
        }
        
        // Shift y
        for i in 0 ..< context.runs.count {
            context.runs[i].position.y += dy
            context.runs[i].frame = context.runs[i].frame.shift(dx: 0, dy: dy)
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
        let gap = (context.renderSize.width - total) / CGFloat(tokenCount)
        let diff = context.renderSize.width - total
        
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
            guard !context.runs[runIdRange.upperBound - 1].char.isNewline else { break }
            
            // Align to justify
            var x = context.runs[runIdRange.lowerBound].position.x
            var prevTokeId = context.runs[runIdRange.lowerBound].tokenId
            for i in runIdRange {
                // Check token ID
                if context.runs[i].tokenId != prevTokeId {
                    prevTokeId = context.runs[i].tokenId
                    x += gap
                }
                
                // Shift x
                let dx = x - context.runs[i].position.x
                context.runs[i].position.x += dx
                context.runs[i].frame = context.runs[i].frame.shift(dx: dx, dy: 0)
                
                // Move x
                x += context.runs[i].frame.width
            }
        }
    }
    
    private func alignTextLrTb() {
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
        for i in 0 ..< context.runs.count {
            maxX = max(maxX, context.runs[i].frame.maxX)
            maxY = max(maxY, context.runs[i].frame.maxY)
        }
        
        // Set rendered size
        context.renderedSize = .init(width: maxX, height: maxY)
    }
    
    private func updateVisibility() {
        // Set visibility
        let renderFrame = CGRect(origin: .zero, size: context.renderSize)
        for i in 0 ..< context.runs.count {
            // Decide shown
            let isShown = renderFrame.contains(context.runs[i].frame)
            let nextIsShown: Bool
            if i < context.runs.count - 1 { nextIsShown = renderFrame.contains(context.runs[i + 1].frame) }
            else { nextIsShown = true }
            
            // Decide visibility
            if isShown && !nextIsShown {
                context.runs[i].visibility = .ellipsis
            }
            else {
                context.runs[i].visibility = isShown ? .visible : .invisible
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
        // Decide min x and max x
        var minX: CGFloat = .greatestFiniteMagnitude
        for i in (0 ..< context.runs.count).reversed() {
            guard context.runs[i].line == context.lineCount - 1 else { break }
            minX = min(minX, context.runs[i].frame.minX)
        }
        var maxX: CGFloat = 0
        for i in 0 ..< context.runs.count {
            guard context.runs[i].line == 0 else { break }
            maxX = max(maxX, context.runs[i].frame.maxX)
        }
        guard minX < .greatestFiniteMagnitude && maxX > .greatestFiniteMagnitude * -1 else { return }
        
        // Decide dx
        let dx: CGFloat
        switch context.directionAlign {
        case .start: dx = context.renderSize.width - maxX
        case .middle: dx = context.renderSize.width - context.adjustFontSize - (context.renderSize.width - (maxX - minX)) * 0.5
        case .end: dx = -minX
        }
        
        // Shift x
        for i in 0 ..< context.runs.count {
            context.runs[i].position.x += dx
            context.runs[i].frame = context.runs[i].frame.shift(dx: dx, dy: 0)
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
        let gap = (context.renderSize.height - total) / CGFloat(tokenCount)
        let diff = context.renderSize.height - total
        
        
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
            let diff = context.renderSize.height - total
            for i in runIdRange {
                context.runs[i].position.y += diff
                context.runs[i].frame = context.runs[i].frame.shift(dx: 0, dy: diff)
            }
        case .justify:
            // Check last run
            guard runIdRange.upperBound < context.runs.count else { return }
            guard !context.runs[runIdRange.upperBound - 1].char.isNewline else { break }
            
            // Align to justify
            var y = context.runs[runIdRange.lowerBound].position.y
            var prevTokeId = context.runs[runIdRange.lowerBound].tokenId
            for i in runIdRange {
                // Check token ID
                if context.runs[i].tokenId != prevTokeId {
                    prevTokeId = context.runs[i].tokenId
                    y += gap
                }
                
                // Shift y
                let dy = y - context.runs[i].position.y
                context.runs[i].position.y += dy
                context.runs[i].frame = context.runs[i].frame.shift(dx: 0, dy: dy)
                
                // For tate chu yoko
                if context.isTateChuYoko(run: context.runs[i]) {
                    // For last one
                    if context.runs[i].tokenRunIndex == 1 {
                        // Move y
                        y += context.runs[i].frame.height
                    }
                }
                // For other
                else {
                    // Move y
                    y += context.runs[i].frame.height
                }
            }
        }
    }
    
    private func alignTextTbRl() {
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
        for i in 0 ..< context.runs.count {
            minX = min(minX, context.runs[i].frame.minX)
            maxX = max(maxX, context.runs[i].frame.maxX)
            minY = min(minY, context.runs[i].frame.minY)
            maxY = max(maxY, context.runs[i].frame.maxY)
        }
        
        // Set rendered size
        if minX < .greatestFiniteMagnitude && maxX > 0 {
            context.renderedSize.width = maxX - minX
        }
        else {
            context.renderedSize.width = 0
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
            if context.runs[runId].char.isNewline {
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
