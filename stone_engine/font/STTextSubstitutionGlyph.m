/*
STTextSubstitutionGlyph.m

Author: Makoto Kinoshita

Copyright 2010 HMDT. All rights reserved.
*/

#import "STTextSubstitutionGlyph.h"

// Script tags
#define TAG_cyrl (('c' << 24) | ('y' << 16) | ('r' << 8) | 'l')
#define TAG_grek (('g' << 24) | ('r' << 16) | ('e' << 8) | 'k')
#define TAG_hani (('h' << 24) | ('a' << 16) | ('n' << 8) | 'i')
#define TAG_kana (('k' << 24) | ('a' << 16) | ('n' << 8) | 'a')
#define TAG_latn (('l' << 24) | ('a' << 16) | ('t' << 8) | 'n')

#define TAG_aalt (('a' << 24) | ('a' << 16) | ('l' << 8) | 't')
#define TAG_jp78 (('j' << 24) | ('p' << 16) | ('7' << 8) | '8')
#define TAG_jp83 (('j' << 24) | ('p' << 16) | ('8' << 8) | '3')
#define TAG_jp90 (('j' << 24) | ('p' << 16) | ('9' << 8) | '0')
#define TAG_jp04 (('j' << 24) | ('p' << 16) | ('0' << 8) | '4')
#define TAG_nlck (('n' << 24) | ('l' << 16) | ('c' << 8) | 'k')
#define TAG_trad (('t' << 24) | ('r' << 16) | ('a' << 8) | 'd')
#define TAG_vert (('v' << 24) | ('e' << 16) | ('r' << 8) | 't')
#define TAG_vkna (('v' << 24) | ('k' << 16) | ('n' << 8) | 'a')
#define TAG_vrt2 (('v' << 24) | ('r' << 16) | ('t' << 8) | '2')

CGGlyph _substityteGlyphIdWithLookupSubtable(int lookupType, const UInt8* subTablePtr, CGGlyph glyph);
CGGlyph _substituteGlyph(NSString* fontName, UInt32 scriptTag, UInt32 featureTag, CGGlyph glyph);
void _setVerticalGlyphWithStrings(CTFontRef font, CGGlyph* glyphTable, NSString* normalStr, NSString* vertStr);

void printTag(int value) {
    printf("%c", value >> 24);
    printf("%c", (value & 0x00FF0000) >> 16);
    printf("%c", (value & 0x0000FF00) >> 8);
    printf("%c\n", (value & 0x000000FF));
}

//
// Read GSUB table, refer to http://www.microsoft.com/typography/otspec/gsub.htm
// and common table, refer to http://www.microsoft.com/typography/otspec/chapter2.htm
//

