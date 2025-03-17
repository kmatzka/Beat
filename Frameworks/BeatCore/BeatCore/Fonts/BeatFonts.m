//
//  BeatFonts.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 2.8.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//


#import "BeatFonts.h"
#import <TargetConditionals.h>

@interface BeatFonts ()
@property (nonatomic) NSMutableDictionary<NSNumber*, NSDictionary<NSString*, BeatFontSet*>*>* fonts;
@property (strong, nonatomic) NSMutableDictionary *sectionFonts;
@property (nonatomic) CGFloat size;
@end

@implementation BeatFonts

+ (BeatFonts*)forType:(BeatFontType)type
{
    BeatFonts* fonts;
    
    if (type == BeatFontTypeFixed) fonts = BeatFonts.sharedFonts;
    else if (type == BeatFontTypeFixedSansSerif) fonts = BeatFonts.sharedSansSerifFonts;
    else if (type == BeatFontTypeVariableSerif) fonts = BeatFonts.sharedVariableFonts;
    else if (type == BeatFontTypeVariableSansSerif) fonts = BeatFonts.sharedVariableSansSerifFonts;
    
    return fonts;
}

/// Modern singleton for supporting the new font system
+ (BeatFonts*)shared
{
    static BeatFonts* sharedInstance;
    
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [BeatFonts.alloc init];
    });
    
    return sharedInstance;
}

+ (BeatFonts*)sharedFonts
{
    static dispatch_once_t once;
    static BeatFonts* sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] initWithFontType:BeatFontTypeFixed];
    });
    return sharedInstance;
}

/// Creates a set of fonts with given scale, stored in a two-dimensional array (type -> scale)
+ (BeatFonts*)sharedFontsWithScale:(CGFloat)scale type:(BeatFontType)type
{
    static NSMutableDictionary<NSNumber*, NSMutableDictionary<NSNumber*, BeatFonts*>*>* scaledFonts;
    if (scaledFonts == nil) scaledFonts = NSMutableDictionary.new;
    
    if (scaledFonts[@(type)] == nil) scaledFonts[@(type)] = NSMutableDictionary.new;
    NSMutableDictionary* scaledFontSet = scaledFonts[@(type)];
    
    if (scaledFontSet[@(scale)] == nil) {
        scaledFontSet[@(scale)] = [[self alloc] initWithFontType:type size:12.0 scale:scale];
    }
    
    return scaledFonts[@(type)][@(scale)];
}

+ (BeatFonts*)sharedSansSerifFonts {
    static dispatch_once_t once;
    static BeatFonts* sharedSansSerifInstance;
    dispatch_once(&once, ^{
        sharedSansSerifInstance = [[self alloc] initWithFontType:BeatFontTypeFixedSansSerif];
    });
    return sharedSansSerifInstance;
}

+ (BeatFonts*)sharedVariableFonts {
    static dispatch_once_t once;
    static BeatFonts* sharedVariableInstance;
    dispatch_once(&once, ^{
        sharedVariableInstance = [[self alloc] initWithFontType:BeatFontTypeVariableSerif];
    });
    return sharedVariableInstance;
}

+ (BeatFonts*)sharedVariableSansSerifFonts {
    static dispatch_once_t once;
    static BeatFonts* sharedVariableSansSerifInstance;
    dispatch_once(&once, ^{
        sharedVariableSansSerifInstance = [[self alloc] initWithFontType:BeatFontTypeVariableSansSerif];
    });
    return sharedVariableSansSerifInstance;
}

- (instancetype)init
{
    self = [super init];
    return self;
}

- (instancetype)initWithFontType:(BeatFontType)type
{
    return [self initWithFontType:type size:12.0 scale:1.0];
}

