/*
UIFont+Localized.m

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center. All rights reserved.
This software is licensed under the MIT License. See LICENSE for details.
*/

#import "UIFont+Localized.h"

@implementation UIFont (UIFontEx)

+ (NSArray<NSString*>*)availableFamilyNames:(NSArray*)languages {
    // Get family names
    NSArray* familyNames = [UIFont familyNames];
    familyNames = [familyNames sortedArrayUsingSelector:@selector(compare:)];
    
    // Collect available family names
    NSMutableArray* localizedNames = [NSMutableArray array];
    for (NSString* familyName in familyNames) {
        // Create descriptor
        CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithNameAndSize((CFStringRef)familyName, 12.0);
        if (!descriptor) { continue; }
        
        // Get languages
        NSArray* fontLanguages = CFBridgingRelease(CTFontDescriptorCopyAttribute(descriptor, kCTFontLanguagesAttribute));
        
        // Check availability
        BOOL isContained = NO;
        for (NSString* language in languages) {
            if ([fontLanguages containsObject:language]) {
                isContained = YES;
                break;
            }
        }
        if (!isContained) continue;
        
        // Add family name
        [localizedNames addObject:familyName];
    }
    
    return localizedNames;
}

+ (NSString*)localizedFamilyName:(NSString*)familyName language:(NSString*)language {
    // Create descriptor
    CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithNameAndSize((CFStringRef)familyName, 12.0);
    if (!descriptor) {
        return familyName;
    }
    
    // Get localized family name
    CFStringRef lang = CFStringCreateCopy(NULL, (CFStringRef)language);
    NSString* localizedName = CFBridgingRelease(CTFontDescriptorCopyLocalizedAttribute(descriptor, kCTFontFamilyNameAttribute, &lang));
    if (!localizedName) {
        return familyName;
    }
    
    return localizedName;
}

+ (NSString*)localizedFontName:(NSString*)fontName language:(NSString*)language {
    // Create descriptor
    CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithNameAndSize((CFStringRef)fontName, 12.0);
    if (!descriptor) {
        return fontName;
    }
    
    // Get localized font name
    CFStringRef lang = CFStringCreateCopy(NULL, (CFStringRef)language);
    NSString* localizedName = CFBridgingRelease(CTFontDescriptorCopyLocalizedAttribute(descriptor, kCTFontDisplayNameAttribute, &lang));
    if (!localizedName) {
        return fontName;
    }
    
    return localizedName;
}

@end
