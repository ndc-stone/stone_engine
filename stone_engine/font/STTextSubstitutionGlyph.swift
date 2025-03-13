/*
 STTextSubstitutionGlyph.swift

 Author: Makoto Kinoshita (mkino@hmdt.jp)

 Copyright 2024 Nihon Design Center. All rights reserved.
 This software is licensed under the MIT License. See LICENSE for details.
 */

import Foundation
import CoreText
#if os(iOS)
import UIKit
#else
import Cocoa
#endif

// Extension for reading big-endian values from UInt8 pointers
extension UnsafePointer where Pointee == UInt8 {
    func readBigEndianUInt16(at offset: Int = 0) -> UInt16 {
        let bytes = self.advanced(by: offset)
        return (UInt16(bytes.pointee) << 8) | UInt16(bytes.advanced(by: 1).pointee)
    }

    func readBigEndianUInt32(at offset: Int = 0) -> UInt32 {
        let bytes = self.advanced(by: offset)
        return (UInt32(bytes.pointee) << 24) |
        (UInt32(bytes.advanced(by: 1).pointee) << 16) |
        (UInt32(bytes.advanced(by: 2).pointee) << 8) |
        UInt32(bytes.advanced(by: 3).pointee)
    }
}

// Helper function to create tag from characters
private func createTag(_ a: Character, _ b: Character, _ c: Character, _ d: Character) -> UInt32 {
    let aVal = UInt32(a.asciiValue ?? 0)
    let bVal = UInt32(b.asciiValue ?? 0)
    let cVal = UInt32(c.asciiValue ?? 0)
    let dVal = UInt32(d.asciiValue ?? 0)

    return (aVal << 24) | (bVal << 16) | (cVal << 8) | dVal
}

// Script tags
struct ScriptTag {
    static let cyrl = createTag("c", "y", "r", "l")
    static let grek = createTag("g", "r", "e", "k")
    static let hani = createTag("h", "a", "n", "i")
    static let kana = createTag("k", "a", "n", "a")
    static let latn = createTag("l", "a", "t", "n")
}

// Feature tags
struct FeatureTag {
    static let aalt = createTag("a", "a", "l", "t")
    static let jp78 = createTag("j", "p", "7", "8")
    static let jp83 = createTag("j", "p", "8", "3")
    static let jp90 = createTag("j", "p", "9", "0")
    static let jp04 = createTag("j", "p", "0", "4")
    static let nlck = createTag("n", "l", "c", "k")
    static let trad = createTag("t", "r", "a", "d")
    static let vert = createTag("v", "e", "r", "t")
    static let vkna = createTag("v", "k", "n", "a")
    static let vrt2 = createTag("v", "r", "t", "2")
}

class STTextSubstitutionGlyph {
    private static let vertBufferCount = 16
    private static var vertNumber = 0
    private static var vertFontNames: [String] = Array(repeating: "", count: vertBufferCount)
    private static var vertGlyphs: [UnsafeMutablePointer<CGGlyph>?] = Array(repeating: nil, count: vertBufferCount)

    private static var prevFontName: String?
    private static var gsubTable: CFData?

    static func printTag(_ value: Int) {
        print("\(Character(UnicodeScalar(value >> 24)!))\(Character(UnicodeScalar((value & 0x00FF0000) >> 16)!))\(Character(UnicodeScalar((value & 0x0000FF00) >> 8)!))\(Character(UnicodeScalar(value & 0x000000FF)!))")
    }