- (instancetype)initWithFontType:(BeatFontType)type size:(CGFloat)size scale:(CGFloat)scale
{
    self = [super init];
    
    if (self) {
        self.size = size * scale;
        
        // Set these first. Families can override them if needed.
        self.synopsisFont = [self fontWithTrait:BXFontDescriptorTraitItalic font:[BXFont systemFontOfSize:_size - 1.0]];
        self.sectionFont = [BXFont boldSystemFontOfSize:17.0 * scale];
        
        if (type == BeatFontTypeFixed) [self loadSerifFont];
        else if (type == BeatFontTypeFixedSansSerif) [self loadSansSerifFont];
        else if (type == BeatFontTypeVariableSerif) [self loadVariableFont];
        else if (type == BeatFontTypeVariableSansSerif) [self loadVariableSansSerifFont];
        else if (type == BeatFontTypeLibertinus) [self loadLibertinusFont];
        
        self.emojis = [BXFont fontWithName:@"Noto Emoji" size:_size];
        if (_emojis == nil) self.emojis = [BXFont fontWithName:@"NotoEmoji" size:_size]; // Fix for Mojave
        
        self.scale = scale;
    }
    
    return self;
}


#pragma mark - New font system (experimental)

- (void)setFont:(BeatFontSet*)font
{
    self.regular = font.regular;
    self.bold = font.bold;
    self.italic = font.italic;
    self.sectionFont = font.section;
    self.synopsisFont = font.synopsis;
    self.emojis = font.emojiFont;
}

- (void)loadFontsWithScale:(CGFloat)scale
{
    self.fonts[@(scale)] = @{
        @"serif": [BeatFontSet
                   name:@"Fixed Serif"
                   size: 12.0
                   scale: scale
                   regular:([BXFont fontWithName:@"Courier Prime" size:_size] != nil) ? @"Courier Prime" : @"CourierPrime"
                   bold:@"CourierPrime-Bold"
                   italic:@"CourierPrime-Italic"
                   boldItalic:@"CourierPrime-BoldItalic"
                   sectionFont:nil synopsisFont:nil],
        
        @"sans serif": [BeatFontSet
                        name:@"Fixed Sans Serif"
                        size: 12.0
                        scale: scale
                        regular:([BXFont fontWithName:@"Courier Prime Sans" size:_size] != nil) ? @"Courier Prime Sans" : @"CourierPrimeSans"
                        bold:@"CourierPrimeSans-Bold"
                        italic:@"CourierPrimeSans-Italic"
                        boldItalic:@"CourierPrimeSans-BoldItalic"
                        sectionFont:nil synopsisFont:nil],
        
        @"variable serif": [BeatFontSet
                      name:@"Variable Serif"
                      size: 12.0
                      scale: scale
                      regular:@"Times New Roman"
                      bold:@"Times New Roman Bold"
                      italic:@"Times New Roman Italic"
                      boldItalic:@"Times New Roman Bold Italic"
                      sectionFont:@"Times New Roman Bold Italic"
                      synopsisFont:nil],
        
        @"variable sans serif": [BeatFontSet
                      name:@"Variable Sans Serif"
                      size: 12.0
                      scale: scale
                      regular:@"Helvetica"
                      bold:@"Helvetica Bold"
                      italic:@"Helvetica Oblique"
                      boldItalic:@"Helvetica Bold Oblique"
                      sectionFont:@"Helvetica Bold Italic"
                      synopsisFont:nil]
    };
}

#pragma mark - macOS fonts
/*
 
 I used to have a more clever approach:
 self.bold = [self fontWithTrait:BXFontDescriptorTraitBold];
 self.italic = [self fontWithTrait:BXFontDescriptorTraitItalic];
 self.boldItalic = [self fontWithTrait:BXFontDescriptorTraitBold | BXFontDescriptorTraitItalic];

 However, this caused *extremely* weird issues on Mojave, such as the fonts transforming into something
 completely different. We'll use hard-coded font names, instead.
 
 */

- (void)loadSerifFont
{
    self.name = @"Fixed Serif";
	self.regular = [BXFont fontWithName:@"Courier Prime" size:_size];
    // This is a fix for some systems
    if (_regular == nil) self.regular = [BXFont fontWithName:@"CourierPrime" size:_size];
    
    self.bold = [BXFont fontWithName:@"CourierPrime-Bold" size:_size];
    self.italic = [BXFont fontWithName:@"CourierPrime-Italic" size:_size];
    self.boldItalic = [BXFont fontWithName:@"CourierPrime-BoldItalic" size:_size];
}

