/*
STObject.swift

Author: Makoto Kinoshita

Copyright 2024 HMDT. All rights reserved.
*/

import UIKit

extension Unicode.Scalar {
    var unicodeCategory: STUnicodeCategory? {
        // Find unicode category
        return STUnicodeCategory.allCases.first { unicodeCategory in
            unicodeCategory.range.contains(value)
        }
    }
    
    var script: STScript? {
        // Find script
        guard let unicodeCategory = unicodeCategory else { return nil }
        return STScript.allCases.first { script in
            script.unicodeCategories.contains(unicodeCategory)
        }
    }
}

enum STUnicodeCategory: Int, CaseIterable {
    case c0Control
    case basicLatin
    case c1Control
    case latin1Supplement
    case latinExtendedA
    case latinExtendedB
    case ipaExtensions
    case spacingModifierLetters
    case combiningDiacriticalMarks
    case greedAndCoptic
    case cyrllic
    case cyrllicSupplement
    case armenian
    case hebrew
    case arabic
    case syriac
    case arabicSupplement
    case thaana
    case nko
    case samaritan
    case mandaic
    case syriacSupplement
    case arabicExtendedB
    case arabicExtendedA
    case devanagari
    case gurmukhi
    case gujarati
    case oriya
    case tamil
    case telugu
    case kannada
    case malayalam
    case sinhala
    case thai
    case lao
    case tibetan
    case myanmar
    case georgian
    case hangulJamo
    case ethiopic
    case ethiopicSupplement
    case cherokee
    case unifiedCanadianAboriginalSyllabics
    case ogham
    case runic
    case tagalog
    case hanunoo
    case buhid
    case tagbanwa
    case khmer
    case mongolian
    case unifiedCanadianAboriginalSyllabicsExtended
    case limbu
    case taiLe
    case newTaiLue
    case khmerSymbols
    case buginese
    case taiTham
    case combiningDiacriticalMarksExtended
    case balinese
    case sundanese
    case batak
    case lepcha
    case olChiki
    case cyrillicExtendedC
    case georgianExtended
    case sundaneseSupplement
    case vedicExtensions
    case phoneticExtensions
    case phoneticExtensionsSupplement
    case combiningDiacriticalMarksSupplement
    case latinExtendedAdditional
    case greekExtended
    case generalPunctuation
    case superscriptsAndSubscripts
    case currencySymbols
    case combiningDiacriticalMarksForSymbols
    case letterlikSymbols
    case numberForms
    case arrows
    case mathematicalOperators
    case miscellaneousTechical
    case controlPictures
    case opticalCharacterRecognition
    case enclosedAlphanumerics
    case boxDrawing
    case blockElements
    case geometricShapes
    case miscellaneousSymbols
    case dingbats
    case miscellaneousMathematicalSymbolsA
    case supplementalArrowsA
    case braillePatterns
    case supplementalArrowsB
    case miscellaneousMathematicalSymbolsB
    case supplementalMathematicalOperators
    case miscellaneousSymbolsAndArrows
    case glagolitic
    case latinExtendedC
    case coptic
    case georgianSupplement
    case tifinagh
    case ethiopicExtended
    case cyrillicExtendedA
    case supplementalPunctuation
    case cjkRadicalsSupplement
    case kangxiRadicals
    case ideographicsDescriptionCharacters
    case cjkSymbolsAndPunctuation
    case hiragana
    case katakana
    case bopomofo
    case hangulCompatibilityJamo
    case kanbun
    case bopomofoExtended
    case cjkStrokes
    case katakanaPhoneticExtensions
    case enclosedCjkLettesAndMonths
    case cjkCompatibility
    case cjkUnifiedIdeographsExtensionA
    case yijingHexgramSymbols
    case cjkUnifiedIdeographs
    case yiSyllables
    case yiRadicals
    case lisu
    case vai
    case cyrillicExtendedB
    case bamum
    case modifierToneLetters
    case latinExtendedD
    case sylotiNagri
    case commonIndicNumberForms
    case phagsPa
    case saurashtra
    case devanagariExtended
    case kayahLi
    case rejang
    case hangulJamoExtendedA
    case javanese
    case myanmmarExtendedB
    case cham
    case myanmmarExtendedA
    case taiViet
    case meeteiMayekExtensions
    case ethiopicExtendedA
    case latinExtendedE
    case cherokeeSupplement
    case meeteiMayek
    case hangulSyllables
    case hangulJamoExtendedB
    case highSurrogates
    case highPrivateUseSurrogates
    case lowSurrogates
    case privateUseArea
    case cjkCompatibilityIdeographs
    case alphabeticPresentationForms
    case arabicPresentationFormsA
    case variationSelectors
    case verticalForms
    case combniningHalfMarks
    case cjkCompatibilityForms
    case smallFormVariants
    case arabicPresentationFormsB
    case halfwidthAndFullwidthForms
    case specials
    
