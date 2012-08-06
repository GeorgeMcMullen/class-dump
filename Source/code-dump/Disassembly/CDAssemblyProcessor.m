//
//  CDAssemblyProcessor.m
//  code-dump
//
//  Created by Braden Thomas on 10/24/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "CDAssemblyProcessor.h"
#import "CDInstructionLine.h"
#import "CDOCProtocol.h"

@implementation CDAssemblyProcessor

- (id)initWithDisassembly:(CDDisassembly*)disas andArchitecture:(NSString*)arch
{
	self = [super init];
	if (self != nil) {
		functionMap = [[NSMutableDictionary alloc] init];
		architecture = arch;
		disassembly = disas;
		functionEndPoints = [[NSMutableArray alloc] init];
		[self parseInstructions:[disassembly instructionsString]];
	}
	return self;
}

- (NSArray*)parseInstructions:(NSString*)disas
{
	instructionArray = [[NSMutableArray alloc] init];
	NSScanner* instructionScanner = [[NSScanner alloc] initWithString:disas];
	if (![instructionScanner scanUpToString:@":" intoString:nil]) {
		NSLog(@"Error: incorrect format, path not found");
		return nil;
	}
	[instructionScanner scanString:@":" intoString:nil];
	[instructionScanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];
	NSString* sectionName=nil;
	[instructionScanner scanUpToString:@"\n" intoString:&sectionName];
	if (![sectionName isEqualToString:@"(__TEXT,__text) section"]) {
		NSLog(@"Unknown section: %@",sectionName);
		return nil;
	}
	[instructionScanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];
	NSString* instrLine=nil;
	NSString* functionHeader=nil;
	while ([instructionScanner scanUpToString:@"\n" intoString:&instrLine])
	{
		NSScanner* lineScanner = [[NSScanner alloc] initWithString:instrLine];
		if ([instrLine hasSuffix:@":"]) {
			functionHeader=[instrLine stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":"]];
		}
		else {
			NSString* offsetString=nil;
			[lineScanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&offsetString];
			if (!offsetString) {
				NSLog(@"Error: Unable to read instruction offset");
				return nil;
			}

            //TODO: otool probably used to output 8 byte offsets for 32-bit architectures, so the format was "%8lx". It's changed to 16 now for 64-bit architectures
            //TODO: Determine if it outputs 8 byte offsets for other legacy and arm arch's
            //TODO: Determine if we need uint64_t instead of unsigned long for this
			unsigned long offset;
			if (sscanf([offsetString cStringUsingEncoding:NSUTF8StringEncoding],"%16lx",&offset)!=1) {
				NSLog(@"%@",offsetString);
				exit(0);

				NSLog(@"Error: Unable to parse instruction offset");
				return nil;
			}
			NSNumber* instructionOffset = [[NSNumber alloc] initWithUnsignedLong:offset];
			if (functionHeader) {
				[functionMap setObject:functionHeader forKey:instructionOffset];
				functionHeader=nil;
			}
			[lineScanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:nil];
			if ([lineScanner isAtEnd]) {
				NSLog(@"Error: Unable to read instruction");
				return nil;
			}
			NSString* instructionLine = [[lineScanner string] substringFromIndex:[lineScanner scanLocation]+1];
			CDInstructionLine* instruction = [[CDInstructionLine alloc] initWithLine:instructionLine andArchitecture:architecture atOffset:instructionOffset];
			[instructionArray addObject:instruction];
			
		}
	}

	[self detectFunctions];
	return instructionArray;
}

- (void)detectFunctions
{
	[functionEndPoints removeAllObjects];
	unsigned int i;
	for (i=0;i<[instructionArray count];i++)
	{
		CDInstructionLine* curInstr = [instructionArray objectAtIndex:i];

		if ([curInstr isReturnInstruction])
			[functionEndPoints addObject:curInstr];

		if (i<[instructionArray count]-2) {
			CDInstructionLine* nxtInstr = [instructionArray objectAtIndex:i+1];
			if (functionMap != nil && [functionMap objectForKey:[nxtInstr offset]] != nil)
				[functionEndPoints addObject:curInstr];
		}
	}
}

- (NSArray*)getInstructionsForMethod:(CDOCMethod*)method inClass:(CDOCClass*)class
{
	//NSLog(@"instructions for %@",method);
	// try to find in functions
	NSString* functionHeader=nil;
	if ([functionMap count]) {
		if ([[class classMethods] containsObject:method])
			functionHeader = [NSString stringWithFormat:@"+[%@ %@]",[class name],[method name]];
		else if ([[class instanceMethods] containsObject:method])
			functionHeader = [NSString stringWithFormat:@"-[%@ %@]",[class name],[method name]];
		else
			[NSException raise:@"CDMethodNotFoundException" format:@"Couldn't find method in class"];
		
		NSNumber* funcOffset = [functionMap objectForKey:functionHeader];
		if (funcOffset!=nil)
			[NSException raise:@"CDNotImplemented" format:@"Found method with functions"];
	}
	
	unsigned int i,startIndex=0,endIndex=0;
	BOOL hasStartIndex=NO;
	for (i=0;i<[instructionArray count];i++) {
		CDInstructionLine* curInstr = [instructionArray objectAtIndex:i];
		if (hasStartIndex==NO && [[curInstr offset] isEqualToNumber:[NSNumber numberWithUnsignedInteger:[method imp]]]) {
			startIndex=i;
			hasStartIndex=YES;
		}
		if (hasStartIndex==YES && [functionEndPoints containsObject:curInstr]) {
			endIndex=i+1;
			break;
		}
	}
	if (hasStartIndex==NO || endIndex==0) {
		NSLog(@"Error finding instructions for method.  Attempting to use next method for header %@",functionHeader);
		BOOL anotherDisassembler = [disassembly useNextDisassemblerForHeader:functionHeader atOffset:[NSNumber numberWithUnsignedInt:[method imp]]];
		if (anotherDisassembler == NO)
			[NSException raise:@"NSInstructionsNotFound" format:@"Instructions for method not found"];
		
        for (i=0;i<[instructionArray count];i++)
        {
            [instructionArray removeObjectAtIndex:i];
        }

		[self parseInstructions:[disassembly instructionsString]];
		// restart this method with new disassembler
		return [self getInstructionsForMethod:method inClass:class];
	}
	return [instructionArray subarrayWithRange:NSMakeRange(startIndex, endIndex-startIndex)];
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"CDAssemblyProcessor, %ld instructions, %ld functions",[instructionArray count],[functionMap count]];
}

@end
