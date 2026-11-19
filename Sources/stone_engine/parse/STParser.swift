/*
STParser.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(iOS)
import UIKit
#elseif os(macOS)
import Cocoa
#endif

public class STParser {
    static let willParse = Notification.Name("STParserWillParse")
    static let didParse = Notification.Name("STParserDidParse")

    // Context
    let context: STContext

    // Run
    var runs = [STRun]()
    var tokens = [STToken]()

    // The readings found in the text, if any. Built as the runs are, so that
    // the ranges it holds are ranges of the runs handed to the context
    var rubies = [STRuby]()

    // Per-character working buffers, indexed in parallel with `chars`. Keeping the
    // whole document in flat arrays lets the CoreText calls be batched per font
    // across the document, instead of once per token.
    private var chars = [Character]()
    private var charFontIds = [Int]()
    private var charGlyphs = [CGGlyph]()
    private var charAdvances = [CGSize]()
    private var charBoundingRects = [CGRect]()
    private var charScalars = [UInt32]()

    // How large each character is set, against the size the text as a whole is
    // set at. One for ordinary text; a reading set over a word is half of it.
    // Measurements belong to the size they were taken at, so this is what the
    // metrics pass groups and keys by, beside the font
    private var charFontScales = [CGFloat]()
    private var tokenRanges = [Range<Int>]()

    // Sentinel stored in charScalars for characters made of more than one scalar.
    // Those need CoreText shaping and are never served from the metrics cache.
    private static let multiScalar = UInt32.max

    //--------------------------------------------------------------//
    // MARK: - Initialize
    //--------------------------------------------------------------//

    public init(context: STContext) {
        self.context = context
    }

    //--------------------------------------------------------------//
    // MARK: - Glyph metrics
    //--------------------------------------------------------------//

    private func composedGlyphMetrics(char: Character, baseFontId: Int, fontScale: CGFloat) -> (glyph: CGGlyph, advance: CGSize, boundingRect: CGRect, fontId: Int) {
        let size = context.adjustFontSize * fontScale
        let baseCTFont = context.fontManager.ctFont(fontId: baseFontId, size: size)

        // Shape the whole grapheme cluster through CoreText so OpenType ligatures apply
        // (e.g. a regional-indicator pair such as 🇯🇵 collapses into a single flag glyph).
        // CTFontGetGlyphsForCharacters would only cmap each scalar independently.
        let attrStr = NSAttributedString(string: String(char), attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): baseCTFont,
        ])
        let line = CTLineCreateWithAttributedString(attrStr as CFAttributedString)

        // A composed emoji collapses to a single glyph in the first glyph run
        let glyphRuns = CTLineGetGlyphRuns(line)
        guard CFArrayGetCount(glyphRuns) > 0 else {
            return (glyph: 0, advance: .zero, boundingRect: .zero, fontId: baseFontId)
        }
        let glyphRun = unsafeBitCast(CFArrayGetValueAtIndex(glyphRuns, 0), to: CTRun.self)
        guard CTRunGetGlyphCount(glyphRun) > 0 else {
            return (glyph: 0, advance: .zero, boundingRect: .zero, fontId: baseFontId)
        }

        // Take the first glyph
        var glyph: CGGlyph = 0
        CTRunGetGlyphs(glyphRun, CFRange(location: 0, length: 1), &glyph)

        // Resolve the font CoreText actually used for this run. When the first scalar is not
        // itself an emoji (keycap 1️⃣ / #️⃣, ❤️ …), CoreText substitutes the emoji font, so the
        // glyph index belongs to that substituted font rather than baseFontId. Map it back to a
        // fontId so STLabel later draws the glyph with the matching font instead of baseFontId
        // (otherwise the emoji glyph index is drawn against the wrong font and renders garbage).
        var resolvedFontId = baseFontId
        let attributes = CTRunGetAttributes(glyphRun) as NSDictionary
        if let fontAttribute = attributes[kCTFontAttributeName as String] {
            let runFont = fontAttribute as! CTFont
            let runFontName = CTFontCopyPostScriptName(runFont) as String
            if let mappedFontId = context.fontManager.fontId(fontName: runFontName) {
                resolvedFontId = mappedFontId
            }
        }

        // Measure advance and bounding rect with the resolved font at its draw-time scale so the
        // stored metrics match the font the glyph will actually be drawn with.
        let resolvedCTFont = context.fontManager.ctFont(fontId: resolvedFontId, size: size)
        var g = glyph
        var advance: CGSize = .zero
        var boundingRect: CGRect = .zero
        CTFontGetAdvancesForGlyphs(resolvedCTFont, .horizontal, &g, &advance, 1)
        CTFontGetBoundingRectsForGlyphs(resolvedCTFont, .horizontal, &g, &boundingRect, 1)

        return (glyph: glyph, advance: advance, boundingRect: boundingRect, fontId: resolvedFontId)
    }

    // Resolves glyph, advance and bounding rect for every character. Cached
    // characters are served directly; the rest are grouped by font and measured
    // with one set of CoreText calls per font, for the whole document.
    /// What a batch of characters is measured as: one font at one size.
    ///
    /// The size is in the key because a measurement belongs to the size it was
    /// taken at. Scaled text is rare and takes few sizes when it appears at
    /// all — a reading over a word is the one extra — so a document without
    /// any is still measured in one batch per font, as it was
    private struct MetricsBatchKey: Hashable {
        let fontId: Int
        let fontScaleInt: Int

        init(fontId: Int, fontScale: CGFloat) {
            self.fontId = fontId
            self.fontScaleInt = Int(fontScale * 1000)
        }
    }

    private func resolveGlyphMetrics() {
        let isVertical = context.direction == .tbRl
        let adjustFontSize = context.adjustFontSize
        let fontManager = context.fontManager

        // Collect the characters the cache cannot serve, grouped by font and
        // the size it is to be measured at
        var uncachedByFont = [MetricsBatchKey: [Int]]()
        for index in 0 ..< chars.count {
            let scalar = charScalars[index]
            let fontScale = charFontScales[index]

            // Multi-scalar characters need CoreText shaping and are not cached
            guard scalar != Self.multiScalar else {
                let metrics = composedGlyphMetrics(
                    char: chars[index], baseFontId: charFontIds[index], fontScale: fontScale
                )
                charGlyphs[index] = metrics.glyph
                charAdvances[index] = metrics.advance
                charBoundingRects[index] = metrics.boundingRect
                charFontIds[index] = metrics.fontId
                continue
            }

            let fontId = charFontIds[index]
            if let metrics = fontManager.cachedGlyphMetrics(
                fontId: fontId, size: adjustFontSize * fontScale, isVertical: isVertical, scalar: scalar
            ) {
                charGlyphs[index] = metrics.glyph
                charAdvances[index] = metrics.advance
                charBoundingRects[index] = metrics.boundingRect
            }
            else {
                uncachedByFont[
                    MetricsBatchKey(fontId: fontId, fontScale: fontScale), default: []
                ].append(index)
            }
        }

        // Measure the remaining characters, one batch per font and size
        for (batchKey, indices) in uncachedByFont {
            let fontId = batchKey.fontId
            let size = adjustFontSize * charFontScales[indices[0]]
            let ctFont = fontManager.ctFont(fontId: fontId, size: size)
            let count = indices.count

            // Resolve glyphs. Characters outside the BMP have to be looked up on
            // their own: when a surrogate pair is followed by another character in
            // the same buffer, CTFontGetGlyphsForCharacters fails and leaves the
            // entries after it at 0, which then draw as .notdef.
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var bmpUnits = [UniChar]()
            var bmpSlots = [Int]()
            bmpUnits.reserveCapacity(count)
            bmpSlots.reserveCapacity(count)

            for k in 0 ..< count {
                let value = charScalars[indices[k]]
                if value > 0xFFFF {
                    // Look the surrogate pair up by itself
                    let v = value - 0x10000
                    let pair: [UniChar] = [
                        UniChar(0xD800 + (v >> 10)),
                        UniChar(0xDC00 + (v & 0x3FF)),
                    ]
                    var pairGlyphs = [CGGlyph](repeating: 0, count: 2)
                    CTFontGetGlyphsForCharacters(ctFont, pair, &pairGlyphs, 2)
                    glyphs[k] = pairGlyphs[0]
                }
                else {
                    bmpUnits.append(UniChar(value))
                    bmpSlots.append(k)
                }
            }

            // BMP characters are one unit each, so they map to the glyph array one
            // to one and can still be resolved with a single call per font
            if !bmpUnits.isEmpty {
                var bmpGlyphs = [CGGlyph](repeating: 0, count: bmpUnits.count)
                CTFontGetGlyphsForCharacters(ctFont, bmpUnits, &bmpGlyphs, bmpUnits.count)
                for j in 0 ..< bmpSlots.count {
                    glyphs[bmpSlots[j]] = bmpGlyphs[j]
                }
            }

            // Measure before substituting vertical forms, so the metrics stay the
            // ones the horizontal glyph reported, as they were before
            var advances = [CGSize](repeating: .zero, count: count)
            var boundingRects = [CGRect](repeating: .zero, count: count)
            CTFontGetAdvancesForGlyphs(ctFont, .horizontal, &glyphs, &advances, count)
            CTFontGetBoundingRectsForGlyphs(ctFont, .horizontal, &glyphs, &boundingRects, count)

            // Substitute vertical forms for Japanese characters
            if isVertical {
                let fontName = fontManager.fontName(fontId: fontId)
                for k in 0 ..< count {
                    guard let scalar = Unicode.Scalar(charScalars[indices[k]]), scalar.script == .japanese else { continue }
                    let vertGlyph = STTextVerticalSubstitutionGlyphWithGlyph(fontName: fontName, glyph: glyphs[k])
                    if vertGlyph != 0 { glyphs[k] = vertGlyph }
                }
            }

            // Store back and cache
            for k in 0 ..< count {
                let index = indices[k]
                charGlyphs[index] = glyphs[k]
                charAdvances[index] = advances[k]
                charBoundingRects[index] = boundingRects[k]
                fontManager.setGlyphMetrics(
                    .init(glyph: glyphs[k], advance: advances[k], boundingRect: boundingRects[k]),
                    fontId: fontId, size: size, isVertical: isVertical, scalar: charScalars[index]
                )
            }
        }
    }

    //--------------------------------------------------------------//
    // MARK: - Tokenize
    //--------------------------------------------------------------//

    // Alphanumeric characters group into one token; everything else becomes a
    // token of its own.
    private func tokenizeStone() {
        var alnumStart = -1
        for index in 0 ..< chars.count {
            let char = chars[index]
            if char.isWhitespace || char.isNewline || !STIsAlnum(char: char) {
                // Flush the pending alphanumeric token
                if alnumStart >= 0 {
                    tokenRanges.append(alnumStart ..< index)
                    alnumStart = -1
                }

                // This character is a token on its own
                tokenRanges.append(index ..< index + 1)
            }
            else if alnumStart < 0 {
                alnumStart = index
            }
        }

        // Flush the last token
        if alnumStart >= 0 {
            tokenRanges.append(alnumStart ..< chars.count)
        }
    }

    // Walks the enumerated substrings and the character array in step, so the
    // substring boundaries become character index ranges without building strings.
    private func tokenizeByEnumeration(text: String) {
        var cursor = text.startIndex
        var charIndex = 0

        func emit(upTo target: String.Index) {
            let start = charIndex
            while cursor < target {
                cursor = text.index(after: cursor)
                charIndex += 1
            }
            if charIndex > start { tokenRanges.append(start ..< charIndex) }
        }

        let options: String.EnumerationOptions = context.isDividedByWords ? .byWords : .byComposedCharacterSequences
        text.enumerateSubstrings(in: text.startIndex ..< text.endIndex, options: options) { _, substringRange, _, _ in
            // Anything skipped before this substring is a token of its own
            emit(upTo: substringRange.lowerBound)
            emit(upTo: substringRange.upperBound)
        }

        // Trailing remainder
        emit(upTo: text.endIndex)
    }

    //--------------------------------------------------------------//
    // MARK: - Ruby
    //--------------------------------------------------------------//

    /// Makes one token of every word that is read, and one of every reading.
    ///
    /// A token is where a line may be broken. The tokenizer knows nothing of
    /// readings and would break a word in the middle of one, which would leave
    /// the reading set beside the half of the word it belongs over.
    ///
    /// Done by rebuilding rather than by joining: a token may begin inside a
    /// word and end outside it — words are tokenized by word where the mode
    /// asks for it — so the edges are taken from both and the inside of a
    /// word or a reading is left without any
    private func mergeRubyTokens(_ rubyRanges: [STRubyCharRanges]) {
        // Most texts carry no reading
        guard !rubyRanges.isEmpty else { return }

        let charCount = chars.count
        guard charCount > 0 else { return }

        // Every place a token may begin
        var isBoundary = [Bool](repeating: false, count: charCount + 1)
        isBoundary[0] = true
        isBoundary[charCount] = true
        for range in tokenRanges {
            isBoundary[range.lowerBound] = true
            isBoundary[range.upperBound] = true
        }

        // The edges of a word and of its reading are places a token begins;
        // anywhere inside either of them is not
        var isInside = [Bool](repeating: false, count: charCount + 1)
        for ruby in rubyRanges {
            for range in [ruby.baseRange, ruby.readingRange] {
                guard !range.isEmpty else { continue }
                isBoundary[range.lowerBound] = true
                isBoundary[range.upperBound] = true
                for index in (range.lowerBound + 1) ..< range.upperBound {
                    isInside[index] = true
                }
            }
        }
        for index in 0 ... charCount where isInside[index] {
            isBoundary[index] = false
        }

        // Rebuild the tokens from the places that are left
        tokenRanges.removeAll(keepingCapacity: true)
        var start = 0
        for index in 1 ... charCount where isBoundary[index] {
            tokenRanges.append(start ..< index)
            start = index
        }
    }

    //--------------------------------------------------------------//
    // MARK: - Parse
    //--------------------------------------------------------------//

    public func parse(text: String?) {
        // Notify it
        NotificationCenter.default.post(name: Self.willParse, object: self)

        // Take the readings out of the text, where any are written in it.
        // What is set is what is left; where each reading goes is kept beside
        // it, counted in the characters of that
        let scan = STRubyScanner.scan(
            text: text ?? "",
            notation: context.rubyNotation,
            readingFontScale: context.rubyFontScale
        )
        let text = scan.text

        // Materialize the characters once. Every later pass indexes this array
        // instead of walking the string again.
        chars.removeAll(keepingCapacity: true)
        chars.append(contentsOf: text)
        let charCount = chars.count

        // Prepare the parallel buffers
        charFontIds = .init(repeating: 0, count: charCount)
        charGlyphs = .init(repeating: 0, count: charCount)
        charAdvances = .init(repeating: .zero, count: charCount)
        charBoundingRects = .init(repeating: .zero, count: charCount)
        charScalars = .init(repeating: 0, count: charCount)
        charFontScales = scan.fontScales.count == charCount
            ? scan.fontScales
            : .init(repeating: 1, count: charCount)

        tokenRanges.removeAll(keepingCapacity: true)
        runs.removeAll(keepingCapacity: true)
        tokens.removeAll(keepingCapacity: true)
        rubies.removeAll(keepingCapacity: true)
        runs.reserveCapacity(charCount)

        // Resolve the font of every character. A newline inherits the font of the
        // character before it, matching the order runs used to be appended in.
        var prevFontId = 0
        for index in 0 ..< charCount {
            let char = chars[index]

            // Record the scalar used as the glyph cache key
            var scalars = char.unicodeScalars.makeIterator()
            if let first = scalars.next(), scalars.next() == nil {
                charScalars[index] = first.value
            }
            else {
                charScalars[index] = Self.multiScalar
            }

            // Decide the font
            if char.isNewline {
                charFontIds[index] = prevFontId
            }
            else {
                charFontIds[index] = context.fontManager.fontId(char: char)
                prevFontId = charFontIds[index]
            }
        }

        // Resolve glyphs and metrics
        resolveGlyphMetrics()

        // Tokenize
        if context.punctuationMode == .stone {
            tokenizeStone()
        }
        else {
            tokenizeByEnumeration(text: text)
        }

        // Hold each reading, and the word it is read from, together
        mergeRubyTokens(scan.rubies)

        // Say where the readings are. A character becomes one run and they are
        // built in order, so a run is numbered as its character was
        rubies = scan.rubies.map {
            STRuby(rbcRunIdRange: $0.baseRange, rtcRunIdRange: $0.readingRange)
        }

        // Say which characters are a reading's. A character becomes one run,
        // so this stands for the runs as well
        var isRubyTextChar = [Bool](repeating: false, count: charCount)
        for ruby in rubies {
            for index in ruby.rtcRunIdRange where index < charCount {
                isRubyTextChar[index] = true
            }
        }

        // Build runs, tokens and the characters in run order
        var runChars = [Character]()
        runChars.reserveCapacity(charCount)
        for (tokenId, range) in tokenRanges.enumerated() {
            let runId = runs.count
            var tokenRunIndex = 0
            for index in range {
                let char = chars[index]
                runChars.append(char)

                // Resolve every classification the layout needs, once
                var flags = STRunFlags()
                let isNewline = char.isNewline
                if isNewline { flags.insert(.newline) }
                if char.isNumber { flags.insert(.number) }
                if let scalar = char.unicodeScalars.first {
                    if STKinsoku.notEndingCharSet.contains(scalar) { flags.insert(.notEnding) }
                    if STKinsoku.notStartingCharSet.contains(scalar) { flags.insert(.notStarting) }
                    if STKinsoku.hangingCharSet.contains(scalar) { flags.insert(.hanging) }
                }
                if isRubyTextChar[index] { flags.insert(.rubyText) }

                runs.append(STRun(
                    tokenId: tokenId,
                    tokenRunIndex: tokenRunIndex,
                    fontId: charFontIds[index],
                    fontScale: charFontScales[index],
                    scalar: char.unicodeScalars.first?.value ?? 0,
                    flags: flags,
                    punctuation: STPunctuation.valueOf(charatcter: char),
                    glyph: charGlyphs[index],
                    advance: isNewline ? .zero : charAdvances[index],
                    boundingRect: charBoundingRects[index],
                    position: .zero,
                    frame: .zero,
                    visibility: .visible,
                    line: 0
                ))
                tokenRunIndex += 1
            }
            tokens.append(STToken(runIdRange: runId ..< runs.count))
        }

        // Set runs. The characters are kept in run order so callers that need the
        // text can still get it without STRun carrying a Character.
        context.runs = runs
        context.runChars = runChars
        context.tokens = tokens
        context.rubies = rubies
        context.lineCount = 0

        // Drop our own references, so the context owns the arrays uniquely and the
        // layout can mutate the runs in place without triggering a copy
        runs = []
        tokens = []
        rubies = []

        // Release the working buffers
        chars.removeAll(keepingCapacity: false)
        charFontIds.removeAll(keepingCapacity: false)
        charGlyphs.removeAll(keepingCapacity: false)
        charAdvances.removeAll(keepingCapacity: false)
        charBoundingRects.removeAll(keepingCapacity: false)
        charScalars.removeAll(keepingCapacity: false)
        charFontScales.removeAll(keepingCapacity: false)
        tokenRanges.removeAll(keepingCapacity: false)

        // Notify it
        NotificationCenter.default.post(name: Self.didParse, object: self)
    }
}

public func STIsAlnum(char: Character) -> Bool {
    // Check char
    /*
    guard char.unicodeScalars.count == 1, let unicodeScalar = char.unicodeScalars.first else { return false }
    return CharacterSet.alphanumerics.contains(unicodeScalar)
    */
    if char.utf16.count == 1, let uc = char.utf16.first, uc < 0x052f { return true }
    else { return false }
}