CGGlyph _substityteGlyphIdWithLookupSubtable(int lookupType, const UInt8* subTablePtr, CGGlyph glyph) {
    // Set sub table pointer
    const UInt8* tmp6 = subTablePtr;
    
    // Switch by lookup type
    switch (lookupType) {
    // Lookup type 1: Single Substitution Subtable
    // Lookup type 3: Single Substitution Subtable
    case 1:
    case 3:
    {
        // Read subst format
        UInt16 substFormat = OSReadBigInt16(tmp6, 0);
        tmp6 += 2;
        
        // Read coverage offset
        UInt16 coverageOffset = OSReadBigInt16(tmp6, 0);
        tmp6 += 2;
        
        // Read coverage table
        const UInt8* coverageTablePtr = subTablePtr + coverageOffset;
        const UInt8* tmp7 = coverageTablePtr;
        
        // Read coverage format
        UInt16 coverageFormat = OSReadBigInt16(tmp7, 0);
        tmp7 += 2;
        
        // Decide coverage index
        SInt16 coverageIndex = -1;
        
        // Switch by coverage format
        switch (coverageFormat) {
        // Coverage format 1: Individual glyph indices
        case 1: {
            // Read glyph count
            UInt16 glyphCount = OSReadBigInt16(tmp7, 0);
            tmp7 += 2;
            
            // Read glyph IDs
            for (int n = 0; n < glyphCount; n++) {
                // Read glyph ID
                CGGlyph glyphId = OSReadBigInt16(tmp7, 0);
                tmp7 += 2;
                
                // Check glyph
                if (glyph == glyphId) {
                    coverageIndex = n;
                    break;
                }
            }
            
            break;
        }
        // Coverage format 2: Range of glyphs
        case 2: {
            // Read range count
            UInt16 rangeCount = OSReadBigInt16(tmp7, 0);
            tmp7 += 2;
            
            // Read RangeRecords
            for (int n = 0; n < rangeCount; n++) {
                // Read RangeRecord
                CGGlyph startGlyphId = OSReadBigInt16(tmp7, 0);
                tmp7 += 2;
                CGGlyph endGlyphId = OSReadBigInt16(tmp7, 0);
                tmp7 += 2;
                UInt16 startCoverageIndex = OSReadBigInt16(tmp7, 0);
                tmp7 += 2;
                
                // Check glyph
                if (glyph >= startGlyphId && glyph <= endGlyphId) {
                    // Calc coverage index
                    coverageIndex = startCoverageIndex + (glyph - startGlyphId);
                }
            }
            
            break;
        }
        }
        
        // For lookup type 1
        if (lookupType == 1) {
            // Switch by subst format
            switch (substFormat) {
            // Subst format 1
            case 1: {
                // Read delta glyph ID
                UInt16 deltaGlyphId = 0;
                if (substFormat == 1) {
                    deltaGlyphId = OSReadBigInt16(tmp6, 0);
                    tmp6 += 2;
                }
                
                NSLog(@"Not implemented yet, subst format 1");
                
                break;
            }
            // Subst format 2
            case 2: {
                // Read glyph count
                UInt16 glyphCount = OSReadBigInt16(tmp6, 0);
                tmp6 += 2;
                
                // Check with coverage index
                if (coverageIndex == -1) return 0;
                if (coverageIndex > glyphCount) {
                    NSLog(@"Coverage index is larger than glyph count, coverageIndex %d, glyphCount %d", 
                            coverageIndex, glyphCount);
                    
                    return 0;
                }
                
                // Read substitute glyph ID at coverage index
                CGGlyph substGlyph = OSReadBigInt16(tmp6, coverageIndex * 2);
                
                return substGlyph;
            }
            }
        }
        
        // For lookup type 3
        else if (lookupType == 3) {
            // Read alternate set count
            UInt16 alternateSetCount = OSReadBigInt16(tmp6, 0);
            tmp6 += 2;
            
            // Check with coverage index
            if (coverageIndex == -1) return 0;
            if (coverageIndex > alternateSetCount) {
                NSLog(@"Coverage index is larger than alternate set count, coverageIndex %d, alternateSetCount %d", 
                        coverageIndex, alternateSetCount);
                
                return 0;
            }
            
            // Read alternate set table offset
            UInt16 alternateSetTableOffset = OSReadBigInt16(tmp6, coverageIndex * 2);
            
            // Read AlternateSet table
            const UInt8* alternateSetTablePtr = subTablePtr + alternateSetTableOffset;
            const UInt8* tmp7 = alternateSetTablePtr;
            
            // Read glyph count
            //UInt16 glyphCount = OSReadBigInt16(tmp7, 0);
            tmp7 += 2;
            
            // Read alternate glyph ID
            CGGlyph alternateGlyph = OSReadBigInt16(tmp7, 0);
            tmp7 += 2;
            
            // Add glyph ID
            return alternateGlyph;
        }
        
        break;
    }
    
    // Lookup type 7: Extension Substitution
    case 7: {
        // Read subst format
        //UInt16 substFormat = OSReadBigInt16(tmp6, 0);
        tmp6 += 2;
        
        // Read extension lookup type
        UInt16 extensionLookupType = OSReadBigInt16(tmp6, 0);
        tmp6 += 2;
        
        // Read extension offset
        UInt32 extensionOffset = OSReadBigInt32(tmp6, 0);
        tmp6 += 4;
        
        // Read sub table
        return _substityteGlyphIdWithLookupSubtable(extensionLookupType, subTablePtr + extensionOffset, glyph);
    }
    }
    
    return 0;
}