    case miscellaneousSymbolsAndPictographs
    case emoticons
    case ornametalDingbats
    case transportAndMapSymbols
    case alchemicalSymbols
    case geometricShapesExtended
    case supplementalArrowsC
    case supplementalSymbolsAndPictographs
    case chessSymbols
    case symbolsAndPictographsExtendedA
    case symbolsForLegacyComputing
    case unassigned
    
    var range: Range<UInt32> {
    // Switch by self
    switch self {
    case .c0Control: return 0x0000 ..< 0x0020
    case .basicLatin: return 0x0020 ..< 0x0080
    case .c1Control: return 0x0080 ..< 0x009f
    case .latin1Supplement: return 0x00a0 ..< 0x0100
    case .latinExtendedA: return 0x0100 ..< 0x0180
    case .latinExtendedB: return 0x0180 ..< 0x0250
    case .ipaExtensions: return 0x0250 ..< 0x02b0
    case .spacingModifierLetters: return 0x02b0 ..< 0x0300
    case .combiningDiacriticalMarks: return 0x0300 ..< 0x0370
    case .greedAndCoptic: return 0x0370 ..< 0x0400
    case .cyrllic: return 0x0400 ..< 0x0500
    case .cyrllicSupplement: return 0x0500 ..< 0x0530
    case .armenian: return 0x0530 ..< 0x0590
    case .hebrew: return 0x0590 ..< 0x0600
    case .arabic: return 0x0600 ..< 0x0700
    case .syriac: return 0x0700 ..< 0x0750
    case .arabicSupplement: return 0x0750 ..< 0x0780
    case .thaana: return 0x0780 ..< 0x07c0
    case .nko: return 0x07c0 ..< 0x0800
    case .samaritan: return 0x0800 ..< 0x0840
    case .mandaic: return 0x0840 ..< 0x0860
    case .syriacSupplement: return 0x0860 ..< 0x0870
    case .arabicExtendedB: return 0x0870 ..< 0x08a0
    case .arabicExtendedA: return 0x08a0 ..< 0x0900
    case .devanagari: return 0x0900 ..< 0x0980
    case .gurmukhi: return 0x0a00 ..< 0x0a80
    case .gujarati: return 0x0a80 ..< 0x0b00
    case .oriya: return 0x0b00 ..< 0x0b80
    case .tamil: return 0x0b80 ..< 0x0c00
    case .telugu: return 0x0c00 ..< 0x0c80
    case .kannada: return 0x0c80 ..< 0x0d00
    case .malayalam: return 0x0d00 ..< 0x0d80
    case .sinhala: return 0x0d80 ..< 0x0e00
    case .thai: return 0x0e00 ..< 0x0e80
    case .lao: return 0x0e80 ..< 0x0f00
    case .tibetan: return 0x0f00 ..< 0x1000
    case .myanmar: return 0x1000 ..< 0x10a0
    case .georgian: return 0x10a0 ..< 0x1100
    case .hangulJamo: return 0x1100 ..< 0x1200
    case .ethiopic: return 0x1200 ..< 0x1380
    case .ethiopicSupplement: return 0x1380 ..< 0x13a0
    case .cherokee: return 0x13a0 ..< 0x1400
    case .unifiedCanadianAboriginalSyllabics: return 0x1400 ..< 0x1680
    case .ogham: return 0x1680 ..< 0x16a0
    case .runic: return 0x1680 ..< 0x1700
    case .tagalog: return 0x1700 ..< 0x1720
    case .hanunoo: return 0x1720 ..< 0x1740
    case .buhid: return 0x1740 ..< 0x1760
    case .tagbanwa: return 0x1760 ..< 0x1780
    case .khmer: return 0x1780 ..< 0x1800
    case .mongolian: return 0x1800 ..< 0x18b0
    case .unifiedCanadianAboriginalSyllabicsExtended: return 0x18b0 ..< 0x1900
    case .limbu: return 0x1900 ..< 0x1950
    case .taiLe: return 0x1950 ..< 0x1980
    case .newTaiLue: return 0x1980 ..< 0x19e0
    case .khmerSymbols: return 0x19a0 ..< 0x1a00
    case .buginese: return 0x1a00 ..< 0x1a20
    case .taiTham: return 0x1a20 ..< 0x1ab0
    case .combiningDiacriticalMarksExtended: return 0x1ab0 ..< 0x1b00
    case .balinese: return 0x1b00 ..< 0x1b80
    case .sundanese: return 0x1b80 ..< 0x1bc0
    case .batak: return 0x1bc0 ..< 0x1c00
    case .lepcha: return 0x1c00 ..< 0x1c50
    case .olChiki: return 0x1c50 ..< 0x1c80
    case .cyrillicExtendedC: return 0x1c80 ..< 0x1c90
    case .georgianExtended: return 0x1c90 ..< 0x1cc0
    case .sundaneseSupplement: return 0x1cc0 ..< 0x1cd0
    case .vedicExtensions: return 0x1cd0 ..< 0x1d00
    case .phoneticExtensions: return 0x1d00 ..< 0x1d80
    case .phoneticExtensionsSupplement: return 0x1d80 ..< 0x1dc0
    case .combiningDiacriticalMarksSupplement: return 0x1dc0 ..< 0x1e00
    case .latinExtendedAdditional: return 0x1e00 ..< 0x1f00
    case .greekExtended: return 0x1f00 ..< 0x2000
    case .generalPunctuation: return 0x2000 ..< 0x2070
    case .superscriptsAndSubscripts: return 0x2070 ..< 0x20a0
    case .currencySymbols: return 0x20a0 ..< 0x20d0
    case .combiningDiacriticalMarksForSymbols: return 0x20d0 ..< 0x2100
    case .letterlikSymbols: return 0x2100 ..< 0x2150
    case .numberForms: return 0x2150 ..< 0x2190
    case .arrows: return 0x2190 ..< 0x2200
    case .mathematicalOperators: return 0x2200 ..< 0x2300
    case .miscellaneousTechical: return 0x2300 ..< 0x2400
    case .controlPictures: return 0x2400 ..< 0x2440
    case .opticalCharacterRecognition: return 0x2440 ..< 0x2460
    case .enclosedAlphanumerics: return 0x2460 ..< 0x2500
    case .boxDrawing: return 0x2500 ..< 0x2580
    case .blockElements: return 0x2580 ..< 0x25a0
    case .geometricShapes: return 0x25a0 ..< 0x2600
    case .miscellaneousSymbols: return 0x2600 ..< 0x2700
    case .dingbats: return 0x2700 ..< 0x27c0
    case .miscellaneousMathematicalSymbolsA: return 0x27c0 ..< 0x27f0
    case .supplementalArrowsA: return 0x27f0 ..< 0x2800
    case .braillePatterns: return 0x2800 ..< 0x2900
    case .supplementalArrowsB: return 0x2900 ..< 0x2980
    case .miscellaneousMathematicalSymbolsB: return 0x2980 ..< 0x2a00
    case .supplementalMathematicalOperators: return 0x2a00 ..< 0x2b00
    case .miscellaneousSymbolsAndArrows: return 0x2b00 ..< 0x2c00
    case .glagolitic: return 0x2c00 ..< 0x2c60
    case .latinExtendedC: return 0x2c60 ..< 0x2c80
    case .coptic: return 0x2c80 ..< 0x2d00
    case .georgianSupplement: return 0x2d00 ..< 0x2d30
    case .tifinagh: return 0x2d30 ..< 0x2d80
    case .ethiopicExtended: return 0x2d80 ..< 0x2de0
    case .cyrillicExtendedA: return 0x2de0 ..< 0x2e00
    case .supplementalPunctuation: return 0x2e00 ..< 0x2e80
    case .cjkRadicalsSupplement: return 0x2e80 ..< 0x2f00
    case .kangxiRadicals: return 0x2f00 ..< 0x2fe0
    case .ideographicsDescriptionCharacters: return 0x2ff0 ..< 0x3000
    case .cjkSymbolsAndPunctuation: return 0x3000 ..< 0x3040
    case .hiragana: return 0x3040 ..< 0x30a0
    case .katakana: return 0x30a0 ..< 0x3100
    case .bopomofo: return 0x3100 ..< 0x3130
    case .hangulCompatibilityJamo: return 0x3130 ..< 0x3190
    case .kanbun: return 0x3190 ..< 0x31a0
    case .bopomofoExtended: return 0x31a0 ..< 0x31c0
    case .cjkStrokes: return 0x31c0 ..< 0x31f0
    case .katakanaPhoneticExtensions: return 0x31f0 ..< 0x3200
    case .enclosedCjkLettesAndMonths: return 0x3200 ..< 0x3300
    case .cjkCompatibility: return 0x3300 ..< 0x3400
    case .cjkUnifiedIdeographsExtensionA: return 0x3400 ..< 0x4dc0
    case .yijingHexgramSymbols: return 0x4dc0 ..< 0x4e00
    case .cjkUnifiedIdeographs: return 0x4e00 ..< 0xa000
    case .yiSyllables: return 0xa000 ..< 0xa490
    case .yiRadicals: return 0xa490 ..< 0xa4d0
    case .lisu: return 0xa4d0 ..< 0xa500
    case .vai: return 0xa500 ..< 0xa640
    case .cyrillicExtendedB: return 0xa640 ..< 0xa6a0
    case .bamum: return 0xa6a0 ..< 0xa700
    case .modifierToneLetters: return 0xa700 ..< 0xa720
    case .latinExtendedD: return 0xa720 ..< 0xa800
    case .sylotiNagri: return 0xa800 ..< 0xa830
    case .commonIndicNumberForms: return 0xa830 ..< 0xa840
    case .phagsPa: return 0xa840 ..< 0xa880
    case .saurashtra: return 0xa880 ..< 0xa8e0
    case .devanagariExtended: return 0xa8e0 ..< 0xa900
    case .kayahLi: return 0xa900 ..< 0xa930
    case .rejang: return 0xa930 ..< 0xa960
    case .hangulJamoExtendedA: return 0xa960 ..< 0xa980
    case .javanese: return 0xa980 ..< 0xa9e0
    case .myanmmarExtendedB: return 0xa9e0 ..< 0xaa00
    case .cham: return 0xaa00 ..< 0xaa60
    case .myanmmarExtendedA: return 0xaa60 ..< 0xaa80
    case .taiViet: return 0xaa80 ..< 0xaae0
    case .meeteiMayekExtensions: return 0xaae0 ..< 0xab00
    case .ethiopicExtendedA: return 0xab00 ..< 0xab30
    case .latinExtendedE: return 0xab30 ..< 0xab70
    case .cherokeeSupplement: return 0xab70 ..< 0xabc0
    case .meeteiMayek: return 0xabc0 ..< 0xac00
    case .hangulSyllables: return 0xac00 ..< 0xd7b0
    case .hangulJamoExtendedB: return 0xd7b0 ..< 0xd800
    case .highSurrogates: return 0xd800 ..< 0xdb80
    case .highPrivateUseSurrogates: return 0xdb80 ..< 0xdc00
    case .lowSurrogates: return 0xdc00 ..< 0xe000
    case .privateUseArea: return 0xe000 ..< 0xf900
    case .cjkCompatibilityIdeographs: return 0xf900 ..< 0xfb00
    case .alphabeticPresentationForms: return 0xfb00 ..< 0xfb50
    case .arabicPresentationFormsA: return 0xfb50 ..< 0xfe00
    case .variationSelectors: return 0xfe00 ..< 0xfe10
    case .verticalForms: return 0xfe10 ..< 0xfe20
    case .combniningHalfMarks: return 0xfe20 ..< 0xfe30
    case .cjkCompatibilityForms: return 0xfe30 ..< 0xfe50
    case .smallFormVariants: return 0xfe50 ..< 0xfe70
    case .arabicPresentationFormsB: return 0xfe70 ..< 0xff00
    case .halfwidthAndFullwidthForms: return 0xff00 ..< 0xfff0
    case .specials: return 0xfff0 ..< 0x10000
    
    case .miscellaneousSymbolsAndPictographs: return 0x1f300 ..< 0x1f600
    case .emoticons: return 0x1f600 ..< 0x1f650
    case .ornametalDingbats: return 0x1f650 ..< 0x1f680
    case .transportAndMapSymbols: return 0x1f680 ..< 0x1f700
    case .alchemicalSymbols: return 0x1f700 ..< 0x1f780
    case .geometricShapesExtended: return 0x1f780 ..< 0x1f800
    case .supplementalArrowsC: return 0x1f800 ..< 0x1f900
    case .supplementalSymbolsAndPictographs: return 0x1f900 ..< 0x1fa00
    case .chessSymbols: return 0x1fa00 ..< 0x1fa70
    case .symbolsAndPictographsExtendedA: return 0x1fa70 ..< 0x1fb00
    case .symbolsForLegacyComputing: return 0x1fb00 ..< 0x1fc00
    case .unassigned: return 0x1ff80 ..< 0x20000
    }
    }
}

