/*
STTextSubstitutionGlyph.h

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center. All rights reserved.
This software is licensed under the MIT License. See LICENSE for details.
*/

#include <TargetConditionals.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#else
#import <Cocoa/Cocoa.h>
#endif

CGGlyph STTextVerticalSubstitutionGlyphWithGlyph(NSString* fontName, CGGlyph glyph);