CGGlyph _substituteGlyph(NSString* fontName, UInt32 scriptTag, UInt32 featureTag, CGGlyph glyph) {
    static NSString* _prevFontName = nil;
    static CFDataRef _gsubTable = NULL;
    
    // For anthor font
    if (!_prevFontName || ![_prevFontName isEqualToString:fontName]) {
        // Set prev font name
        _prevFontName = fontName;
        
        // Create ctFont
        CTFontRef font = CTFontCreateWithName((CFStringRef)CFBridgingRetain(fontName), 18.0f, NULL);
        if (!font) {
            NSLog(@"Failed to create font with name, %@", fontName);
            
            return 0;
        }
        
        // Release old GUSB table
        if (_gsubTable) {
            CFRelease(_gsubTable);
            _gsubTable = NULL;
        }
        
        // Get GSUB table
        _gsubTable = CTFontCopyTable(font, kCTFontTableGSUB, kCTFontTableOptionNoOptions);
        if (!_gsubTable) {
            NSLog(@"Failed to get GSUB table");
            
            return 0;
        }
        
        // Release font
        CFRelease(font);
        font = NULL;
    }
    
    // Get root pointer
    if (!_gsubTable) return 0;
    const UInt8* rootPtr = CFDataGetBytePtr(_gsubTable);
    const UInt8* tmp = rootPtr;
    
    // Read GSUB header 
    tmp += 4; // Skip version
    UInt16 scriptListOffset = OSReadBigInt16(tmp, 0);
    tmp += 2;
    UInt16 featureListOffset = OSReadBigInt16(tmp, 0);
    tmp += 2;
    UInt16 lookupListOffset = OSReadBigInt16(tmp, 0);
    tmp += 2;
    
    // Read ScriptList table
    const UInt8* scriptListTalbePtr = rootPtr + scriptListOffset;
    UInt16 scriptListCount = OSReadBigInt16(scriptListTalbePtr, 0);
    
    // Read FeatureList table
    const UInt8* featureListTablePtr = rootPtr + featureListOffset;
    //UInt16 featureListCount = OSReadBigInt16(featureListTablePtr, 0);
    
    // Read LookupList table
    const UInt8* lookupListTablePtr = rootPtr + lookupListOffset;
    //UInt16 lookupListCount = OSReadBigInt16(lookupListTablePtr, 0);
    
    // Read ScriptRecords
    tmp = scriptListTalbePtr + 2;
    for (int i = 0; i < scriptListCount; i++) {
        // Read ScriptRecord tag
        UInt32 scriptRecordTag = OSReadBigInt32(tmp, 0);
        tmp += 4;
        
        // Read ScriptRecord offset
        UInt16 scriptRecordOffset = OSReadBigInt16(tmp, 0);
        tmp += 2;
        
        // Check script tag
        if (scriptTag != scriptRecordTag) continue;
        
        // Read Script table
        const UInt8* scriptTablePtr = scriptListTalbePtr + scriptRecordOffset;
        const UInt8* tmp2 = scriptTablePtr;
        UInt16 defaultLangSysOffset = OSReadBigInt16(tmp2, 0);
        tmp2 += 2;
        if (defaultLangSysOffset != 0) {
            // Read LangSys table
            const UInt8* langSysTablePtr = scriptTablePtr + defaultLangSysOffset;
            tmp2 = langSysTablePtr;
            tmp2 += 2; // Skip LookupOrder
            //UInt16 reqFeatureIndex = OSReadBigInt16(tmp2, 0);
            tmp2 += 2;
            UInt16 featureCount = OSReadBigInt16(tmp2, 0);
            tmp2 += 2;
            
            // Read feature FeatureList tables
            for (int j = 0; j < featureCount; j++) {
                // Read feature index
                UInt16 featureIndex = OSReadBigInt16(tmp2, 0);
                tmp2 += 2;
                
                // Read FeatureRecord
                const UInt8* featureRecordPtr = featureListTablePtr + 2 + featureIndex * 6;
                const UInt8* tmp3 = featureRecordPtr;
                
                // Read feature record tag
                UInt32 featureRecordTag = OSReadBigInt32(tmp3, 0);
                tmp3 += 4;
                
                // Read feature record offset
                UInt16 featureRecordOffset = OSReadBigInt16(tmp3, 0);
                tmp3 += 2;
                
                // Check feature tag
                if (featureTag != featureRecordTag) continue;
                
                // Read Feature table
                const UInt8* featureTablePtr = featureListTablePtr + featureRecordOffset;
                const UInt8* tmp4 = featureTablePtr;
                
                // Skip feature params
                tmp4 += 2;
                
                // Read lookup count
                UInt16 lookupCount = OSReadBigInt16(tmp4, 0);
                tmp4 += 2;
                
                // Read lookup list index
                for (int l = 0; l < lookupCount; l++) {
                    // Read lookup list index
                    UInt16 lookupListIndex = OSReadBigInt16(tmp4, 0);
                    tmp4 += 2;
                    
                    // Read lookup offset
                    UInt16 lookupOffset = OSReadBigInt16(lookupListTablePtr + 2, lookupListIndex * 2);
                    
                    // Read Lookup table
                    const UInt8* lookupTablePtr = lookupListTablePtr + lookupOffset;
                    const UInt8* tmp5 = lookupTablePtr;
                    
                    // Read lookup type
                    UInt16 lookupType = OSReadBigInt16(tmp5, 0);
                    tmp5 += 2;
                    
                    // Read lookup flag
                    //UInt16 lookupFlag = OSReadBigInt16(tmp5, 0);
                    tmp5 += 2;
                    
                    // Read sub table count
                    UInt16 subTableCount = OSReadBigInt16(tmp5, 0);
                    tmp5 += 2;
                    
                    // Read sub table offset
                    for (int m = 0; m < subTableCount; m++) {
                        // Read sub table offset
                        UInt16 subTableOffset = OSReadBigInt16(tmp5, 0);
                        tmp5 += 2;
                        
                        // Read sub table
                        const UInt8* subTablePtr = lookupTablePtr + subTableOffset;
                        //const UInt8* tmp6 = subTablePtr;
                        
                        // Read sub table
                        CGGlyph substGlyph = _substityteGlyphIdWithLookupSubtable(lookupType, subTablePtr, glyph);
                        if (substGlyph > 0) return substGlyph;
                    }
                    
                    // Skip mark filtering set
                    tmp5 += 2;
                }
                
                return 0;
            }
        }
    }
    
    return 0;
}

