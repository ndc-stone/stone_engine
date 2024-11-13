/*
UIFont+Localized.h

Author: Miho Kuroda, Makoto Kinoshita

Copyright 2016 HMDT. All rights reserved.
*/

#import <CoreText/CoreText.h>
#import <UIKit/UIKit.h>

@interface UIFont (UIFontEx)

+ (NSArray<NSString*>*)availableFamilyNames:(NSArray*)languages;
+ (NSString*)localizedFamilyName:(NSString*)familyName language:(NSString*)language;
+ (NSString*)localizedFontName:(NSString*)fontName language:(NSString*)language;

@end
