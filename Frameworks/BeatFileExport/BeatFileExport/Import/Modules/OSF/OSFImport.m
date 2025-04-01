//
//  OSFImport.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 17.7.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

/**
 
 Simple import plugin for Open Screenplay Format (XML) files. Misses a lot of features.
 
 */

#import "OSFImport.h"
#import <BeatCore/BeatRevisions.h>

@interface OSFImport () <NSXMLParserDelegate>
@property(nonatomic, strong) NSXMLParser *xmlParser;
@property (nonatomic) bool paragraph;
@property (nonatomic) NSDictionary *paraProperties;
@property (nonatomic) NSDictionary *textProperties;

@property(nonatomic, strong) NSMutableArray *results;
@property (nonatomic, strong) NSMutableArray<NSAttributedString*>* titlePageElements;
@property(nonatomic, strong) NSMutableString *parsedString;
@property(nonatomic, strong) NSMutableString *resultScript;

@property(nonatomic) bool contentFound;
@property(nonatomic) bool titlePage;
@property(nonatomic, strong) NSString *lastFoundElement;
@property(nonatomic, strong) NSMutableAttributedString *lastFoundString;
@property(nonatomic, strong) NSMutableAttributedString *lastAddedLine;
@property(nonatomic, strong) NSString *style;
@property(nonatomic, strong) NSMutableAttributedString *elementText;
@property(nonatomic, strong) NSMutableAttributedString *paragraphText;
@property(nonatomic, strong) NSMutableArray <NSAttributedString*>* scriptLines;
@property(nonatomic) NSUInteger dualDialogue;

@end

@implementation OSFImport

+ (bool)asynchronous { return true; }

- (id)initWithURL:(NSURL*)url options:(NSDictionary* _Nullable)options completion:(void(^ _Nullable)(NSString*))callback
{
    return [self initWithURL:url completion:callback];
}

+ (NSArray<NSString *> * _Nullable)UTIs { return nil; }
+ (NSArray<NSString *> * _Nonnull)formats { return @[@"osf"]; }


- (id)initWithData:(NSData*)data
{
	// Parsing with just data does not need a callback, we can do everything in sync
    // 2024 edit: Why? Is this true for iOS as well?
	self = [super init];
	if (self) {
		[self parse:data];
	}
	return self;
}

- (id)initWithURL:(NSURL*)url completion:(void(^)(NSString* _Nullable))callback
{
	// Parsing a URL request needs a completion callback
	
#if TARGET_OS_OSX
	self = [super init];
	if (self) {
		// Thank you, RIPtutorial
		// Fetch xml data
		NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
		
		NSURLSessionDataTask *task = [session dataTaskWithRequest:[NSURLRequest requestWithURL:url] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
			// After the data has loaded, parse the file & return to callback
			[self parse:data];
			if (callback != nil) callback(self.fountain);
		}];
			
		[task resume];
	}
    return self;
#else
    // You can't do that on iOS for some reason, and you can't do this on macOS:
    NSError* error;
    NSString* string = [NSString.alloc initWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
    NSData* data = [string dataUsingEncoding:NSUTF8StringEncoding];
    
    if (error != nil) {
        self.errorMessage = [NSString stringWithFormat:@"%@", error];
    }
    
    [self parse:data];
    callback(self.fountain);
#endif
    return self;
}

