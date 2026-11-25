/*
STFontManager.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

#if os(iOS)
import UIKit
#elseif os(macOS)
import Cocoa
#endif

open class STFontManager {
    public init() {
    }

    public static let fontNamesNeedToFlip = [
        "AppleColorEmoji", 
    ]
    
    // Font name
    private let defaultFontName = "HelveticaNeue"
    private var scriptFontNames: [STScript: [String]] = [
        .latin: ["HelveticaNeue"], 
        .japanese: ["HiraginoSans-W3"],
        .emoji: ["AppleColorEmoji", "ArialUnicodeMS", "MS-Gothic", "Menlo-Regular"],  
    ]
    private var possibleFontNames = [String]()
    private var possibleScripts = [STScript]()
    
    // Font scale. An emoji glyph fills its whole em box, where a Japanese glyph
    // only inks about 83% of it, so emoji set at the text size touch each other
    // while the text around them breathes. 0.85 gives emoji the same gap between
    // neighbours as the Japanese text they sit in.
    private var scriptFontScales: [STScript: CGFloat] = [
        .latin: 0.95,
        .japanese: 1.0,
        .emoji: 0.85,
    ]
    
    // MARK: - Optimized Font Cache with Struct Keys
    struct FontCacheKey: Hashable {
        let fontId: Int
        let sizeInt: Int  // size * 100 for precision
        let isClockwise: Bool
        
        init(fontId: Int, size: CGFloat, isClockwise: Bool) {
            self.fontId = fontId
            self.sizeInt = Int(size * 100)
            self.isClockwise = isClockwise
        }
        
        // Optimized hash function for better performance
        func hash(into hasher: inout Hasher) {
            hasher.combine(fontId)
            hasher.combine(sizeInt)
            hasher.combine(isClockwise)
        }
        
        // Optimized equality check
        static func == (lhs: FontCacheKey, rhs: FontCacheKey) -> Bool {
            return lhs.fontId == rhs.fontId && 
                   lhs.sizeInt == rhs.sizeInt && 
                   lhs.isClockwise == rhs.isClockwise
        }
    }
    
    // MARK: - Glyph metrics cache
    public struct GlyphMetrics {
        public let glyph: CGGlyph
        public let advance: CGSize
        public let boundingRect: CGRect
    }
    // Keyed by Unicode scalar rather than Character: hashing a Character normalizes
    // the grapheme, which is far more expensive, and only single-scalar characters
    // are ever cached (composed ones are shaped by CoreText and never stored).
    struct GlyphMetricsKey: Hashable {
        let fontId: Int
        let sizeInt: Int  // size * 100 for precision
        let isVertical: Bool
        let scalar: UInt32

        init(fontId: Int, size: CGFloat, isVertical: Bool, scalar: UInt32) {
            self.fontId = fontId
            self.sizeInt = Int(size * 100)
            self.isVertical = isVertical
            self.scalar = scalar
        }
    }

    // Whether a single glyph of a flipping font is drawn from a colour bitmap
    struct GlyphFlipKey: Hashable {
        let fontId: Int
        let glyph: CGGlyph
    }

    // Caches (per-instance: fontId is an index into this instance's possibleFontNames)
    private var charToFontId = [Character: Int]()
    private var fontCache = [FontCacheKey: CTFont]()
    private var glyphMetricsCache = [GlyphMetricsKey: GlyphMetrics]()
    private var glyphFlipCache = [GlyphFlipKey: Bool]()

    // Signature of the font configuration the caches were built for
    private var cacheConfigSignature: String = ""

    // Bumped every time refresh() sees a different font configuration.
    //
    // Glyphs and advances belong to the fonts they were resolved with, so a
    // parse is only valid for one configuration. Callers that cache a parse
    // compare this against the version they parsed at, and parse again when it
    // moved (see STLabel.performParseAndLayout).
    public private(set) var configurationVersion: Int = 0
}

extension STFontManager {
    //--------------------------------------------------------------//
    // MARK: - Font
    //--------------------------------------------------------------//
    
    // A variation selector 16 asks for colour emoji presentation whatever block
    // the character it follows belongs to
    private static let variationSelector16: UInt32 = 0xfe0f

    // The punctuation of the General Punctuation block (U+2000-206F): '…',
    // '‥', '―', '“' and so on. No script claims it, so it would be set in the
    // first font that has it, a Latin one. A Latin '…' is small and sits on
    // the baseline, and on its side in vertical text its dots run down the
    // left of the line; its advance is not always a full em either, so the
    // characters after it come off the manuscript grid. It is set in the
    // Japanese font instead, as stone 1.2 did for everything past Latin-1:
    // the Japanese '…' sits in the middle of the em, across and, on its side,
    // down. Vertical text turns it on its side rather than substituting a
    // vertical form (see STContext.isClockwise(run:)), as 1.2 did too.
    public static func isPunctuationSetInJapaneseFont(scalar: UInt32) -> Bool {
        return (0x2000 ... 0x206f).contains(scalar)
    }

    func fontId(char: Character) -> Int {
        // Check cache
        if let fontId = charToFontId[char] {
            return fontId
        }

        // Look the base scalar up on its own. The modifiers of a composed
        // character (variation selector, skin tone, ZWJ) are not covered by any
        // single font, and STParser shapes the composed glyph through CoreText
        // afterwards anyway.
        guard let baseScalar = char.unicodeScalars.first else { return 0 }

        // Get script
        var script = baseScalar.script
        if char.unicodeScalars.contains(where: { $0.value == Self.variationSelector16 }) {
            script = .emoji
        }

        // Set the General Punctuation in the Japanese font
        if script == nil, Self.isPunctuationSetInJapaneseFont(scalar: baseScalar.value) {
            script = .japanese
        }

        // Decide font ID and cache it
        let fontId = fontId(scalar: baseScalar, script: script)
        charToFontId[char] = fontId

        return fontId
    }

    private func fontId(scalar: Unicode.Scalar, script: STScript?) -> Int {
        // Decide font ID. The script's own fonts come first, then every other
        // font: a character can belong to a script and still be missing from
        // its fonts (an emoji sitting in the Dingbats or Miscellaneous
        // Technical block, say), and drawing it with the default font would
        // only produce .notdef, so any font that has the glyph is preferable.
        let chars = uniChars(string: String(scalar))
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        for fontId in fontIdSearchOrder(script: script) {
            let ctFont = CTFontCreateWithName(possibleFontNames[fontId] as CFString, 17, nil)
            if CTFontGetGlyphsForCharacters(ctFont, chars, &glyphs, chars.count), glyphs[0] > 0 {
                return fontId
            }
        }

        // Use default font ID
        return 0
    }

    private func fontIdSearchOrder(script: STScript?) -> [Int] {
        // List the script's own font IDs first, the remaining ones after
        var fontIds = [Int]()
        fontIds.reserveCapacity(possibleScripts.count)
        for fontId in 0 ..< possibleScripts.count where possibleScripts[fontId] == script {
            fontIds.append(fontId)
        }
        for fontId in 0 ..< possibleScripts.count where possibleScripts[fontId] != script {
            fontIds.append(fontId)
        }

        return fontIds
    }

    func fontId(fontName: String) -> Int? {
        // Map a font name to its font ID (index into possibleFontNames)
        return possibleFontNames.firstIndex(of: fontName)
    }

    public func ctFont(fontId: Int, size: CGFloat, isClockwise: Bool = false) -> CTFont {
        // Decide font size
        let script = possibleScripts[fontId]
        let fontScale = scriptFontScales[script]!
        let size = size * fontScale
        
        // Get from cache
        let cacheKey = FontCacheKey(fontId: fontId, size: size, isClockwise: isClockwise)
        if let cachedFont = fontCache[cacheKey] {
            return cachedFont
        }
        
        // Get font name
        let fontName = possibleFontNames[fontId]
        
        // Decide transform
        var transform: CGAffineTransform = .identity
        transform = transform.scaledBy(x: 1, y: -1)
        if isClockwise {
            transform = transform.rotated(by: .pi * -0.5)
        }
        
        // Create font and cache it with struct key
        let font = CTFontCreateWithName(fontName as CFString, size, &transform)
        fontCache[cacheKey] = font
        
        return font
    }
    
    //--------------------------------------------------------------//
    // MARK: - Glyph metrics cache
    //--------------------------------------------------------------//

    func cachedGlyphMetrics(fontId: Int, size: CGFloat, isVertical: Bool, scalar: UInt32) -> GlyphMetrics? {
        return glyphMetricsCache[GlyphMetricsKey(fontId: fontId, size: size, isVertical: isVertical, scalar: scalar)]
    }

    func setGlyphMetrics(_ metrics: GlyphMetrics, fontId: Int, size: CGFloat, isVertical: Bool, scalar: UInt32) {
        glyphMetricsCache[GlyphMetricsKey(fontId: fontId, size: size, isVertical: isVertical, scalar: scalar)] = metrics
    }

    // The ascent a line's em box is measured from.
    //
    // Runs on a line share a baseline, but each one's frame is its own font's
    // ascent above it, and fonts do not agree. A run that has to be fitted to the
    // line rather than to its own font - a colour emoji, whose ascent reaches far
    // above the baseline - is placed against this instead, so it lands on the same
    // box as the text it sits in.
    func primaryAscent(size: CGFloat) -> CGFloat {
        guard let fontName = scriptFontNames[.japanese]?.first,
              let fontId = fontId(fontName: fontName) else {
            return ascent(fontId: 0, size: size)
        }
        return ascent(fontId: fontId, size: size)
    }
    
    func ascent(fontId: Int, size: CGFloat) -> CGFloat {
        // Get descent
        return CTFontGetAscent(ctFont(fontId: fontId, size: size))
    }
    
    func descent(fontId: Int, size: CGFloat) -> CGFloat {
        // Get descent
        return CTFontGetDescent(ctFont(fontId: fontId, size: size))
    }

    /// How tall a line has to be for the faces a text is set in, against the
    /// size it is set at.
    ///
    /// What `STContext.lineHeightScale` has to be at the least. A line is
    /// given the height it is told and no more, and a face reaching from well
    /// above the em square to well below it is a face cut off at the foot of a
    /// line only an em tall — Chalkboard SE ascends 1.13 em and descends 0.28,
    /// which is 1.41 em of letter asked to stand in 1.00 em of line.
    ///
    /// One at or above this leaves every letter whole. Below it, the feet of
    /// the letters are cut off, and nothing says so: the text is laid out and
    /// measured by the line it was given, and only the drawing runs past it.
    ///
    /// Nothing here about readings. A reading is set in the room the line
    /// leaves above the letters, which is room this does not ask for — see
    /// `rubyFontScale`, and add what a reading needs on top of this.
    ///
    /// Asked of the face at the head of each chain, which is the one a text is
    /// set in. The ones behind it are reached only for a character the first
    /// has no glyph for, and a line sized for every face a chain might fall
    /// back to is a line sized for none of them
    public var minimumLineHeightScale: CGFloat {
        // The scripts a text is set in. Emoji are left out: they are given the
        // line's own em box and their ink centred in it — see STLayout — so
        // however far they reach, they do not ask the line to be taller
        return [STScript.latin, .japanese]
            .map { minimumLineHeightScale(script: $0) }
            .max() ?? 1
    }

    /// The same, asked of the one script
    public func minimumLineHeightScale(script: STScript) -> CGFloat {
        // Get the face at the head of the chain
        guard let fontName = fontNames(script: script).first,
            let fontId = fontId(fontName: fontName)
        else { return 1 }

        // Measured at a size of its own rather than at the one the text is
        // set at, which is not known here and does not change the answer: what
        // comes back is a ratio, and the metrics of a face scale with it.
        //
        // The scale the script is set at is already in it. `ctFont` applies
        // it, so a face set smaller than the text around it asks for less of
        // a line, which is what it should ask for
        let size = Self.metricsSize
        let ascent = ascent(fontId: fontId, size: size)
        let descent = descent(fontId: fontId, size: size)
        return max(1, (ascent + descent) / size)
    }

    /// The size the faces are measured at when a ratio is wanted. Large
    /// enough that rounding in the metrics does not reach the answer
    static let metricsSize: CGFloat = 1000
    
    //--------------------------------------------------------------//
    // MARK: - Font name
    //--------------------------------------------------------------//
    
    public func fontNames(script: STScript) -> [String] {
        // Get font names
        return scriptFontNames[script]!
    }
    
    public func setFontNames(_ fontNames: [String], script: STScript) {
        // Set font name
        scriptFontNames[script] = fontNames
        
        // Rebuild right away, so configurationVersion moves at the moment the
        // configuration changes. Callers that cache a parse watch that version
        // to know their glyphs went stale, and they must not have to call
        // refresh() themselves to find out.
        refresh()
    }
    
    func fontName(fontId: Int) -> String {
        // Get font name
        return possibleFontNames[fontId]
    }
    
    //--------------------------------------------------------------//
    // MARK: - Font scale
    //--------------------------------------------------------------//
    
    func fontScale(script: STScript) -> CGFloat {
        // Get font scale
        return scriptFontScales[script]!
    }
    
    func setFontScale(_ fontScale: CGFloat, script: STScript) {
        // Set font scale
        scriptFontScales[script] = fontScale
        
        // Rebuild right away (see setFontNames)
        refresh()
    }
    
    func fontScale(fontId: Int) -> CGFloat {
        // Get font scale with script
        return fontScale(script: script(fontId: fontId))
    }
    
    //--------------------------------------------------------------//
    // MARK: - Script
    //--------------------------------------------------------------//
    
    public func script(fontId: Int) -> STScript {
        // Get script
        return possibleScripts[fontId]
    }
    
    //--------------------------------------------------------------//
    // MARK: - Drawing properties
    //--------------------------------------------------------------//
    
    func needsToFlip(fontId: Int) -> Bool {
        // Get font name
        let fontName = fontName(fontId: fontId)

        // Check needs to flip
        return Self.fontNamesNeedToFlip.contains(fontName)
    }

    func needsToFlip(fontId: Int, glyph: CGGlyph) -> Bool {
        // Check the font
        guard needsToFlip(fontId: fontId) else { return false }

        // Check cache
        let key = GlyphFlipKey(fontId: fontId, glyph: glyph)
        if let needsToFlip = glyphFlipCache[key] {
            return needsToFlip
        }

        // An emoji font also carries ordinary outline glyphs, for the characters
        // that are text unless a variation selector asks otherwise: '♀' and '♂'
        // are drawn from outlines by AppleColorEmoji, not from its colour bitmaps.
        // Only the bitmaps go through the flipped draw path, so an outline sent the
        // same way comes out upside down. A colour bitmap glyph has no outline to
        // hand back, which is what tells the two apart.
        let ctFont = ctFont(fontId: fontId, size: 17)
        let needsToFlip = CTFontCreatePathForGlyph(ctFont, glyph, nil) == nil
        glyphFlipCache[key] = needsToFlip

        return needsToFlip
    }
    
    //--------------------------------------------------------------//
    // MARK: - Ellipsis
    //--------------------------------------------------------------//
    
    static let horizontalEllipsis = "…" // HORIZONTAL ELLIPSIS, U+2026
    static let middleHorizontalEllipsis = "⋯" // MIDDLE HORIZONTAL ELLIPSIS, U+22ef
    static let verticalEllipsis = "⋮" // VERTICAL ELLIPSIS, U+22ee
    static let presentationVerticalEllipsis = "︙" // PRESENTATION FORM FOR VERTICAL HORIZONTAL ELLIPSIS, U+fe19
    
    /// How far the mark that says the text goes on sends the line along.
    ///
    /// Asked of the font the glyph it stands in place of was set in, at the
    /// size that glyph was set at: the mark is set among the words, not beside
    /// them, and a mark measured at some other size would be put where it does
    /// not fit
    func ellipsisAdvance(fontId: Int, size: CGFloat, direction: STDirection) -> CGFloat {
        // Get ellipsis glyph
        let glyph = ellipsisGlyph(fontId: fontId, direction: direction)
        guard glyph > 0 else { return 0 }
        
        // Get advance
        let ctFont = ctFont(fontId: fontId, size: size)
        var glyphs: [CGGlyph] = [glyph]
        var advances: [CGSize] = [.zero]
        CTFontGetAdvancesForGlyphs(ctFont, .horizontal, &glyphs, &advances, 1)
        
        return advances[0].width
    }

    func ellipsisGlyph(fontId: Int, direction: STDirection) -> CGGlyph {
        // Get ct font
        let ctFont = ctFont(fontId: fontId, size: 17)
        
        // Get ellipsis glyph
        var glyph: CGGlyph = 0
        var buf = [UniChar]()
        switch direction {
        case .lrTb:
            buf = uniChars(string: Self.horizontalEllipsis)
            if CTFontGetGlyphsForCharacters(ctFont, &buf, &glyph, buf.count), glyph > 0 { return glyph }
            buf = uniChars(string: Self.middleHorizontalEllipsis)
            if CTFontGetGlyphsForCharacters(ctFont, &buf, &glyph, buf.count), glyph > 0 { return glyph }
        case .tbRl:
            buf = uniChars(string: Self.verticalEllipsis)
            if CTFontGetGlyphsForCharacters(ctFont, &buf, &glyph, buf.count), glyph > 0 { return glyph }
            buf = uniChars(string: Self.presentationVerticalEllipsis)
            if CTFontGetGlyphsForCharacters(ctFont, &buf, &glyph, buf.count), glyph > 0 { return glyph }
        }
        
        // For not found
        return 0
    }
    
    //--------------------------------------------------------------//
    // MARK: - Refresh
    //--------------------------------------------------------------//
    
    public func refresh() {
        // Refresh possible font names and scripts
        var possibleFontNames = [String]()
        var possibleScripts = [STScript]()
        for script in STScript.allCases {
            guard let fontNames = scriptFontNames[script] else { continue }
            for fontName in fontNames {
                possibleFontNames.append(fontName)
                possibleScripts.append(script)
            }
        }
        self.possibleFontNames = possibleFontNames
        self.possibleScripts = possibleScripts

        // Build a signature of the current font configuration
        var signature = ""
        for script in STScript.allCases {
            let names = (scriptFontNames[script] ?? []).joined(separator: ",")
            let scale = scriptFontScales[script] ?? 1.0
            signature += "\(script):\(names):\(scale);"
        }

        // Clear caches only when the configuration actually changed.
        // fontId is an index into possibleFontNames, so caches stay valid
        // as long as the configuration is unchanged (e.g. across keystrokes).
        guard signature != cacheConfigSignature else { return }
        cacheConfigSignature = signature
        configurationVersion += 1
        charToFontId = [:]
        fontCache = [:]
        glyphMetricsCache = [:]
        glyphFlipCache = [:]
    }
}

private func uniChars(string: String) -> [UniChar] {
    // Get unichars
    var buf = Array<UniChar>(repeating: 0, count: string.utf16.count)
    for (i, c) in string.utf16.enumerated() { buf[i] = c }
    
    return buf
}
