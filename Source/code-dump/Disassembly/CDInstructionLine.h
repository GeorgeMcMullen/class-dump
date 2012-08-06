//
//  CDInstructionLine.h
//  code-dump
//
//  Created by Braden Thomas on 10/25/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface CDInstructionLine : NSObject {
	NSString* instruction;
	NSMutableArray* instructionComps;
	NSString* architecture;
	NSDictionary* lookupDict;
	NSNumber* offset;
}

- (id)initWithLine:(NSString*)disas andArchitecture:(NSString*)arch atOffset:(NSNumber*)offset;
- (BOOL)parseInstructionLine:(NSString*)line;
- (BOOL)isReturnInstruction;
- (NSDictionary*)populateLookupDict;
- (NSNumber*)offset;
- (NSString*)instruction;
- (NSArray*)instructionComps;
@end
