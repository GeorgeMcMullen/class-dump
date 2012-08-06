//
//  CDRegVal.h
//  class-dump
//
//  Created by Braden Thomas on 4/8/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CDSymbol.h"

@interface CDRegVal : NSObject <NSCopying> {
	
	BOOL isSelf;
	BOOL isLineRef;
	BOOL valid;
	BOOL isDeRef;
	
	long value;
	NSUInteger lineRef;
	CDSymbol* symbol;
}

- (id)initWithSelf;
- (id)initWithValue:(long)value;
- (id)initWithLine:(NSUInteger)line;
- (id)initInvalid;
- (id)initWithSymbolDeRef:(CDSymbol*)symbol;

- (NSString*)description;

- (BOOL)isEqualTo:(CDRegVal*)b;

- (BOOL)data;
- (BOOL)deref;

@property(readonly) BOOL isLineRef;
@property(readonly) BOOL isSelf;
@property(readonly) BOOL valid;
//@property(readonly) BOOL data;
//@property(readonly) BOOL deref;
@property(readonly) CDSymbol* symbol;
@property(readonly) NSUInteger lineRef;
@property(readonly) long value;

@end
