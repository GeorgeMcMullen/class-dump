//
//  CDHeaderIndex.h
//  code-dump
//
//  Created by Braden Thomas on 10/22/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CDSymbol.h"

@interface CDHeaderIndex : NSObject <NSCoding> {
	NSMutableArray* xmlDocuments;
	NSMutableDictionary* subclasses;
}

- (void)addHeaderData:(NSString*)data;
- (void)addSubclassData:(NSString*)data;
- (NSXMLElement*)lookupSymbol:(CDSymbol*)sym;
- (NSDictionary*)lookupSelector:(NSDictionary*)sel;
- (NSString*)subclassOf:(NSString*)className;

@end