- (void)loadSansSerifFont
{
    self.name = @"Fixed Sans Serif";
    self.regular = [BXFont fontWithName:@"Courier Prime Sans" size:_size];
    // This is a fix for some systems
    if (_regular == nil) self.regular = [BXFont fontWithName:@"CourierPrimeSans-Regular" size:_size];
    
    self.bold = [BXFont fontWithName:@"CourierPrimeSans-Bold" size:_size];
    self.italic = [BXFont fontWithName:@"CourierPrimeSans-Italic" size:_size];
    self.boldItalic = [BXFont fontWithName:@"CourierPrimeSans-BoldItalic" size:_size];
}

- (void)loadVariableFont
{
    self.name = @"Variable Serif";
    self.regular = [BXFont fontWithName:@"Times New Roman" size:_size];
    self.bold = [BXFont fontWithName:@"Times New Roman Bold" size:_size];
    self.italic = [BXFont fontWithName:@"Times New Roman Italic" size:_size];
    self.boldItalic = [BXFont fontWithName:@"Times New Roman Bold Italic" size:_size];
    
    self.sectionFont = [BXFont fontWithName:@"Times New Roman Bold Italic" size:_size * 1.34];
}

- (void)loadVariableSansSerifFont
{
    self.name = @"Variable Sans Serif";
    self.regular = [BXFont fontWithName:@"Helvetica" size:_size];
    self.bold = [BXFont fontWithName:@"Helvetica Bold" size:_size];
    self.italic = [BXFont fontWithName:@"Helvetica Oblique" size:_size];
    self.boldItalic = [BXFont fontWithName:@"Helvetica Bold Oblique" size:_size];
}

- (void)loadLibertinusFont
{
    self.name = @"Libertinus";
    self.regular = [BXFont fontWithName:@"LibertinusSerif-Regular" size:_size];
    self.bold = [BXFont fontWithName:@"LibertinusSerif-Bold" size:_size];
    self.italic = [BXFont fontWithName:@"LibertinusSerif-Italic" size:_size];
    self.boldItalic = [BXFont fontWithName:@"LibertinusSerif-BoldItalic" size:_size];
    self.sectionFont = [BXFont fontWithName:@"LibertinusSerif-BoldItalic" size:_size];
}

- (BXFont*)fontWithTrait:(BXFontDescriptorSymbolicTraits)traits
{
	return [self fontWithTrait:traits font:self.regular];
}

- (BXFont*)fontWithTrait:(BXFontDescriptorSymbolicTraits)traits font:(BXFont*)originalFont
{
    return [BeatFonts fontWithTrait:traits font:originalFont];
}

+ (BXFont*)fontWithTrait:(BXFontDescriptorSymbolicTraits)traits font:(BXFont*)originalFont
{
    BXFontDescriptor *fd = [originalFont.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
    BXFont *font = [BXFont fontWithDescriptor:fd size:originalFont.pointSize];
    
    if (font == nil) return originalFont;
    else return font;
}

- (BXFont*)boldWithSize:(CGFloat)size {
	BXFont* f = [BXFont fontWithName:self.regular.fontName size:size];
	f = [self fontWithTrait:BXFontDescriptorTraitBold font:f];
	return f;
}
- (BXFont*)withSize:(CGFloat)size {
	BXFont* f = [BXFont fontWithName:self.regular.fontName size:size];
	return f;
}

- (BXFont*)sectionFontWithSize:(CGFloat)size
{
    // Init dictionary if it's unset
    if (!_sectionFonts) _sectionFonts = NSMutableDictionary.new;
    
    // We'll store fonts of varying sizes on the go, because why not?
    // No, really, why shouldn't we?
    NSString *sizeKey = [NSString stringWithFormat:@"%f", size];
    
    if (!_sectionFonts[sizeKey]) {
        #if TARGET_OS_IOS
            // There's a weird bug in iOS with system fonts
            BXFont* font;
            if ([_sectionFont.familyName isEqualToString:[BXFont systemFontOfSize:12.0].familyName]) {
                font = [BXFont boldSystemFontOfSize:size];
            } else {
                font = [BXFont fontWithName:_sectionFont.fontName size:size];
            }
        #else
            // On macOS we can jsut use the normal system font name
            BXFont* font = [BXFont fontWithName:_sectionFont.fontName size:size];
        #endif
        
        // Store to dict
        [_sectionFonts setValue:font forKey:sizeKey];
    }
    
    return (BXFont*)_sectionFonts[sizeKey];
}

+ (CGFloat)characterWidth {
	return 7.25;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Font Set: %@", self.name];
}

@end