    private static func substituteGlyphIdWithLookupSubtable(lookupType: Int, subTablePtr: UnsafePointer<UInt8>, glyph: CGGlyph) -> CGGlyph {
        // Set sub table pointer
        var tmp6 = subTablePtr

        // Switch by lookup type
        switch lookupType {
            // Lookup type 1: Single Substitution Subtable
            // Lookup type 3: Single Substitution Subtable
        case 1, 3:
            // Read subst format
            let substFormat = tmp6.readBigEndianUInt16()
            tmp6 = tmp6.advanced(by: 2)

            // Read coverage offset
            let coverageOffset = tmp6.readBigEndianUInt16()
            tmp6 = tmp6.advanced(by: 2)

            // Read coverage table
            let coverageTablePtr = subTablePtr.advanced(by: Int(coverageOffset))
            var tmp7 = coverageTablePtr

            // Read coverage format
            let coverageFormat = tmp7.readBigEndianUInt16()
            tmp7 = tmp7.advanced(by: 2)

            // Decide coverage index
            var coverageIndex: Int16 = -1

            // Switch by coverage format
            switch coverageFormat {
                // Coverage format 1: Individual glyph indices
            case 1:
                // Read glyph count
                let glyphCount = tmp7.readBigEndianUInt16()
                tmp7 = tmp7.advanced(by: 2)

                // Read glyph IDs
                for n in 0..<glyphCount {
                    // Read glyph ID
                    let glyphId = tmp7.readBigEndianUInt16()
                    tmp7 = tmp7.advanced(by: 2)

                    // Check glyph
                    if glyph == glyphId {
                        coverageIndex = Int16(n)
                        break
                    }
                }

                // Coverage format 2: Range of glyphs
            case 2:
                // Read range count
                let rangeCount = tmp7.readBigEndianUInt16()
                tmp7 = tmp7.advanced(by: 2)

                // Read RangeRecords
                for _ in 0..<rangeCount {
                    // Read RangeRecord
                    let startGlyphId = tmp7.readBigEndianUInt16()
                    tmp7 = tmp7.advanced(by: 2)
                    let endGlyphId = tmp7.readBigEndianUInt16()
                    tmp7 = tmp7.advanced(by: 2)
                    let startCoverageIndex = tmp7.readBigEndianUInt16()
                    tmp7 = tmp7.advanced(by: 2)

                    // Check glyph
                    if glyph >= startGlyphId && glyph <= endGlyphId {
                        // Calc coverage index
                        coverageIndex = Int16(startCoverageIndex) + Int16(glyph - startGlyphId)
                    }
                }

            default:
                break
            }

            // For lookup type 1
            if lookupType == 1 {
                // Switch by subst format
                switch substFormat {
                    // Subst format 1
                case 1:
                    // Read delta glyph ID
                    let deltaGlyphId = tmp6.readBigEndianUInt16()
                    tmp6 = tmp6.advanced(by: 2)

                    print("Not implemented yet, subst format 1")

                    // Subst format 2
                case 2:
                    // Read glyph count
                    let glyphCount = tmp6.readBigEndianUInt16()
                    tmp6 = tmp6.advanced(by: 2)

                    // Check with coverage index
                    if coverageIndex == -1 { return 0 }
                    if coverageIndex > Int16(glyphCount) {
                        print("Coverage index is larger than glyph count, coverageIndex \(coverageIndex), glyphCount \(glyphCount)")
                        return 0
                    }

                    // Read substitute glyph ID at coverage index
                    let substGlyph = tmp6.advanced(by: Int(coverageIndex) * 2).readBigEndianUInt16()

                    return CGGlyph(substGlyph)

                default:
                    break
                }
            }

            // For lookup type 3
            else if lookupType == 3 {
                // Read alternate set count
                let alternateSetCount = tmp6.readBigEndianUInt16()
                tmp6 = tmp6.advanced(by: 2)

                // Check with coverage index
                if coverageIndex == -1 { return 0 }
                if coverageIndex > Int16(alternateSetCount) {
                    print("Coverage index is larger than alternate set count, coverageIndex \(coverageIndex), alternateSetCount \(alternateSetCount)")
                    return 0
                }

                // Read alternate set table offset
                let alternateSetTableOffset = tmp6.advanced(by: Int(coverageIndex) * 2).readBigEndianUInt16()

                // Read AlternateSet table
                let alternateSetTablePtr = subTablePtr.advanced(by: Int(alternateSetTableOffset))
                var tmp7 = alternateSetTablePtr

                // Skip glyph count
                tmp7 = tmp7.advanced(by: 2)

                // Read alternate glyph ID
                let alternateGlyph = tmp7.readBigEndianUInt16()

                // Add glyph ID
                return CGGlyph(alternateGlyph)
            }

            // Lookup type 7: Extension Substitution
        case 7:
            // Skip subst format
            tmp6 = tmp6.advanced(by: 2)

            // Read extension lookup type
            let extensionLookupType = Int(tmp6.readBigEndianUInt16())
            tmp6 = tmp6.advanced(by: 2)

            // Read extension offset
            let extensionOffset = Int(tmp6.readBigEndianUInt32())

            // Read sub table
            return substituteGlyphIdWithLookupSubtable(
                lookupType: extensionLookupType,
                subTablePtr: subTablePtr.advanced(by: extensionOffset),
                glyph: glyph
            )

        default:
            break
        }

        return 0
    }

