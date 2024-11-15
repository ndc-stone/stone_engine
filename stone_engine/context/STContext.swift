/*
STContext.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center. All rights reserved.
This software is licensed under the MIT License. See LICENSE for details.
*/

import UIKit

class STContext {
    static let cursorWide: CGFloat = 2
    
    // Runs
    var runs = [STRun]()
    var tokens = [STToken]()
    var lineCount = 0
    
    // Font
    let fontManager = STFontManager()
    
    // Layout
    var fontSize: CGFloat = 17
    var lineHeightScale: CGFloat = 1.0
    var lineHeight: CGFloat { fontSize * lineHeightScale }
    var textAlign: STTextAlign = .leading
    var directionAlign: STDirectionAlign = .start
    var direction: STDirection = .lrTb
    var isAllowedTateChuYoko: Bool = true
    var adjustsFontSizeToFitWidth: Bool = false
    var minimumScaleFactor: CGFloat = 0
    
    // Layout for adjusting
    var adjustFontScale: CGFloat = 1.0
    var adjustFontSize: CGFloat { fontSize * adjustFontScale }
    var adjustLineHeight: CGFloat { adjustFontSize * lineHeightScale }
    
    // Color
    var textColor: UIColor = .label
    
    // Features
    var punctuationMode: STPunctuationMode = .stone
    //var isHalfPunctuation = true
    var isKinsokuAvailable = true
    var isDividedByWords = true
    
    // Render
    var renderSize: CGSize = .zero
    var renderedSize: CGSize = .zero
}

extension STContext {
    //--------------------------------------------------------------//
    // MARK: - Advance
    //--------------------------------------------------------------//
    
    func advance(token: STToken) -> CGFloat {
        // Calc with runs
        return token.runIdRange.map({ runs[$0] }).reduce(0) { $0 + $1.advance.width }
    }
    
    //--------------------------------------------------------------//
    // MARK: - Token and run
    //--------------------------------------------------------------//
    
    func isLastInToken(run: STRun) -> Bool {
        // Check token run index
        return run.tokenRunIndex >= tokens[run.tokenId].runIdRange.count - 1
    }
    
    func runIndexes(line: Int) -> Range<Int>? {
        // Find runs at line
        var lower: Int = -1
        var upper: Int = -1
        for (index, run) in runs.enumerated() {
            // For found
            if run.line == line {
                if lower == -1 { lower = index }
                upper = index
            }
            // For over
            else if run.line > line {
                break
            }
        }
        
        // Create range
        guard lower != -1 || upper == -1 else { return nil }
        return lower ..< upper + 1
    }
    
    func line(at runId: Int) -> Int {
        // Get line
        guard runs.count > 0 else { return 0 }
        if runId < runs.count - 1 { return runs[runId].line }
        else { return runs.last!.line }
    }
    
    func isNewline(at runId: Int) -> Bool {
        // Check newline
        guard runs.count > 0 else { return false }
        if runId < runs.count - 1 { return runs[runId].char.isNewline }
        else { return runs.last!.char.isNewline }
    }
    
    func tokenString(runId: Int) -> String? {
        // Get token string
        guard runId < runs.count - 1 else { return nil }
        return tokenString(tokenId: runs[runId].tokenId)
    }
    
    func tokenString(tokenId: Int) -> String? {
        // Get token string
        guard tokenId < tokens.count - 1 else { return nil }
        return tokens[tokenId].runIdRange.reduce("") { "\($0!)\(runs[$1].char)" }
    }
    
    //--------------------------------------------------------------//
    // MARK: - Geometry
    //--------------------------------------------------------------//
    
    func firstRunFrame(line: Int) -> CGRect {
        // Decide run rect
        var rect: CGRect = .zero
        switch direction {
        case .lrTb:
            rect.size.width = 0
            rect.size.height = fontSize
            rect.origin.x = 0
            rect.origin.y = CGFloat(line) * lineHeight
        case .tbRl:
            rect.size.width = fontSize
            rect.size.height = 0
            rect.origin.x = renderedSize.width - (CGFloat(line) * lineHeight) - rect.width
            rect.origin.y = 0
        }
        
        return rect
    }
    