#define VERT_BUFFER_COUNT 16
static int          _vertNumber = 0;
static NSString*    _vertFontNames[VERT_BUFFER_COUNT];
static CGGlyph*     _vertGlyphs[VERT_BUFFER_COUNT];

void _setVerticalGlyphWithStrings(CTFontRef font, CGGlyph* glyphTable, NSString* normalStr, NSString* vertStr) {
    // Get normal glyph
    unichar normalUnichar;
    CGGlyph normalGlyph;
    [normalStr getCharacters:&normalUnichar range:NSMakeRange(0, 1)];
    CTFontGetGlyphsForCharacters(font, &normalUnichar, &normalGlyph, 1);
    if (normalGlyph == 0) {
        NSLog(@"Can't find glyph for %@", normalStr);
    }
    
    // Get vertical glyph
    unichar vertUnichar;
    CGGlyph vertGlyph;
    [vertStr getCharacters:&vertUnichar range:NSMakeRange(0, 1)];
    CTFontGetGlyphsForCharacters(font, &vertUnichar, &vertGlyph, 1);
    if (vertGlyph == 0) {
        NSLog(@"Can't find glyph for %@", vertStr);
    }
    
    // Set glyph
    if (normalGlyph != 0 && vertGlyph != 0) {
        *(glyphTable + normalGlyph) = vertGlyph;
    }
}

CGGlyph STTextVerticalSubstitutionGlyphWithGlyph(NSString* fontName, CGGlyph glyph) {
    // Find buffer index
    int i;
    for (i = 0; i < _vertNumber; i++) {
        if ([fontName isEqualToString:_vertFontNames[i]]) {
            break;
        }
    }
    
    //  For not found
    if (i == _vertNumber) {
        // Check count
        if (i >= VERT_BUFFER_COUNT) {
            NSLog(@"Exceed vert buffer count");
            
            return 0;
        }
        else {
            // Set font name
            _vertFontNames[i] = fontName;
            
            // Allocate glyph table
            _vertGlyphs[i] = malloc(sizeof(CGGlyph) * 65536);
            for (int j = 0; j < 65536; j++) {
                *(_vertGlyphs[i] + j) = 65535;
            }
            
            // Increment vert number
            _vertNumber++;
            
            //
            // Add special vertical glyphs, which has no vert values
            //
            
            // Create ctFont
            CTFontRef font = CTFontCreateWithName((CFStringRef)CFBridgingRetain(fontName), 18.0f, NULL);
            
            // Set vert glyphs
            _setVerticalGlyphWithStrings(font, _vertGlyphs[i], @"＜", @"︿");
            _setVerticalGlyphWithStrings(font, _vertGlyphs[i], @"＞", @"﹀");
            _setVerticalGlyphWithStrings(font, _vertGlyphs[i], @"－", @"｜");
            
            // Release font
            if (font) {
                CFRelease(font);
                font = NULL;
            }
        }
    }
    
    // Get glyph table
    CGGlyph* glyphTable = _vertGlyphs[i];
    
    // Check table
    if (*(glyphTable + glyph) == 65535) {
        // Get substitution glyph ID
        CGGlyph substGlyph = _substituteGlyph(fontName, TAG_kana, TAG_vrt2, glyph);
        if (substGlyph == 0) {
            substGlyph = _substituteGlyph(fontName, TAG_kana, TAG_vert, glyph);
        }
        if (substGlyph == 0) {
            substGlyph = _substituteGlyph(fontName, TAG_kana, TAG_vkna, glyph);
        }
        
        // Set substitution glyph ID
        *(glyphTable + glyph) = substGlyph;
    }
    
    // Get substitution glyph
    return *(glyphTable + glyph);
}
