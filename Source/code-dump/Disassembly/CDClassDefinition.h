//
//  CDClassDefinition.h
//  code-dump
//
//  Created by Braden Thomas on 10/24/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface CDClassDefinition : NSObject {
	NSString* className;
	NSString* category;
	NSString* superClass;
	NSMutableSet* protocols;
	NSMutableArray* ivars;
	NSMutableSet* methods;
}

- (id)initWithClassName:(NSString*)className;
- (void)setCategory:(NSString*)cat;
- (void)setSuperClass:(NSString*)superc;
- (void)addProtocol:(NSString*)protocol;
- (void)addIvarOfType:(NSString*)type andName:(NSString*)name isPublic:(BOOL)pub;
- (void)addMethodSignature:(NSString*)signature;
- (NSString*)description;

@end
