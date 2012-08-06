//
//  CDInstructionLine.m
//  code-dump
//
//  Created by Braden Thomas on 10/25/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "CDInstructionLine.h"


@implementation CDInstructionLine

- (id)initWithLine:(NSString*)line andArchitecture:(NSString*)arch atOffset:(NSNumber*)off
{
	self = [super init];
	if (self != nil) {
		instructionComps = [[NSMutableArray alloc] init];
		[self parseInstructionLine:line];
		architecture = arch;
		lookupDict = [self populateLookupDict];
		offset = off;
	}
	return self;
}

- (BOOL)isEqual:(NSObject*)anObj
{
	if ([anObj isKindOfClass:[self class]]==NO)
		return NO;
	return [[self offset] isEqualToNumber:[(CDInstructionLine*)anObj offset]];
	
}

- (NSNumber*)offset
{
	return offset;
}

- (NSString*)instruction
{
	return instruction;
}

- (NSDictionary*)populateLookupDict
{
    //TODO: Popuplate the return instructions with the appropriate instructions for x86_64 and arm processors
	return [[NSDictionary alloc] initWithObjectsAndKeys:
				[[NSDictionary alloc] initWithObjectsAndKeys:
					[[NSArray alloc] initWithObjects:
						@"trap",
						@"blr",
						nil],
					@"ppc",
					[[NSArray alloc] initWithObjects:
						@"ret",nil],
					@"i386",
                 [[NSArray alloc] initWithObjects:
                  @"ret",nil],
                 @"x86_64",
                 [[NSArray alloc] initWithObjects:
                  @"ret",nil],
                 @"arm",
                 [[NSArray alloc] initWithObjects:
                  @"ret",nil],
                 @"armv6",
                 [[NSArray alloc] initWithObjects:
                  @"ret",nil],
                 @"armv7",
					nil],
				@"return instructions",
				nil];
}

- (BOOL)parseInstructionLine:(NSString*)line
{
	NSScanner* instructionScanner = [[NSScanner alloc] initWithString:line];
	NSString* instr;
	[instructionScanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&instr];
	instruction = [instr copy];
	[instructionScanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
	NSString* instrComp;
	while ([instructionScanner scanUpToString:@"," intoString:&instrComp]) {
		[instructionComps addObject:instrComp];
		[instructionScanner scanString:@"," intoString:nil];
	}
	return YES;
}

- (BOOL)isReturnInstruction
{
	NSArray* lookupArray = [[lookupDict objectForKey:@"return instructions"] objectForKey:architecture];
	if ([lookupArray containsObject:instruction])
		return YES;
	return NO;
}

- (NSArray*)instructionComps
{
	return instructionComps;
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"%@ (%@)",instruction,[instructionComps componentsJoinedByString:@","]];
}

@end