    func cursorFrame(at index: Int) -> CGRect {
        // Decide cursor frame
        var cursorFrame: CGRect = .zero
        switch direction {
        case .lrTb:
            if runs.count == 0 {
                let runFrame = firstRunFrame(line: 0)
                cursorFrame.size.width = Self.cursorWide
                cursorFrame.size.height = runFrame.height
                cursorFrame.origin.x = runFrame.minX - cursorFrame.width * 0.5
                cursorFrame.origin.y = runFrame.minY
            }
            else if index < runs.count {
                let runFrame = runs[index].frame
                cursorFrame.size.width = Self.cursorWide
                cursorFrame.size.height = runFrame.height
                cursorFrame.origin.x = runFrame.minX - cursorFrame.width * 0.5
                cursorFrame.origin.y = runFrame.minY
            }
            else {
                let runFrame = runs[runs.count - 1].frame
                cursorFrame.size.width = Self.cursorWide
                cursorFrame.size.height = runFrame.height
                cursorFrame.origin.x = runFrame.maxX - cursorFrame.width * 0.5
                cursorFrame.origin.y = runFrame.minY
            }
        case .tbRl:
            if runs.count == 0 {
                let runFrame = firstRunFrame(line: 0)
                cursorFrame.size.width = runFrame.width
                cursorFrame.size.height = Self.cursorWide
                cursorFrame.origin.x = runFrame.minX
                cursorFrame.origin.y = runFrame.minY - cursorFrame.height * 0.5
            }
            else if index < runs.count {
                let runFrame = runs[index].frame
                
                // For tate chu yoko
                if isTateChuYoko(run: runs[index]) {
                    cursorFrame.size.width = Self.cursorWide
                    cursorFrame.size.height = runFrame.height
                    cursorFrame.origin.x = runFrame.minX - cursorFrame.width * 0.5
                    cursorFrame.origin.y = runFrame.minY
                }
                // For other
                else {
                    cursorFrame.size.width = runFrame.width
                    cursorFrame.size.height = Self.cursorWide
                    cursorFrame.origin.x = runFrame.minX
                    cursorFrame.origin.y = runFrame.minY - cursorFrame.height * 0.5
                }
            }
            else {
                let runFrame = runs[runs.count - 1].frame
                cursorFrame.size.width = runFrame.width
                cursorFrame.size.height = Self.cursorWide
                cursorFrame.origin.x = runFrame.minX
                cursorFrame.origin.y = runFrame.maxY - cursorFrame.height * 0.5
            }
        }
        
        return cursorFrame
    }
    
    private func dx(from rect: CGRect, to point: CGPoint) -> CGFloat {
        // Calc distance X
        let dx = point.x - rect.midX
        return sqrt(dx * dx)
    }
    
    private func dy(from rect: CGRect, to point: CGPoint) -> CGFloat {
        // Calc distance Y
        let dy = point.y - rect.midY
        return sqrt(dy * dy)
    }
    
    private func distance(from rect: CGRect, to point: CGPoint) -> CGFloat {
        // Calc distance
        let dx = point.x - rect.midX
        let dy = point.y - rect.midY
        return sqrt(dx * dx + dy * dy)
    }
    
    private func closestRunIndexH(to point: CGPoint, range: Range<Int>?) -> Int {
        // Decide range
        let isAll = range == nil
        let range = range ?? 0 ..< runs.count
        
        // Decide closest line
        var minDy: CGFloat = .greatestFiniteMagnitude
        var line = -1
        for i in range {
            // Check run
            guard runs[i].line != line else { continue }
            
            // Get first run rect
            let runFrame = firstRunFrame(line: runs[i].line)
            
            // Check dy
            let dy = dy(from: runFrame, to: point)
            guard dy < minDy else { continue }
            minDy = dy
            line = runs[i].line
        }
        if line == -1 { line = 0 }
        
        // Check last new line
        if isAll, isNewline(at: range.upperBound), line < lineCount {
            // Get first run rect for last line
            let runRect = firstRunFrame(line: lineCount - 1)
            
            // Check dy
            let dy = dy(from: runRect, to: point)
            if dy < minDy {
                minDy = dy
                line = lineCount - 1
            }
        }
        
        // Decide closest run
        var minDx: CGFloat = .greatestFiniteMagnitude
        var index = 0
        for i in range {
            // Check line
            guard runs[i].line == line else { continue }
            let runFrame = runs[i].frame
            
            // For new line
            if runs[i].char.isNewline {
                // Calc dx
                let dx = dx(from: runFrame, to: point)
                if dx < minDx {
                    minDx = dx
                    index = i
                }
            }
            // For other
            else {
                // Calc dx for first half
                let firstHalfRect: CGRect = .init(x: runFrame.minX, y: runFrame.minY, width: runFrame.width * 0.5, height: runFrame.height)
                let fdx = dx(from: firstHalfRect, to: point)
                if fdx < minDx {
                    minDx = fdx
                    index = i
                }
                
                // Calc dx for second half
                let secondHalfRect: CGRect = .init(x: runFrame.midX, y: runFrame.minY, width: runFrame.width * 0.5, height: runFrame.height)
                let sdx = dx(from: secondHalfRect, to: point)
                if sdx < minDx {
                    minDx = sdx
                    index = i + 1
                }
            }
        }
        
        // For not found
        if minDx == .greatestFiniteMagnitude {
            // Use last
            index = runs.count
        }
        
        return index
    }
    
