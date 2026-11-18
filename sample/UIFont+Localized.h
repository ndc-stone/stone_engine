/*
UIFont+Localized.h

Author: Makoto Kinoshita (mkino@hmdt.jp)

Copyright 2024 Nihon Design Center.
This software is licensed under the MIT License. See LICENSE for details.
*/

#import <CoreText/CoreText.h>
#import <UIKit/UIKit.h>

@interface UIFont (UIFontEx)

+ (NSArray<NSString*>*)availableFamilyNames:(NSArray*)languages;

@end
