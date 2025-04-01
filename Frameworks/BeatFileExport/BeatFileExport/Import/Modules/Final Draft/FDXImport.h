//
//  FDXImport.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.1.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatFileExport/BeatImportModule.h>

@interface FDXImport : NSObject <BeatFileImportModule>

typedef NS_ENUM(NSInteger, FDXSectionType) {
	FDXSectionNone = 0,
	FDXSectionTitlePage,
	FDXSectionContent,
	FDXSectionNotes,
	FDXSectionTags,
    FDXSectionTagDefinitions,
};

@property (nonatomic, copy) void (^callback)(NSString*);

@property (nonatomic, strong) NSMutableArray *results;
@property (nonatomic, strong) NSMutableString *parsedString;
@property (nonatomic, strong) NSMutableString *resultScript;
 
@property (nonatomic, strong) NSMutableArray *script;
@property (nonatomic, strong) NSMutableArray *attrScript;

@property (nonatomic) NSString* errorMessage;

@property (nonatomic) NSString* fountain;

- (id)initWithURL:(NSURL*)url importNotes:(bool)importNotes completion:(void(^)(NSString*))callback;
- (id)initWithData:(NSData*)data importNotes:(bool)importNotes completion:(void(^)(NSString*))callback;
- (NSString*)scriptAsString;

@end