    private func closestRunIndexV(to point: CGPoint, range: Range<Int>?) -> Int {
        // Decide range
        let isAll = range == nil
        let range = range ?? 0 ..< runs.count - 1
        
        // Decide closest line
        var minDx: CGFloat = .greatestFiniteMagnitude
        var line = -1
        for i in range {
            // Check run
            guard runs[i].line != line else { continue }
            
            // Get first run frame
            let runFrame = firstRunFrame(line: runs[i].line)
            
            // Check dx
            let dx = dx(from: runFrame, to: point)
            guard dx < minDx else { continue }
            minDx = dx
            line = runs[i].line
        }
        if line == -1 { line = 0 }
        
        // Check last new line
        if isAll, runs[range.upperBound].char.isNewline, line < lineCount {
            // Get first run rect for last line
            let runFrame = firstRunFrame(line: lineCount - 1)
            
            // Check dx
            let dx = dx(from: runFrame, to: point)
            if dx < minDx {
                minDx = dx
                line = lineCount - 1
            }
        }
        
        // Decide closest run
        var minDy: CGFloat = .greatestFiniteMagnitude
        var index = 0
        for i in range {
            // Check run
            guard runs[i].line == line else { continue }
            let runFrame = runs[i].frame
            
            // For new line
            if runs[i].char.isNewline {
                // Calc dy
                let dy = dy(from: runFrame, to: point)
                if dy < minDy {
                    minDy = dy
                    index = i
                }
            }
            // For other
            else {
                // Calc dy for first half
                let firstHalfRect: CGRect = .init(x: runFrame.minX, y: runFrame.minY, width: runFrame.width, height: runFrame.height * 0.5)
                let fdy = dy(from: firstHalfRect, to: point)
                if fdy < minDy {
                    minDy = fdy
                    index = i
                }
                
                // Calc dy for second half
                let secondHalfRect: CGRect = .init(x: runFrame.minX, y: runFrame.midY, width: runFrame.width, height: runFrame.height * 0.5)
                let sdy = dy(from: secondHalfRect, to: point)
                if sdy < minDy {
                    minDy = sdy
                    index = i + 1
                }
            }
        }
        
        // For not found
        if minDy == .greatestFiniteMagnitude {
            // Use last
            index = runs.count
        }
        
        return index
    }
    
    func closestRunIndex(to point: CGPoint, range: Range<Int>? = nil) -> Int {
        // Check run count
        guard runs.count > 0 else { return 0 }
        
        // Switch by direction
        switch direction {
        case .lrTb: return closestRunIndexH(to: point, range: range)
        case .tbRl: return closestRunIndexV(to: point, range: range)
        }
    }
    
    private func hitRunIndexH(to point: CGPoint, range: Range<Int>?) -> Int? {
        // Decide range
        let range = range ?? 0 ..< runs.count
        
        // Decide hit run
        if runs.count == 0 {
            var runFrame = firstRunFrame(line: 0)
            runFrame.size.width = 8
            runFrame.origin.x -= runFrame.width * 0.5
            return runFrame.contains(point) ? 0 : nil
        }
        else {
            for i in range {
                // Check run frame
                let runFrame = runs[i].frame
                if runFrame.contains(point) { return i }
            }
        }
        
        return nil
    }
    
    private func hitRunIndexV(to point: CGPoint, range: Range<Int>?) -> Int? {
        // Decide range
        let range = range ?? 0 ..< runs.count
        
        // Decide hit run
        for i in range {
            // Check run frame
            let runFrame = runs[i].frame
            if runFrame.contains(point) { return i }
        }
        
        return nil
    }
    
    func hitRunIndex(to point: CGPoint, range: Range<Int>? = nil) -> Int? {
        // Switch by direction
        switch direction {
        case .lrTb: return hitRunIndexH(to: point, range: range)
        case .tbRl: return hitRunIndexV(to: point, range: range)
        }
    }
    
    //--------------------------------------------------------------//
    // MARK: - Tate chu yoko
    //--------------------------------------------------------------//
    
    func isTateChuYoko(token: STToken) -> Bool {
        // Check with first run
        guard let runId = token.runIdRange.first, runId < runs.count else { return false }
        return isTateChuYoko(run: runs[runId])
    }
    
    func isTateChuYoko(run: STRun) -> Bool {
        // Check flag
        guard isAllowedTateChuYoko else { return false }
        
        // Check script
        guard !fontManager.script(fontId: run.fontId).notNeedsToClockwiseInTbRl else { return false }
        
        // Check direction
        guard direction == .tbRl else { return false }
        
        // For number token
        if tokens[run.tokenId].runIdRange.map({ runs[$0] }).first(where: { !$0.char.isNumber }) == nil {
            // Check token count
            return tokens[run.tokenId].runIdRange.count <= 2
        }
        // For letter token
        else if tokens[run.tokenId].runIdRange.map({ runs[$0] }).first(where: { !$0.char.isLetter }) == nil {
            // Check token count
            return tokens[run.tokenId].runIdRange.count <= 1
        }
        
        return false
    }
    
    //--------------------------------------------------------------//
    // MARK: - Clockwise rotation
    //--------------------------------------------------------------//
    
    func isClockwise(run: STRun) -> Bool {
        // Check script
        guard !fontManager.script(fontId: run.fontId).notNeedsToClockwiseInTbRl else { return false }
        
        // Check direction
        guard direction == .tbRl else { return false }
        
        // Check tate chu yoko
        return !isTateChuYoko(run: run)
    }
    
    //--------------------------------------------------------------//
    // MARK: - Adjust
    //--------------------------------------------------------------//
    
    var isTruncated: Bool {
        // Check visibility
        for run in runs.reversed() {
            if run.visibility == .invisible || run.visibility == .ellipsis { return true }
        }
        
        return false
    }
}