    private static func substituteGlyph(fontName: String, scriptTag: UInt32, featureTag: UInt32, glyph: CGGlyph) -> CGGlyph {
        // For another font
        if prevFontName != fontName {
            // Set prev font name
            prevFontName = fontName

            // Create ctFont
            let font = CTFontCreateWithName(fontName as CFString, 18.0, nil)

            // Release old GSUB table
            gsubTable = nil

            // Get GSUB table
            gsubTable = CTFontCopyTable(font, CTFontTableTag(kCTFontTableGSUB), CTFontTableOptions(rawValue: CTFontTableTag(0)))
            if gsubTable == nil {
                print("Failed to get GSUB table")
                return 0
            }
        }

        // Get root pointer
        guard let gsubTable = gsubTable,
              let rootPtr = CFDataGetBytePtr(gsubTable) else {
            return 0
        }

        var tmp = rootPtr

        // Read GSUB header
        tmp = tmp.advanced(by: 4) // Skip version
        let scriptListOffset = tmp.readBigEndianUInt16()
        tmp = tmp.advanced(by: 2)
        let featureListOffset = tmp.readBigEndianUInt16()
        tmp = tmp.advanced(by: 2)
        let lookupListOffset = tmp.readBigEndianUInt16()

        // Read ScriptList table
        let scriptListTablePtr = rootPtr.advanced(by: Int(scriptListOffset))
        let scriptListCount = scriptListTablePtr.readBigEndianUInt16()

        // Read FeatureList table
        let featureListTablePtr = rootPtr.advanced(by: Int(featureListOffset))

        // Read LookupList table
        let lookupListTablePtr = rootPtr.advanced(by: Int(lookupListOffset))

        // Read ScriptRecords
        tmp = scriptListTablePtr.advanced(by: 2)
        for _ in 0..<scriptListCount {
            // Read ScriptRecord tag
            let scriptRecordTag = tmp.readBigEndianUInt32()
            tmp = tmp.advanced(by: 4)

            // Read ScriptRecord offset
            let scriptRecordOffset = tmp.readBigEndianUInt16()
            tmp = tmp.advanced(by: 2)

            // Check script tag
            if scriptTag != scriptRecordTag { continue }

            // Read Script table
            let scriptTablePtr = scriptListTablePtr.advanced(by: Int(scriptRecordOffset))
            var tmp2 = scriptTablePtr
            let defaultLangSysOffset = tmp2.readBigEndianUInt16()

            if defaultLangSysOffset != 0 {
                // Read LangSys table
                let langSysTablePtr = scriptTablePtr.advanced(by: Int(defaultLangSysOffset))
                var tmp2 = langSysTablePtr
                tmp2 = tmp2.advanced(by: 2) // Skip LookupOrder
                tmp2 = tmp2.advanced(by: 2) // Skip reqFeatureIndex
                let featureCount = tmp2.readBigEndianUInt16()
                tmp2 = tmp2.advanced(by: 2)

                // Read feature FeatureList tables
                for _ in 0..<featureCount {
                    // Read feature index
                    let featureIndex = tmp2.readBigEndianUInt16()
                    tmp2 = tmp2.advanced(by: 2)

                    // Read FeatureRecord
                    let featureRecordPtr = featureListTablePtr.advanced(by: 2 + Int(featureIndex) * 6)
                    var tmp3 = featureRecordPtr

                    // Read feature record tag
                    let featureRecordTag = tmp3.readBigEndianUInt32()
                    tmp3 = tmp3.advanced(by: 4)

                    // Read feature record offset
                    let featureRecordOffset = tmp3.readBigEndianUInt16()

                    // Check feature tag
                    if featureTag != featureRecordTag { continue }

                    // Read Feature table
                    let featureTablePtr = featureListTablePtr.advanced(by: Int(featureRecordOffset))
                    var tmp4 = featureTablePtr

                    // Skip feature params
                    tmp4 = tmp4.advanced(by: 2)

                    // Read lookup count
                    let lookupCount = tmp4.readBigEndianUInt16()
                    tmp4 = tmp4.advanced(by: 2)

                    // Read lookup list index
                    for _ in 0..<lookupCount {
                        // Read lookup list index
                        let lookupListIndex = tmp4.readBigEndianUInt16()
                        tmp4 = tmp4.advanced(by: 2)

                        // Read lookup offset
                        let lookupOffset = lookupListTablePtr.advanced(by: 2).advanced(by: Int(lookupListIndex) * 2).readBigEndianUInt16()

                        // Read Lookup table
                        let lookupTablePtr = lookupListTablePtr.advanced(by: Int(lookupOffset))
                        var tmp5 = lookupTablePtr

                        // Read lookup type
                        let lookupType = Int(tmp5.readBigEndianUInt16())
                        tmp5 = tmp5.advanced(by: 2)

                        // Skip lookup flag
                        tmp5 = tmp5.advanced(by: 2)

                        // Read sub table count
                        let subTableCount = tmp5.readBigEndianUInt16()
                        tmp5 = tmp5.advanced(by: 2)

                        // Read sub table offset
                        for _ in 0..<subTableCount {
                            // Read sub table offset
                            let subTableOffset = tmp5.readBigEndianUInt16()
                            tmp5 = tmp5.advanced(by: 2)

                            // Read sub table
                            let subTablePtr = lookupTablePtr.advanced(by: Int(subTableOffset))

                            // Read sub table
                            let substGlyph = substituteGlyphIdWithLookupSubtable(
                                lookupType: lookupType,
                                subTablePtr: subTablePtr,
                                glyph: glyph
                            )
                            if substGlyph > 0 { return substGlyph }
                        }
                    }

                    return 0
                }
            }
        }

        return 0
    }

