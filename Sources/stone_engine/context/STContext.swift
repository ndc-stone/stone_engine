/*
STContext.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(iOS)
import UIKit
#elseif os(macOS)
import Cocoa
#endif

open class STContext {
    public init() {
    }

    public static let cursorWide: CGFloat = 2

    // Runs
    public var runs = [STRun]()
    // Characters in run order. Held here rather than in STRun so that STRun stays
    // trivially copyable and the layout loop is free of ARC traffic.
    public var runChars = [Character]()
    public var tokens = [STToken]()

    /// The readings in the text, and what each is set over.
    ///
    /// Filled by the parser and read by the layout. Empty unless a reading was
    /// asked for — see `rubyNotation`, which says how one is written — and
    /// empty for every text that carries none, which is most of them
    public var rubies = [STRuby]()

    public var lineCount = 0

    // Font
    public let fontManager = STFontManager()
    
    // Layout
    public var fontSize: CGFloat = 17
    public var lineHeightScale: CGFloat = 1.0
    public var lineHeight: CGFloat { fontSize * lineHeightScale }
    public var lineGapHeight: CGFloat { fontSize * (lineHeightScale - 1) }
    public var textAlign: STTextAlign = .leading
    public var directionAlign: STDirectionAlign = .start
    public var direction: STDirection = .lrTb
    public var isAllowedTateChuYoko: Bool = true
    public var adjustsFontSizeToFitWidth: Bool = false
    public var minimumScaleFactor: CGFloat = 0
    public var isFixedWidth: Bool = false
    public var isSingleLine: Bool = false

    // Line count

    /// How many lines the text may be set on. Zero leaves it as many as it
    /// takes.
    ///
    /// The lines past the count are laid out as any others — the layout has
    /// to know where the text goes to know it has gone too far — and are
    /// then left undrawn and out of the size the text comes back as. A text
    /// held this way counts as truncated, so `adjustsFontSizeToFitWidth` sets
    /// it down until it fits the lines it is allowed, and only what still does
    /// not fit is lost
    public var maxLineCount: Int = 0

    /// Whether what is cut off is marked with an ellipsis.
    ///
    /// Off, the text simply stops where the room or the line count stops it.
    /// On, the last glyph still shown is set as the mark, so a reader can tell
    /// a text that goes on from one that ends there. It costs a glyph of what
    /// is shown, which is why it is asked for rather than always done
    public var isShownEllipsis: Bool = false

    /// Whether the line is one of those the text is allowed
    public func isShownLine(_ line: Int) -> Bool {
        // Check max line count
        guard maxLineCount > 0 else { return true }
        return line < maxLineCount
    }

    // Ruby

    /// How a reading is written into the text, where one is written at all.
    ///
    /// Nothing by default — see `STRubyNotation`. A text is then set exactly
    /// as it is given, and braces and 《》 are ordinary characters
    public var rubyNotation: STRubyNotation = .none

    /// How large a reading is set, against the text it is read from.
    ///
    /// Half, which is what a reading is set at nearly everywhere it is set at
    /// all: it has to be told apart from the word at a glance and still be
    /// read
    public var rubyFontScale: CGFloat = 0.5

    // Layout for adjusting
    public var adjustFontScale: CGFloat = 1.0
    public var adjustFontSize: CGFloat { fontSize * adjustFontScale }
    public var adjustLineHeight: CGFloat { adjustFontSize * lineHeightScale }

    // Color
    #if os(iOS)
    public var textColor: UIColor = .label
    public var selectedTextColor: UIColor = .label
    public var selectedAreaColor: UIColor = .link
    public var markedTextColor: UIColor = .label
    #elseif os(macOS)
    public var textColor: NSColor = .black // .label
    public var selectedTextColor: NSColor = .black // .label
    public var selectedAreaColor: NSColor = .blue // .link
    public var markedTextColor: NSColor = .black // .label
    #endif

    // Border. Stroked around the glyphs, outside the shape they already have,
    // so the text keeps its own weight and the border widens it from there.
    #if os(iOS)
    public var borderColor: UIColor = .clear
    #elseif os(macOS)
    public var borderColor: NSColor = .clear
    #endif
    public var borderWidth: CGFloat = 0

    // Features
    public var punctuationMode: STPunctuationMode = .stone
    public var isKinsokuAvailable = true
    public var isDividedByWords = true

    // Render
    public var renderSize: CGSize = .zero
    public var renderedSize: CGSize = .zero
    
    // Incremented every layout, to know whether runs have changed
    public var layoutVersion: Int = 0

    // Reveal. What a text that comes out a character at a time is drawn by —
    // see STReveal, which is where all of it but the keeping is written

    /// What is made of a character as it comes out. Nothing, unless something
    /// asks for otherwise, which is every text that simply stands there
    public var revealAnimation: STRevealAnimation = .none

    /// How many characters of the text have come out.
    ///
    /// All of them until something says fewer. A text is a thing to be read
    /// rather than a thing to be waited for, so one that is never told to
    /// come out a character at a time is drawn whole
    public var revealedCharacterCount: Int = .max {
        didSet {
            // Note when they arrived
            guard revealedCharacterCount != oldValue else { return }
            noteRevealed(from: oldValue)
        }
    }

    /// How long one character takes to come out
    public var revealDuration: TimeInterval = 0.2

    /// Which side a character comes in from, where it comes in from one —
    /// see `STRevealAnimation.flyIn`, which is the only one that asks
    public var revealOrigin: STRevealOrigin = .bottom

    /// Which character each run is drawn with — see `prepareReveal`, which
    /// fills this, and leaves it alone until the text is laid out again
    public internal(set) var revealIndexes = [Int]()

    /// How many characters there are to come out, the readings aside
    public internal(set) var revealCharacterCount = 0

    /// The place each run is coming to, which is what a character on its way
    /// is moved and sized against.
    ///
    /// Its own place, except for a reading: a reading is given the place of
    /// the word it is set over, so that the two move as one thing. Sized
    /// about its own, a reading would open out from its own middle and come
    /// away from the word underneath it
    public internal(set) var revealAnchors = [CGRect]()

    /// Which characters are on their way: those from here up to
    /// `revealedCharacterCount`
    public internal(set) var revealingFromCharacterIndex: Int = .max

    /// When they set out
    public internal(set) var revealingStartTime: TimeInterval = 0

    /// The layout `revealIndexes` was built from
    var revealIndexesVersion: Int = -1
    
    //--------------------------------------------------------------//
    // MARK: - Advance
    //--------------------------------------------------------------//
    
    public func advance(token: STToken) -> CGFloat {
        // Calc with runs
        return token.runIdRange.map({ runs[$0] }).reduce(0) { $0 + $1.advance.width }
    }
    
    //--------------------------------------------------------------//
    // MARK: - Token and run
    //--------------------------------------------------------------//
    
    public func isLastInToken(run: STRun) -> Bool {
        // Check token run index
        return run.tokenRunIndex >= tokens[run.tokenId].runIdRange.count - 1
    }
    
    public func runIndexes(line: Int) -> Range<Int>? {
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
        if lower == -1 {
            return runs.count ..< runs.count
        }
        else if upper == -1 {
            return lower ..< lower + 1
        }
        return lower ..< upper + 1
    }
    
    public func line(at runId: Int) -> Int {
        // Get line
        guard runs.count > 0 else { return 0 }
        if runId < runs.count - 1 { return runs[runId].line }
        else { return runs.last!.line }
    }
    
    public func isNewline(at runId: Int) -> Bool {
        // Check newline
        guard runs.count > 0 else { return false }
        if runId < runs.count - 1 { return runs[runId].isNewline }
        else { return runs.last!.isNewline }
    }
    
    public func tokenString(runId: Int) -> String? {
        // Get token string
        guard runs.indices.contains(runId) else { return nil }
        return tokenString(tokenId: runs[runId].tokenId)
    }
    
    public func tokenString(tokenId: Int) -> String? {
        // Get token string
        guard tokens.indices.contains(tokenId) else { return nil }
        return String(runChars[tokens[tokenId].runIdRange])
    }
    
    //--------------------------------------------------------------//
    // MARK: - Geometry
    //--------------------------------------------------------------//
    
    public func firstRunFrame(line: Int) -> CGRect {
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
    
    public func runFrameWithLineGap(at index: Int) -> CGRect {
        // For line 0
        if runs[index].line == 0 { return runs[index].frame }
        
        // Swtich by direction
        var runFrame: CGRect = .zero
        switch direction {
        case .lrTb:
            runFrame.origin.x = runs[index].frame.minX
            runFrame.origin.y = runs[index].frame.minY - lineGapHeight
            runFrame.size.width = runs[index].frame.width
            runFrame.size.height = runs[index].frame.height + lineGapHeight
        case .tbRl:
            runFrame.origin.x = runs[index].frame.minX
            runFrame.origin.y = runs[index].frame.minY
            runFrame.size.width = runs[index].frame.width + lineGapHeight
            runFrame.size.height = runs[index].frame.height
        }
        
        return runFrame
    }
    
    public func cursorFrame(at index: Int) -> CGRect {
        // Decide cursor frame
        var cursorFrame: CGRect = .zero
        switch direction {
        case .lrTb:
            // Cursor y and height are derived from lineHeight (per-line box), not from the
            // run's own font metrics. Otherwise the caret inherits the run font's ascent /
            // scale and, e.g., emoji runs (AppleColorEmoji has a larger ascent) would shift
            // the caret up relative to surrounding text. The run frame is only read for x.
            if runs.count == 0 {
                let runFrame = firstRunFrame(line: 0)
                cursorFrame.size.width = Self.cursorWide
                cursorFrame.size.height = fontSize
                cursorFrame.origin.x = runFrame.minX - cursorFrame.width * 0.5
                cursorFrame.origin.y = 0
            }
            else if index < runs.count {
                let runFrame = runs[index].frame
                let line = runs[index].line
                cursorFrame.size.width = Self.cursorWide
                cursorFrame.size.height = fontSize
                cursorFrame.origin.x = runFrame.minX - cursorFrame.width * 0.5
                cursorFrame.origin.y = CGFloat(line) * lineHeight
            }
            else {
                // For new line
                if isNewline(at: runs.count - 1) {
                    let line = runs[runs.count - 1].line + 1
                    let runFrame = firstRunFrame(line: line)
                    cursorFrame.size.width = Self.cursorWide
                    cursorFrame.size.height = fontSize
                    cursorFrame.origin.x = runFrame.maxX - cursorFrame.width * 0.5
                    cursorFrame.origin.y = CGFloat(line) * lineHeight
                }
                // For other
                else {
                    let runFrame = runs[runs.count - 1].frame
                    let line = runs[runs.count - 1].line
                    cursorFrame.size.width = Self.cursorWide
                    cursorFrame.size.height = fontSize
                    cursorFrame.origin.x = runFrame.maxX - cursorFrame.width * 0.5
                    cursorFrame.origin.y = CGFloat(line) * lineHeight
                }
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
                // For new line
                if isNewline(at: runs.count - 1) {
                    let runFrame = firstRunFrame(line: runs[runs.count - 1].line + 1)
                    cursorFrame.size.width = runFrame.width
                    cursorFrame.size.height = Self.cursorWide
                    cursorFrame.origin.x = runFrame.minX
                    cursorFrame.origin.y = runFrame.maxY - cursorFrame.height * 0.5
                }
                // For other
                else {
                    let runFrame = runs[runs.count - 1].frame
                    cursorFrame.size.width = runFrame.width
                    cursorFrame.size.height = Self.cursorWide
                    cursorFrame.origin.x = runFrame.minX
                    cursorFrame.origin.y = runFrame.maxY - cursorFrame.height * 0.5
                }
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
            guard i >= 0 && i < runs.count else { continue }
            guard runs[i].line != line else { continue }
            
            // Get first run frame
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
            // Get first run frame for last line
            let runFrame = firstRunFrame(line: lineCount - 1)
            
            // Check dy
            let dy = dy(from: runFrame, to: point)
            if dy < minDy {
                minDy = dy
                line = lineCount - 1
            }
        }
        
        // Decide closest run
        var minDistance: CGFloat = .greatestFiniteMagnitude
        var index = 0
        for i in range {
            // Check line
            guard i >= 0 && i < runs.count else { continue }
            // Stay on the closest line, so a click past a short line's end goes to
            // its end rather than to a nearer run on the line above or below
            guard runs[i].line == line else { continue }
            let runFrame = runs[i].frame
            
            // For new line
            if runs[i].isNewline {
                // Calc distance
                let d = distance(from: runFrame, to: point)
                if d < minDistance {
                    minDistance = d
                    index = i
                }
            }
            // For other
            else {
                // Calc dx for first half
                let firstHalfRect: CGRect = .init(x: runFrame.minX, y: runFrame.minY, width: runFrame.width * 0.5, height: runFrame.height)
                let fd = distance(from: firstHalfRect, to: point)
                if fd < minDistance {
                    minDistance = fd
                    index = i
                }
                
                // Calc dx for second half
                let secondHalfRect: CGRect = .init(x: runFrame.midX, y: runFrame.minY, width: runFrame.width * 0.5, height: runFrame.height)
                let sd = distance(from: secondHalfRect, to: point)
                if sd < minDistance {
                    minDistance = sd
                    index = i + 1
                }
            }
        }
        
        // For not found
        if minDistance == .greatestFiniteMagnitude {
            // Use last
            index = runs.count
        }
        
        return index
    }
    
    private func closestRunIndexV(to point: CGPoint, range: Range<Int>?) -> Int {
        // Decide range
        let isAll = range == nil
        let range = range ?? 0 ..< runs.count
        
        // Decide closest line
        var minDx: CGFloat = .greatestFiniteMagnitude
        var line = -1
        for i in range {
            // Check run
            guard i < runs.count else { break }
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
        if isAll, isNewline(at: range.upperBound), line < lineCount {
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
        var minDistance: CGFloat = .greatestFiniteMagnitude
        var index = 0
        for i in range {
            // Check run. Stay on the closest line, so a click past a short line's end
            // goes to its end rather than to a nearer run on the line beside it
            guard runs[i].line == line else { continue }
            let runFrame = runs[i].frame
            
            // For new line
            if runs[i].isNewline {
                // Calc distance
                let d = distance(from: runFrame, to: point)
                if d < minDistance {
                    minDistance = d
                    index = i
                }
            }
            // For other
            else {
                // Calc distance for first half
                let firstHalfRect: CGRect = .init(x: runFrame.minX, y: runFrame.minY, width: runFrame.width, height: runFrame.height * 0.5)
                let fd = distance(from: firstHalfRect, to: point)
                if fd < minDistance {
                    minDistance = fd
                    index = i
                }
                
                // Calc distance for second half
                let secondHalfRect: CGRect = .init(x: runFrame.minX, y: runFrame.midY, width: runFrame.width, height: runFrame.height * 0.5)
                let sd = distance(from: secondHalfRect, to: point)
                if sd < minDistance {
                    minDistance = sd
                    index = i + 1
                }
            }
        }
        
        // For not found
        if minDistance == .greatestFiniteMagnitude {
            // Use last
            index = runs.count
        }
        
        return index
    }
    
    public func closestRunIndex(to point: CGPoint, range: Range<Int>? = nil) -> Int {
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
    
    public func hitRunIndex(to point: CGPoint, range: Range<Int>? = nil) -> Int? {
        // Switch by direction
        switch direction {
        case .lrTb: return hitRunIndexH(to: point, range: range)
        case .tbRl: return hitRunIndexV(to: point, range: range)
        }
    }
    
    //--------------------------------------------------------------//
    // MARK: - Tate chu yoko
    //--------------------------------------------------------------//
    
    public func isTateChuYoko(token: STToken) -> Bool {
        // Check with first run
        guard let runId = token.runIdRange.first, runId < runs.count else { return false }
        return isTateChuYoko(run: runs[runId])
    }
    
    public func isTateChuYoko(run: STRun) -> Bool {
        // Check flag
        guard isAllowedTateChuYoko && !isFixedWidth else { return false }
        
        // Check script
        guard !fontManager.script(fontId: run.fontId).notNeedsToClockwiseInTbRl else { return false }
        
        // Check direction
        guard direction == .tbRl else { return false }
        
        // For number token
        if tokens[run.tokenId].runIdRange.map({ runs[$0] }).first(where: { !$0.flags.contains(.number) }) == nil {
            // Check token count
            return tokens[run.tokenId].runIdRange.count <= 2
        }
        
        return false
    }
    
    //--------------------------------------------------------------//
    // MARK: - Clockwise rotation
    //--------------------------------------------------------------//
    
    public func isClockwise(run: STRun) -> Bool {
        // Check direction
        guard direction == .tbRl else { return false }

        // The General Punctuation is set in the Japanese font, and on its side
        // (see STFontManager.isPunctuationSetInJapaneseFont)
        if STFontManager.isPunctuationSetInJapaneseFont(scalar: run.scalar),
           !run.isNewline,
           fontManager.script(fontId: run.fontId) == .japanese {
            return true
        }

        // Check script
        guard !fontManager.script(fontId: run.fontId).notNeedsToClockwiseInTbRl else { return false }
        
        // Check tate chu yoko
        return !isTateChuYoko(run: run)
    }
    
    //--------------------------------------------------------------//
    // MARK: - Adjust
    //--------------------------------------------------------------//
    
    public var isTruncated: Bool {
        // Check visibility
        for run in runs.reversed() {
            if run.visibility == .invisible || run.visibility == .ellipsis { return true }
        }
        
        return false
    }
}