- (void)parse:(NSData*)data
{
	_elementText = NSMutableAttributedString.new;
	_paragraphText = NSMutableAttributedString.new;
	_scriptLines = NSMutableArray.new;
	_titlePageElements = NSMutableArray.new;
	_titlePage = NO;
	_dualDialogue = -1;
	
	self.xmlParser = [[NSXMLParser alloc] initWithData:data];
	self.xmlParser.delegate = self;
	if ([self.xmlParser parse]) {
		self.script = [self scriptAsString];
	}
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(nullable NSString *)namespaceURI qualifiedName:(nullable NSString *)qName attributes:(NSDictionary<NSString *, NSString *> *)attributeDict{
	_lastFoundElement = elementName;
	
	// Fade In (sometimes) uses lower-case attribute & element names, while
	// OSF documentation explicitly specifies camel case, ie. "sceneNumber" vs "scenenumber".
	// So fuck everything, let's create a new dictionary out of the attributes
	// with lowercase counterparts. Style names are correctly capitalized, though.
	
	elementName = elementName.lowercaseString;
	NSMutableDictionary *attributes = NSMutableDictionary.new;
	
	for (id key in attributeDict) {
		[attributes setValue:[attributeDict objectForKey:key] forKey:[key lowercaseString]];
	}
	
	if ([elementName isEqualToString:@"paragraphs"]) {
		_contentFound = YES;
		_titlePage = NO;
	}
	else if ([elementName isEqualToString:@"text"]) {
		_textProperties = attributes;
	}
	else if ([elementName isEqualToString:@"titlepage"]) {
		_titlePage = YES;
	}
	else if ([elementName isEqualToString:@"para"]) {
		_paraProperties = attributes;
		_paragraph = YES;
		_elementText = NSMutableAttributedString.new;
	}
	else if ([elementName isEqualToString:@"style"]) {
		if (attributes[@"basestylename"]) _style = ((NSString*)attributes[@"basestylename"]).lowercaseString;
		if (attributes[@"basestyle"]) _style = ((NSString*)attributes[@"basestyle"]).lowercaseString;
		
		if (attributes[@"synopsis"]) {
			// Add synopsis to script
			[_scriptLines addObject:NSAttributedString.new];
			[_scriptLines addObject:[NSAttributedString.alloc initWithString:[NSString stringWithFormat:@"\n= %@", attributes[@"synopsis"]]]];
		}
		
		if ([_style isEqualToString:@"character"]) {
			if (_dualDialogue > 0) _dualDialogue += 1;
			if (_dualDialogue > 2) _dualDialogue = 0;
		}
		else if ([_style isEqualToString:@"dialogue"]) {
			if (_dualDialogue == 2) _dualDialogue = 0;
		}
		
		if (attributes[@"dualdialogue"]) {
			// Start dual dialogue
			_dualDialogue = 1;
		}
	}
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string{
	if (_contentFound || _titlePage) {
		NSMutableAttributedString* attrString;
		
		if ([_lastFoundElement isEqualToString:@"text"]) {
			// Create attributed string
			attrString = [NSMutableAttributedString.alloc initWithString:string];
			if (_textProperties[@"revision"] != nil) {
				NSInteger generation = [(NSString*)_textProperties[@"revision"] integerValue] - 1;
				if (generation >= BeatRevisions.revisionGenerations.count) generation = BeatRevisions.revisionGenerations.count - 1;
				
				BeatRevisionItem* revision = [BeatRevisionItem type:RevisionAddition generation:generation];
				[attrString addAttribute:BeatRevisions.attributeKey value:revision range:NSMakeRange(0, attrString.length)];
			}
		}
		else {
			string = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			attrString = [NSMutableAttributedString.alloc initWithString:string];
		}
		
		// Save the string for later use
		[_elementText appendAttributedString:attrString];
	}
}

- (bool)isFirstCharacterSpace:(NSString*)string {
	if (string.length > 0) {
		if ([[string substringWithRange:NSMakeRange(0, 1)] isEqualToString:@" "]) return YES;
		else return NO;
	} else {
		return NO;
	}
}
- (bool)isLastCharacterSpace:(NSString*)string {
	if (string.length > 1) {
		if ([[string substringWithRange:NSMakeRange(string.length - 1, 1)] isEqualToString:@" "]) return YES;
		else return NO;
	} else {
		if ([string isEqualToString:@" "]) return YES;
		else return NO;
	}
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(nullable NSString *)namespaceURI qualifiedName:(nullable NSString *)qName{
	elementName = elementName.lowercaseString;
	
	if ([elementName isEqualToString:@"text"]) {
		//if (![self isLastCharacterSpace:_elementText]) _elementText = [NSMutableString stringWithString:[_elementText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
					
		// Add inline formatting
		NSMutableString* left = NSMutableString.new;
		NSMutableString* right = NSMutableString.new;
		
        bool isSlug = [_style isEqualToString:@"scene heading"] || [_style isEqualToString:@"shot"];
        
        if ([_textProperties[@"bold"] isEqualToString:@"1"] && !isSlug) {
			[left appendString:@"**"];
			[right insertString:@"**" atIndex:0];
		}
		if ([_textProperties[@"italic"] isEqualToString:@"1"]) {
			[left appendString:@"*"];
			[right insertString:@"*" atIndex:0];
		}
		if ([_textProperties[@"underline"] isEqualToString:@"1"]) {
			[left appendString:@"_"];
			[right insertString:@"_" atIndex:0];
		}
		
		[_elementText insertAttributedString:[NSAttributedString.alloc initWithString:left] atIndex:0];
		[_elementText appendAttributedString:[NSAttributedString.alloc initWithString:right]];
			
		[_paragraphText appendAttributedString:_elementText];
		
		_elementText = NSMutableAttributedString.new;
		_lastFoundElement = @"";
		//[_elementText appendString:@" "];
	}
	else if ([elementName isEqualToString:@"para"]) {
		NSMutableAttributedString* result = _paragraphText.mutableCopy;
		
		// Add empty rows before required elements.
		if (_scriptLines.count > 0) {
			NSAttributedString *previousLine = _scriptLines.lastObject;
			
			if (previousLine.length > 0 && _paragraphText.length > 0) {
				if ([_style isEqualToString:@"character"] ||
					[_style isEqualToString:@"scene heading"] ||
					[_style isEqualToString:@"action"] ||
					[_style isEqualToString:@"left column"] ||
					[_style isEqualToString:@"rigth column"] ||
					[_style isEqualToString:@"shot"] ||
					[_style isEqualToString:@"transition"]) {
					[_scriptLines addObject:NSAttributedString.new];
				}
			}
		}
		
		if ([_style isEqualToString:@"scene heading"]) {
            [result.mutableString setString:[self sceneHeadingFrom:result.string.uppercaseString]];
			
			// Force scene prefix if there is none and the style is scene heading anyway
			if ([result.string rangeOfString:@"INT"].location != 0 &&
				[result.string rangeOfString:@"EXT"].location != 0 &&
				[result.string rangeOfString:@"I./E"].location != 0 &&
				[result.string rangeOfString:@"E./I"].location != 0
			) {
				[result insertAttributedString:[NSAttributedString.alloc initWithString:@"."] atIndex:0];
			}
			
			if (_paraProperties[@"scenenumber"]) {
				NSString* sceneNumber = [NSString stringWithFormat:@" #%@#", _paraProperties[@"scenenumber"]];
				[result appendAttributedString:[NSAttributedString.alloc initWithString:sceneNumber]];
			}
		}
		else if ([_style isEqualToString:@"lyrics"]) {
			NSAttributedString* f = [NSAttributedString.alloc initWithString:@"~"];
			[result insertAttributedString:f atIndex:0];
			[result appendAttributedString:f];
		}
		if ([_style isEqualToString:@"character"]) {
			if (_dualDialogue == 2) {
				NSAttributedString* f = [NSAttributedString.alloc initWithString:@"^"];
				[result appendAttributedString:f];
				_dualDialogue = 0;
			}
			[result.mutableString setString:result.string.uppercaseString];
			
			// Force character if it's under 4 letters (like LI or PO)
			//if (result.length < 4) result = [NSString stringWithFormat:@"@%@", result];
		}
		else if ([_style isEqualToString:@"transition"]) {
			NSAttributedString* f = [NSAttributedString.alloc initWithString:@"> "];
			[result insertAttributedString:f atIndex:0];
		}
		else if ([_style isEqualToString:@"shot"]) {
			NSAttributedString* f = [NSAttributedString.alloc initWithString:@"!! "];
			[result insertAttributedString:f atIndex:0];
		}
		
		if (_paraProperties[@"alignment"]) {
			if ([_paraProperties[@"alignment"] isEqualToString:@"right"]) {
				NSAttributedString* f = [NSAttributedString.alloc initWithString:@"> "];
				[result insertAttributedString:f atIndex:0];
			}
			else if ([_paraProperties[@"alignment"] isEqualToString:@"center"]) {
				NSAttributedString* f = [NSAttributedString.alloc initWithString:@">"];
				NSAttributedString* f2 = [NSAttributedString.alloc initWithString:@"<"];
				[result insertAttributedString:f atIndex:0];
				[result appendAttributedString:f2];
			}
		}
		
		// Add () for parentheticals
		if ([_style isEqualToString:@"parenthetical"]) {
			[result.mutableString setString:[result.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
			NSAttributedString* f = [NSAttributedString.alloc initWithString:@"("];
			NSAttributedString* f2 = [NSAttributedString.alloc initWithString:@")"];
			[result insertAttributedString:f atIndex:0];
			[result appendAttributedString:f2];
		}
		
		// Add object
		if ([result.string isEqualToString:@""] && [_lastAddedLine.string isEqualToString:@""]) {
			// Do nothing for now
		} else {
			// For title pages we append the correct param name first
			if (_titlePage) {
				if (_paraProperties[@"bookmark"]) {
					NSString *bookmark = _paraProperties[@"bookmark"];
					NSString *prefix;
					if ([bookmark isEqualToString:@"title"]) prefix = @"Title";
					else if ([bookmark isEqualToString:@"author"]) prefix = @"Author";
					else if ([bookmark isEqualToString:@"draft"]) prefix = @"Draft date";
					else if ([bookmark isEqualToString:@"contact"]) prefix = @"Contact";
					
					// Only add KNOWN title page elements
					if (prefix.length && result.length) {
						NSString* titleLine = [NSString stringWithFormat:@"%@: %@", prefix, result];
						NSAttributedString* titlePageItem = [NSAttributedString.alloc initWithString:titleLine];
						[_titlePageElements addObject:titlePageItem];
					}
				}
			} else {
				[_scriptLines addObject:result];
			}
			_lastAddedLine = result;
		}
		
		_paragraphText = NSMutableAttributedString.new;
	}
	
	// Start & end sections
	if ([elementName isEqualToString:@"titlepage"]) {
		// Add a separator line
		[_titlePageElements addObject:NSMutableAttributedString.new];
		_titlePage = NO;
	}
    if ([elementName isEqualToString:@"paragraphs"]) {
		_contentFound = NO;
    }
}

/// Extract scene number from the heading if needed.
- (NSString*)sceneHeadingFrom:(NSString*)input
{
    NSError *error = nil;
    // Strip away number from a line like "123. Int. My heading" and add it at the end
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^(\\d+)\\.\\s" options:0 error:&error];

    NSTextCheckingResult *match = [regex firstMatchInString:input options:0 range:NSMakeRange(0, input.length)];
    if (match) {
        NSRange numberRange = [match rangeAtIndex:1]; // Captures the number before the dot
        NSString *sceneNumber = [[input substringWithRange:numberRange] stringByReplacingOccurrencesOfString:@"." withString:@""];
        
        // Strip the number, dot, and space
        NSString *strippedString = [input stringByReplacingCharactersInRange:[match range] withString:@""];
        NSString* heading = [NSString stringWithFormat:@"%@ #%@#", strippedString, sceneNumber];

        return heading;
    } else {
        return input;
    }
    
}

- (NSString*)scriptAsString {
	if (_scriptLines.count) {
		if (_titlePageElements.count) {
			_scriptLines = [NSMutableArray arrayWithArray:[_titlePageElements arrayByAddingObjectsFromArray:_scriptLines]];
		}
		
		NSMutableAttributedString* result = NSMutableAttributedString.new;
		for (NSAttributedString* string in _scriptLines) {
			[result appendAttributedString:string];
			[result appendAttributedString:[NSAttributedString.alloc initWithString:@"\n"]];
		}
		
		NSDictionary* revisions = [BeatRevisions rangesForSaving:result];
		BeatDocumentSettings* settings = BeatDocumentSettings.new;
		NSString* settingsString = [settings getSettingsStringWithAdditionalSettings:@{
			DocSettingRevisions: revisions
		}];
		
		NSMutableString* resultString = result.string.mutableCopy;
		[resultString appendFormat:@"\n\n%@", settingsString];
		
		return resultString;
	}
	return @"";
}

- (NSString *)fountain
{
    return self.scriptAsString;
}

@end
