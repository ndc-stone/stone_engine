/*
STFontManager.swift

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center. All rights reserved.
This software is licensed under the MIT License. See LICENSE for details.
*/

import UIKit

open class STFontManager {
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
    
    // Font scale
    private var scriptFontScales: [STScript: CGFloat] = [
        .latin: 0.95, 
        .japanese: 1.0, 
        .emoji: 1.0, 
    ]
    
    // CT fonts cache
    static private var fontIdCtFonts = [Int: CTFont]()
}

extension STFontManager {
    //--------------------------------------------------------------//
    // MARK: - Font
    //--------------------------------------------------------------//
    
    func fontId(char: Character) -> Int {
        // Get script
        guard let script = char.unicodeScalars.first?.script else {
            // Use default font ID
            return 0
        }
        
        // Decide font ID
        let fontNames = scriptFontNames[script] ?? []
        for fontName in fontNames {
            let ctFont = CTFontCreateWithName(fontName as CFString, 17, nil)
            let chars = uniChars(char: char)
            var glyph: CGGlyph = 0
            if CTFontGetGlyphsForCharacters(ctFont, chars, &glyph, chars.count), 
                glyph > 0, 
                let index = possibleFontNames.firstIndex(of: fontName)
            {
                return index
            }
        }
        
        // Use default font ID
        return 0
    }
    
    func ctFont(fontId: Int, size: CGFloat, isClockwise: Bool = false) -> CTFont {
        // Get font name and script
        let fontName = possibleFontNames[fontId]
        let script = possibleScripts[fontId]
        
        // Decide font size
        let fontScale = scriptFontScales[script]!
        let size = size * fontScale
        
        // Decide transform
        var transform: CGAffineTransform = .identity
        transform = transform.scaledBy(x: 1, y: -1)
        if isClockwise {
            transform = transform.rotated(by: .pi * -0.5)
        }
        
        // Create font
        let font = CTFontCreateWithName(fontName as CFString, size, &transform)
        
        return font
    }
    
    func ascent(fontId: Int, size: CGFloat) -> CGFloat {
        // Get descent
        return CTFontGetAscent(ctFont(fontId: fontId, size: size))
    }
    
    func descent(fontId: Int, size: CGFloat) -> CGFloat {
        // Get descent
        return CTFontGetDescent(ctFont(fontId: fontId, size: size))
    }
    
    //--------------------------------------------------------------//
    // MARK: - Font name
    //--------------------------------------------------------------//
    
    func fontNames(script: STScript) -> [String] {
        // Get font names
        return scriptFontNames[script]!
    }
    
    func setFontNames(_ fontNames: [String], script: STScript) {
        // Set font name
        scriptFontNames[script] = fontNames
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
    }
    
    func fontScale(fontId: Int) -> CGFloat {
        // Get font scale with script
        return fontScale(script: script(fontId: fontId))
    }
    
    //--------------------------------------------------------------//
    // MARK: - Script
    //--------------------------------------------------------------//
    
    func script(fontId: Int) -> STScript {
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
    
    //--------------------------------------------------------------//
    // MARK: - Ellipsis
    //--------------------------------------------------------------//
    
    static let horizontalEllipsis = "…" // HORIZONTAL ELLIPSIS, U+2026
    static let middleHorizontalEllipsis = "⋯" // MIDDLE HORIZONTAL ELLIPSIS, U+22ef
    static let verticalEllipsis = "⋮" // VERTICAL ELLIPSIS, U+22ee
    static let presentationVerticalEllipsis = "︙" // PRESENTATION FORM FOR VERTICAL HORIZONTAL ELLIPSIS, U+fe19
    
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
    
    func refresh() {
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
    }
}

private func uniChars(string: String) -> [UniChar] {
    // Get unichars
    var buf = Array<UniChar>(repeating: 0, count: string.utf16.count)
    for (i, c) in string.utf16.enumerated() { buf[i] = c }
    
    return buf
}

private func uniChars(char: Character) -> [UniChar] {
    // Get unichars
    var buf = Array<UniChar>(repeating: 0, count: char.utf16.count)
    for (i, c) in char.utf16.enumerated() { buf[i] = c }
    
    return buf
}