enum STScript: Int, CaseIterable {
    case latin
    case japanese
    case emoji
    
    var unicodeCategories: [STUnicodeCategory] {
        // Swtich by self
        switch self {
        case .latin: return [
            .basicLatin, 
        ]
        case .japanese: return [
            .cjkCompatibility, 
            .cjkCompatibilityForms, 
            .cjkCompatibilityIdeographs, 
            .cjkRadicalsSupplement, 
            .cjkStrokes, 
            .cjkSymbolsAndPunctuation, 
            .cjkUnifiedIdeographs, 
            .cjkUnifiedIdeographsExtensionA, 
            .enclosedCjkLettesAndMonths, 
            .halfwidthAndFullwidthForms, 
            .hiragana, 
            .katakana, 
            .katakanaPhoneticExtensions, 
        ]
        case .emoji: return [
            .dingbats, 
            .emoticons,
            .miscellaneousSymbols,  
            .miscellaneousSymbolsAndPictographs, 
            .supplementalSymbolsAndPictographs, 
            .symbolsAndPictographsExtendedA, 
            .transportAndMapSymbols, 
        ]
        }
    }
    
    var notNeedsToClockwiseInTbRl: Bool {
        let notNeedsToClockwise: [STScript] = [.japanese, .emoji, ]
        return notNeedsToClockwise.contains(self)
    }
}

