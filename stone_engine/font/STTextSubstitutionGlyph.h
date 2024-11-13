/*
STTextSubstitutionGlyph.h

Author: Makoto Kinoshita

Copyright 2010 HMDT. All rights reserved.
*/

#include <TargetConditionals.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#else
#import <Cocoa/Cocoa.h>
#endif

CGGlyph STTextVerticalSubstitutionGlyphWithGlyph(NSString* fontName, CGGlyph glyph);
