//
//  OSFImport.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 17.7.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatFileExport/BeatImportModule.h>

NS_ASSUME_NONNULL_BEGIN

@interface OSFImport : NSObject <BeatFileImportModule>
@property (nonatomic) NSString *script;
@property (nonatomic) NSString* fountain;
@property (nonatomic) NSString* errorMessage;
@property (nonatomic, copy) void (^callback)(NSString*);
- (id)initWithURL:(NSURL*)url completion:(void(^)(NSString* _Nullable))callback;
- (id)initWithData:(NSData*)data;

@end

NS_ASSUME_NONNULL_END