    private static func setVerticalGlyphWithStrings(font: CTFont, glyphTable: UnsafeMutablePointer<CGGlyph>, normalStr: String, vertStr: String) {
        // Get normal glyph
        var normalUnichar: UniChar = 0
        var normalGlyph: CGGlyph = 0

        if let firstScalar = normalStr.unicodeScalars.first {
            normalUnichar = UniChar(firstScalar.value)
        }

        CTFontGetGlyphsForCharacters(font, [normalUnichar], &normalGlyph, 1)
        if normalGlyph == 0 {
            print("Can't find glyph for \(normalStr)")
        }

        // Get vertical glyph
        var vertUnichar: UniChar = 0
        var vertGlyph: CGGlyph = 0

        if let firstScalar = vertStr.unicodeScalars.first {
            vertUnichar = UniChar(firstScalar.value)
        }

        CTFontGetGlyphsForCharacters(font, [vertUnichar], &vertGlyph, 1)
        if vertGlyph == 0 {
            print("Can't find glyph for \(vertStr)")
        }

        // Set glyph
        if normalGlyph != 0 && vertGlyph != 0 {
            glyphTable[Int(normalGlyph)] = vertGlyph
        }
    }

    public static func verticalSubstitutionGlyphWithGlyph(fontName: String, glyph: CGGlyph) -> CGGlyph {
        // Find buffer index
        var i = 0
        for idx in 0..<vertNumber {
            if fontName == vertFontNames[idx] {
                i = idx
                break
            }
        }

        // For not found
        if i == vertNumber {
            // Check count
            if i >= vertBufferCount {
                print("Exceed vert buffer count")
                return 0
            } else {
                // Set font name
                vertFontNames[i] = fontName

                // Allocate glyph table
                let glyphTable = UnsafeMutablePointer<CGGlyph>.allocate(capacity: 65536)
                for j in 0..<65536 {
                    glyphTable[j] = 65535
                }
                vertGlyphs[i] = glyphTable

                // Increment vert number
                vertNumber += 1

                // Add special vertical glyphs, which has no vert values
                let font = CTFontCreateWithName(fontName as CFString, 18.0, nil)
                // Set vert glyphs
                setVerticalGlyphWithStrings(font: font, glyphTable: glyphTable, normalStr: "＜", vertStr: "︿")
                setVerticalGlyphWithStrings(font: font, glyphTable: glyphTable, normalStr: "＞", vertStr: "﹀")
                setVerticalGlyphWithStrings(font: font, glyphTable: glyphTable, normalStr: "－", vertStr: "｜")
            }
        }

        // Get glyph table
        guard let glyphTable = vertGlyphs[i] else { return 0 }

        // Check table
        if glyphTable[Int(glyph)] == 65535 {
            // Get substitution glyph ID
            var substGlyph = substituteGlyph(fontName: fontName, scriptTag: ScriptTag.kana, featureTag: FeatureTag.vrt2, glyph: glyph)
            if substGlyph == 0 {
                substGlyph = substituteGlyph(fontName: fontName, scriptTag: ScriptTag.kana, featureTag: FeatureTag.vert, glyph: glyph)
            }
            if substGlyph == 0 {
                substGlyph = substituteGlyph(fontName: fontName, scriptTag: ScriptTag.kana, featureTag: FeatureTag.vkna, glyph: glyph)
            }

            // Set substitution glyph ID
            glyphTable[Int(glyph)] = substGlyph
        }

        // Get substitution glyph
        return glyphTable[Int(glyph)]
    }
}

// Public API matching the original Objective-C function
public func STTextVerticalSubstitutionGlyphWithGlyph(fontName: String, glyph: CGGlyph) -> CGGlyph {
    return STTextSubstitutionGlyph.verticalSubstitutionGlyphWithGlyph(fontName: fontName, glyph: glyph)
}