enum STTextAlign: Int, CaseIterable {
    case leading
    case center
    case trailng
    case justify
}

enum STDirectionAlign: Int, CaseIterable {
    case start
    case middle
    case end
}

enum STDirection: Int, CaseIterable {
    case lrTb
    case tbRl
}

enum STNewLineMode: Int, CaseIterable {
    case lf
    case cr
    case crlf
}

enum STPunctuation: Int, CaseIterable {
    case whole
    case firstHalf
    case secondHalf
    case quarter
    
    static let firstHalfPunctuationCharSet = CharacterSet(charactersIn: "、。）］｝〕〉》」』】〙〗〟｠")
    static let secondHalfPunctuationCharSet = CharacterSet(charactersIn: "（［｛〔〈《「『【〘〖〝｟")
    static let quarterPunctuationCharSet = CharacterSet(charactersIn: "・：；")
    
    static func valueOf(charatcter: Character) -> STPunctuation {
        // Decide punctuation
        guard let scalar = charatcter.unicodeScalars.first else { return .whole }
        if firstHalfPunctuationCharSet.contains(scalar) { return .firstHalf }
        else if secondHalfPunctuationCharSet.contains(scalar) { return .secondHalf }
        else if quarterPunctuationCharSet.contains(scalar) { return .quarter }
        else { return .whole }
    }
}

enum STPunctuationMode: Int, CaseIterable {
    case whole
    case half
    case stone
}

enum STKinsoku {
    static let notStartingCharSet = CharacterSet(charactersIn: " ,.?:;!)）]］｝、〕〉》」』】〙〗〟’”｠»ヽヾァィゥェォッャュョヮヵヶぁぃぅぇぉっゃゅょゎゕゖㇰㇱㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ々〻？!‼⁇⁈⁉。.™")
    static let notEndingCharSet = CharacterSet(charactersIn: "(（[［｛〔〈《「『【〘〖〝‘“｟«\"'")
    static let hangingCharSet = CharacterSet(charactersIn: "、。")
    
}

enum STRunVisibility: Int, CaseIterable {
    case visible
    case invisible
    case ellipsis
}

struct STRun {
    var tokenId: Int
    var tokenRunIndex: Int
    var fontId: Int
    var char: Character
    var punctuation: STPunctuation
    var glyph: CGGlyph
    var advance: CGSize
    var boundingRect: CGRect
    var position: CGPoint
    var frame: CGRect
    var visibility: STRunVisibility
    var line: Int
    
    var isHidden: Bool { visibility == .invisible }
}

struct STToken {
    var runIdRange: Range<Int>
}
