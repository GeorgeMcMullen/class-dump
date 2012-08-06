//
//  CDX8664Simulator.m
//  code-dump
//
//  Created by Braden Thomas on 10/28/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "CDX8664Simulator.h"
#import "CDRegVal.h"
#import "CDMemorySimulator.h"
#import "CDFunctionCall.h"

@implementation CDX8664Simulator


- (NSMutableDictionary*)initializeProcessorState
{
	NSMutableDictionary* returnState=[super initializeProcessorState];
	[returnState setObject:[[CDRegVal alloc] initWithValue:[method imp]] forKey:@"%eip"];

	[returnState setObject:[[CDMemorySimulator alloc] init] forKey:@"stack"];
	[returnState setObject:[NSNumber numberWithInt:0] forKey:@"%esp"];

	if ([callSelector args])
	{
		int i;
		for (i=0;i<[callSelector args];i++)
		{
			NSString* argName = [callSelector argNum:i];
			NSString* argType = [callSelector argTypeNum:i];
			if ([argType isEqualToString:@"struct _NSRect"])
			{
				[[returnState objectForKey:@"stack"] pushObject:[NSString stringWithFormat:@"%@.origin.x",argName]];
				[[returnState objectForKey:@"stack"] pushObject:[NSString stringWithFormat:@"%@.origin.y",argName]];
				[[returnState objectForKey:@"stack"] pushObject:[NSString stringWithFormat:@"%@.size.width",argName]];
				[[returnState objectForKey:@"stack"] pushObject:[NSString stringWithFormat:@"%@.size.height",argName]];
			}
			else if ([argType hasPrefix:@"struct"])
				[NSException raise:@"NSNotImplemented" format:@"Pushing arguments of type %@ onto stack not implemented",argType];
			else
				[[returnState objectForKey:@"stack"] pushObject:argName];
		}
	}

	// this is actually the selector of the function called
	[[returnState objectForKey:@"stack"] pushObject:[[CDRegVal alloc] initWithValue:0]];

	// self!
	[[returnState objectForKey:@"stack"] pushObject:[[CDRegVal alloc] initWithSelf]];

	// this is actually the saved return address of the calling function
	[[returnState objectForKey:@"stack"] pushObject:[[CDRegVal alloc] initWithValue:0]];

	NSLog(@"init to %@",returnState);

	return returnState;
}

- (void)runInstruction:(CDInstructionLine*)instr onState:(NSMutableDictionary*)state
{
	SEL instructionSEL = NSSelectorFromString([NSString stringWithFormat:@"run_%@:onState:",[instr instruction]]);
	NSLog(@"%@",instr);
    if ([self respondsToSelector:instructionSEL])
    {
        [self performSelector:instructionSEL withObject:instr withObject:state];
    }
    else
    {
        NSLog(@"Warning: %@ is not recognized!", [instr instruction]);
    }

}

- (BOOL)isLiteral:(NSString*)value {
	return [value hasPrefix:@"$"];
}

- (BOOL)isRegister:(NSString*)value {
	return [value hasPrefix:@"%"];
}

- (BOOL)isMemoryLocation:(NSString*)value {
	return ([value hasPrefix:@"0x"] && ![value hasSuffix:@")"]) || ([value hasPrefix:@"("] && [value hasSuffix:@")"]);
}

- (BOOL)isRegisterOffset:(NSString*)value {
	return [value hasPrefix:@"0x"] && [value hasSuffix:@")"];
}

- (int)registerOffsetFor:(NSString*)value
{
	if (![self isRegisterOffset:value])
		return 0;

    NSLog(@"getting registerOffsetFor: %@", value);
	NSScanner* regScan = [NSScanner scannerWithString:value];
	NSString* offString;
	if (![regScan scanUpToString:@"(" intoString:&offString])
		[NSException raise:@"UnexpectedFormat" format:@"Register offset format unhandled: %@",value];
	if ([offString length]>10)
		[NSException raise:@"NSNotImplemented" format:@"Not handled register offsets of size %ld: %@",[offString length],offString];
	signed char outVal;
	sscanf([offString cStringUsingEncoding:NSASCIIStringEncoding], "0x%x", &outVal);

	return outVal;
}

- (NSString*)registerFromOffset:(NSString*)value
{
	NSScanner* offsetScanner = [[NSScanner alloc] initWithString:value];
	[offsetScanner scanUpToString:@"%" intoString:nil];
	NSString* regOut;
	[offsetScanner scanUpToString:@")" intoString:&regOut];
	return regOut;
}


- (unsigned int)literalValueFor:(NSString*)value
{
	unsigned int outVal;
	if ([value hasPrefix:@"$"])
		sscanf([value cStringUsingEncoding:NSASCIIStringEncoding], "$0x%x", &outVal);
	else
		sscanf([value cStringUsingEncoding:NSASCIIStringEncoding], "0x%x", &outVal);
	return outVal;
}

- (void)run_calll:(CDInstructionLine*)instr onState:(NSMutableDictionary*)state
{
	unsigned long callDest = [self literalValueFor:[[instr instructionComps] objectAtIndex:0]];
	// registers are obliterated in calls, eax set to result
	CDFunctionCall* funcCall = [[CDFunctionCall alloc] initWithDestination:callDest andState:state machOFile:mach symbolTable:[mach sym] classDump:aClassDump class:class];
	[state setObject:funcCall forKey:@"%eax"];
}

- (void)run_callq:(CDInstructionLine*)instr onState:(NSMutableDictionary*)state
{
	unsigned long callDest = [self literalValueFor:[[instr instructionComps] objectAtIndex:0]];
	// registers are obliterated in calls, eax set to result
	CDFunctionCall* funcCall = [[CDFunctionCall alloc] initWithDestination:callDest andState:state machOFile:mach symbolTable:[mach sym] classDump:aClassDump class:class];
	[state setObject:funcCall forKey:@"%eax"];
}

- (void)run_testb:(CDInstructionLine*)instr onState:(NSMutableDictionary*)state
{
	NSString*	compareReg1 = [[instr instructionComps] objectAtIndex:0];
    //	NSString*	compareReg2 = [[instr instructionComps] objectAtIndex:1];
	id			compareValue1 = nil;
    //	id			compareValue2 = nil;

	NSLog(@"%@",state);
	if ([self isRegister:compareReg1])
		compareValue1 = [state objectForKey:compareReg1];
	else
		[NSException raise:@"NSNotImplemented" format:@"Can't handle testing non-register value"];

	NSLog(@"compare val %@",compareValue1);

	exit(0);
}


- (void)run_subl:(CDInstructionLine*)instr onState:(NSMutableDictionary*)state
{
	NSString* subtract_value = [[instr instructionComps] objectAtIndex:0];
	id currentValue = [state objectForKey:[[instr instructionComps] objectAtIndex:1]];
	if ([self isLiteral:subtract_value])
	{
		unsigned int literalValue = [self literalValueFor:subtract_value];
		if ([currentValue isKindOfClass:[CDRegVal class]])
			[NSException raise:@"NSNotImplemented" format:@"Not implemented subtract from reg"];
		else if ([currentValue isKindOfClass:[NSNumber class]]) {
			if (literalValue%4)
				[NSException raise:@"NSNotImplemented" format:@"Cannot handle subtraction not divisible by four"];
			[[state objectForKey:@"stack"] offsetIndex:[state objectForKey:@"%esp"] byAmount:(int)literalValue/-4];
		}
		else
			[NSException raise:@"NSNotImplemented" format:@"Not implemented subtract from %@",currentValue];
	}
	else
		[NSException raise:@"NSNotImplemented" format:@"Not implemented subtracting %@",subtract_value];
}

- (void)run_subq:(CDInstructionLine*)instr onState:(NSMutableDictionary*)state
{
	NSString* subtract_value = [[instr instructionComps] objectAtIndex:0];
	id currentValue = [state objectForKey:[[instr instructionComps] objectAtIndex:1]];
	if ([self isLiteral:subtract_value])
	{
		unsigned int literalValue = [self literalValueFor:subtract_value];
		if ([currentValue isKindOfClass:[CDRegVal class]])
			[NSException raise:@"NSNotImplemented" format:@"Not implemented subtract from reg"];
		else if ([currentValue isKindOfClass:[NSNumber class]]) {
			if (literalValue%4)
				[NSException raise:@"NSNotImplemented" format:@"Cannot handle subtraction not divisible by four"];
			[[state objectForKey:@"stack"] offsetIndex:[state objectForKey:@"%esp"] byAmount:(int)literalValue/-4];
		}
		else
			[NSException raise:@"NSNotImplemented" format:@"Not implemented subtract from %@",currentValue];
	}
	else
		[NSException raise:@"NSNotImplemented" format:@"Not implemented subtracting %@",subtract_value];
}

- (void)run_leal:(CDInstructionLine*)instr onState:(NSMutableDictionary*)state
{
	NSString* sourceLocation = [[instr instructionComps] objectAtIndex:0];
	id sourceObject = nil;
	if ([self isLiteral:sourceLocation])
		[NSException raise:@"NSNotImplemented" format:@"Not handled leal with literal"];
	else if ([self isRegisterOffset:sourceLocation]) {
		int registerOffset = [self registerOffsetFor:sourceLocation];
		NSString* registerFrom = [self registerFromOffset:sourceLocation];
		if (registerOffset%4)
			[NSException raise:@"NSNotImplemented" format:@"Not handled undivisible register offsets"];
		sourceObject = [state objectForKey:registerFrom];

		if ([sourceObject isKindOfClass:[NSNumber class]]) {
			// calculate index in stack array
			sourceObject = [[state objectForKey:@"stack"] copyValueForIndex:[sourceObject intValue]];
			if (!sourceObject)
				[NSException raise:@"NSNotImplemented" format:@"Don't know how to handle null sourceObject"];
			[[state objectForKey:@"stack"] offsetIndex:sourceObject byAmount:registerOffset/4];
		}
		else
			[NSException raise:@"NSNotImplemented" format:@"Unknown indexed %@",sourceObject];
	}
	else if ([self isMemoryLocation:sourceLocation])
		[NSException raise:@"NSNotImplemented" format:@"Not handled leal with memory location (%@)",sourceLocation];
	else
		[NSException raise:@"NSNotImplemented" format:@"Unknown source location %@",sourceLocation];

	//NSLog(@"source object %@",sourceObject);
	if (!sourceObject)
		[NSException raise:@"NullSourceObject" format:@"Received NULL source object"];

	NSString* destinationLocation = [[instr instructionComps] objectAtIndex:1];
	if ([self isRegister:destinationLocation])
		[state setObject:sourceObject forKey:destinationLocation];
	else if ([self isMemoryLocation:destinationLocation])
		[NSException raise:@"NSNotImplemented" format:@"Store address in memory %@",destinationLocation];
	else if ([self isRegisterOffset:destinationLocation])
		[NSException raise:@"NSNotImplemented" format:@"Store address in register offset %@",destinationLocation];
	else
		[NSException raise:@"NSNotImplemented" format:@"Unknown location %@",destinationLocation];
}

- (void)run_leaq:(CDInstructionLine*)instr onState:(NSMutableDictionary*)state
{
	NSString* sourceLocation = [[instr instructionComps] objectAtIndex:0];
	id sourceObject = nil;
	if ([self isLiteral:sourceLocation])
		[NSException raise:@"NSNotImplemented" format:@"Not handled leal with literal"];
	else if ([self isRegisterOffset:sourceLocation]) {
		int registerOffset = [self registerOffsetFor:sourceLocation];
		NSString* registerFrom = [self registerFromOffset:sourceLocation];
		if (registerOffset%4)
			[NSException raise:@"NSNotImplemented" format:@"Not handled undivisible register offsets"];
		sourceObject = [state objectForKey:registerFrom];

		if ([sourceObject isKindOfClass:[NSNumber class]]) {
			// calculate index in stack array
			sourceObject = [[state objectForKey:@"stack"] copyValueForIndex:[sourceObject intValue]];
			if (!sourceObject)
				[NSException raise:@"NSNotImplemented" format:@"Don't know how to handle null sourceObject"];
			[[state objectForKey:@"stack"] offsetIndex:sourceObject byAmount:registerOffset/4];
		}
		else
			[NSException raise:@"NSNotImplemented" format:@"Unknown indexed %@",sourceObject];
	}
	else if ([self isMemoryLocation:sourceLocation])
		[NSException raise:@"NSNotImplemented" format:@"Not handled leal with memory location (%@)",sourceLocation];
	else
		[NSException raise:@"NSNotImplemented" format:@"Unknown source location %@",sourceLocation];

	//NSLog(@"source object %@",sourceObject);
	if (!sourceObject)
		[NSException raise:@"NullSourceObject" format:@"Received NULL source object"];

	NSString* destinationLocation = [[instr instructionComps] objectAtIndex:1];
	if ([self isRegister:destinationLocation])
		[state setObject:sourceObject forKey:destinationLocation];
	else if ([self isMemoryLocation:destinationLocation])
		[NSException raise:@"NSNotImplemented" format:@"Store address in memory %@",destinationLocation];
	else if ([self isRegisterOffset:destinationLocation])
		[NSException raise:@"NSNotImplemented" format:@"Store address in register offset %@",destinationLocation];
	else
		[NSException raise:@"NSNotImplemented" format:@"Unknown location %@",destinationLocation];
}

- (void)run_movl:(CDInstructionLine*)instr onState:(NSMutableDictionary*)state
{
	NSString* sourceLocation = [[instr instructionComps] objectAtIndex:0];
	id sourceObject = nil;
	if ([self isRegister:sourceLocation])
	{
		sourceObject = [state objectForKey:[[instr instructionComps] objectAtIndex:0]];
		if ([sourceObject isKindOfClass:[NSNumber class]]) // stack pointer
			sourceObject = [[state objectForKey:@"stack"] copyValueForIndex:[sourceObject intValue]];
		if (sourceObject == nil) {
			NSLog(@"Warning: moving non-existent value into %@.  Setting to zero",[[instr instructionComps] objectAtIndex:1]);
			sourceObject = [[CDRegVal alloc] initWithValue:0];
		}
	}
	else if ([self isLiteral:sourceLocation]) {
		unsigned int literalValue = [self literalValueFor:sourceLocation];
		sourceObject = [[CDRegVal alloc] initWithValue:literalValue];
	}
	else if ([self isRegisterOffset:sourceLocation]) {
		int registerOffset = [self registerOffsetFor:sourceLocation];
		NSString* registerFrom = [self registerFromOffset:sourceLocation];
		//NSLog(@"%d - %@",registerOffset,registerFrom);
		if (registerOffset%4)
			[NSException raise:@"NSNotImplemented" format:@"Not handled undivisible register offsets"];
		sourceObject = [state objectForKey:registerFrom];

		if ([sourceObject isKindOfClass:[NSNumber class]]) {
			// calculate index in stack array
			//NSLog(@"source object %@",sourceObject);
			sourceObject = [[state objectForKey:@"stack"] valueAtIndex:sourceObject withOffset:(registerOffset/4)];
			//NSLog(@"%@",[state objectForKey:@"stack"]);
		}
		else
			[NSException raise:@"NSNotImplemented" format:@"Unknown indexed %@",sourceObject];
	}
	else if ([self isMemoryLocation:sourceLocation])
	{
		NSString* refRegister = [sourceLocation stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"()"]];
		if ([state objectForKey:refRegister])
		{
			if ([[state objectForKey:refRegister] isKindOfClass:[NSNumber class]])
				sourceObject=[[state objectForKey:@"stack"] valueAtIndex:[state objectForKey:refRegister] withOffset:0];
			else if ([[state objectForKey:refRegister] isKindOfClass:[CDRegVal class]])
			{
				CDRegVal* refVal = [state objectForKey:refRegister];
				if ([refVal data])
				{
					unsigned int literalValue = [refVal value];
					sourceObject = [self dataAtAddress:literalValue];
				}
				else
					[NSException raise:@"NSNotImplemented" format:@"Unknown reference type %@ (%@)",refVal, nil];
			}
			else if ([[state objectForKey:refRegister] isKindOfClass:[CDSymbol class]])
			{
				sourceObject = [[CDRegVal alloc] initWithSymbolDeRef:[state objectForKey:refRegister]];
			}
			else
				[NSException raise:@"NSNotImplemented" format:@"Unknown reference register type %@ (%@)",refRegister,[[state objectForKey:refRegister] className]];
		}
		else if ([refRegister hasPrefix:@"0x"])
		{
			unsigned long address = [self literalValueFor:refRegister];
			sourceObject = [self dataAtAddress:address];
		}
		else
			[NSException raise:@"NSNotImplemented" format:@"Unknown reference register %@",refRegister];
	}
	else
		[NSException raise:@"NSNotImplemented" format:@"Unknown source location %@",sourceLocation];

	//NSLog(@"source object %@",sourceObject);
	if (!sourceObject)
		[NSException raise:@"NullSourceObject" format:@"Received NULL source object"];

	NSString* destinationLocation = [[instr instructionComps] objectAtIndex:1];
	if ([self isRegister:destinationLocation])
		[state setObject:sourceObject forKey:destinationLocation];
	else if ([self isMemoryLocation:destinationLocation])
	{
		NSString* refRegister = [destinationLocation stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"()"]];
		if ([state objectForKey:refRegister])
		{
			if ([[state objectForKey:refRegister] isKindOfClass:[NSNumber class]])
				[[state objectForKey:@"stack"] setValueAtIndex:[state objectForKey:refRegister] withOffset:0 toValue:sourceObject];
			else
				[NSException raise:@"NSNotImplemented" format:@"Unknown reference register type %@ (%@)",refRegister,[[state objectForKey:refRegister] className]];
		}
		else
			[NSException raise:@"NSNotImplemented" format:@"Unknown reference register %@",refRegister];
	}
	else if ([self isRegisterOffset:destinationLocation]) {
		int registerOffset = [self registerOffsetFor:destinationLocation];
		NSString* registerFrom = [self registerFromOffset:destinationLocation];
		//NSLog(@"%d - %@",registerOffset,registerFrom);
		if (registerOffset%4)
			[NSException raise:@"NSNotImplemented" format:@"Not handled undivisible register offsets"];
		id destObject = [state objectForKey:registerFrom];
		if ([destObject isKindOfClass:[NSNumber class]]) {
			// calculate index in stack array
			//NSLog(@"dest object %@",destObject);
			[[state objectForKey:@"stack"] setValueAtIndex:[state objectForKey:registerFrom] withOffset:registerOffset/4 toValue:sourceObject];
			//NSLog(@"%@",[state objectForKey:@"stack"]);
		}
		else
			[NSException raise:@"NSNotImplemented" format:@"Unknown indexed %@",destObject];
	}
	else
		[NSException raise:@"NSNotImplemented" format:@"Unknown location %@",destinationLocation];
}

- (void)run_movq:(CDInstructionLine*)instr onState:(NSMutableDictionary*)state
{
	NSString* sourceLocation = [[instr instructionComps] objectAtIndex:0];
	id sourceObject = nil;
	if ([self isRegister:sourceLocation])
	{
		sourceObject = [state objectForKey:[[instr instructionComps] objectAtIndex:0]];
		if ([sourceObject isKindOfClass:[NSNumber class]]) // stack pointer
			sourceObject = [[state objectForKey:@"stack"] copyValueForIndex:[sourceObject intValue]];
		if (sourceObject == nil) {
			NSLog(@"Warning: moving non-existent value into %@.  Setting to zero",[[instr instructionComps] objectAtIndex:1]);
			sourceObject = [[CDRegVal alloc] initWithValue:0];
		}
	}
	else if ([self isLiteral:sourceLocation]) {
		unsigned int literalValue = [self literalValueFor:sourceLocation];
		sourceObject = [[CDRegVal alloc] initWithValue:literalValue];
	}
	else if ([self isRegisterOffset:sourceLocation]) {
		int registerOffset = [self registerOffsetFor:sourceLocation];
		NSString* registerFrom = [self registerFromOffset:sourceLocation];
		//NSLog(@"%d - %@",registerOffset,registerFrom);
		if (registerOffset%4)
			[NSException raise:@"NSNotImplemented" format:@"Not handled undivisible register offsets"];
		sourceObject = [state objectForKey:registerFrom];

		if ([sourceObject isKindOfClass:[NSNumber class]]) {
			// calculate index in stack array
			//NSLog(@"source object %@",sourceObject);
			sourceObject = [[state objectForKey:@"stack"] valueAtIndex:sourceObject withOffset:(registerOffset/4)];
			//NSLog(@"%@",[state objectForKey:@"stack"]);
		}
		else
			[NSException raise:@"NSNotImplemented" format:@"Unknown indexed %@",sourceObject];
	}
	else if ([self isMemoryLocation:sourceLocation])
	{
		NSString* refRegister = [sourceLocation stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"()"]];
		if ([state objectForKey:refRegister])
		{
			if ([[state objectForKey:refRegister] isKindOfClass:[NSNumber class]])
				sourceObject=[[state objectForKey:@"stack"] valueAtIndex:[state objectForKey:refRegister] withOffset:0];
			else if ([[state objectForKey:refRegister] isKindOfClass:[CDRegVal class]])
			{
				CDRegVal* refVal = [state objectForKey:refRegister];
				if ([refVal data])
				{
					unsigned int literalValue = [refVal value];
					sourceObject = [self dataAtAddress:literalValue];
				}
				else
					[NSException raise:@"NSNotImplemented" format:@"Unknown reference type %@ (%@)",refVal, nil];
			}
			else if ([[state objectForKey:refRegister] isKindOfClass:[CDSymbol class]])
			{
				sourceObject = [[CDRegVal alloc] initWithSymbolDeRef:[state objectForKey:refRegister]];
			}
			else
				[NSException raise:@"NSNotImplemented" format:@"Unknown reference register type %@ (%@)",refRegister,[[state objectForKey:refRegister] className]];
		}
		else if ([refRegister hasPrefix:@"0x"])
		{
			unsigned long address = [self literalValueFor:refRegister];
			sourceObject = [self dataAtAddress:address];
		}
		else
			[NSException raise:@"NSNotImplemented" format:@"Unknown reference register %@",refRegister];
	}
	else
		[NSException raise:@"NSNotImplemented" format:@"Unknown source location %@",sourceLocation];

	//NSLog(@"source object %@",sourceObject);
	if (!sourceObject)
		[NSException raise:@"NullSourceObject" format:@"Received NULL source object"];

	NSString* destinationLocation = [[instr instructionComps] objectAtIndex:1];
	if ([self isRegister:destinationLocation])
		[state setObject:sourceObject forKey:destinationLocation];
	else if ([self isMemoryLocation:destinationLocation])
	{
		NSString* refRegister = [destinationLocation stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"()"]];
		if ([state objectForKey:refRegister])
		{
			if ([[state objectForKey:refRegister] isKindOfClass:[NSNumber class]])
				[[state objectForKey:@"stack"] setValueAtIndex:[state objectForKey:refRegister] withOffset:0 toValue:sourceObject];
			else
				[NSException raise:@"NSNotImplemented" format:@"Unknown reference register type %@ (%@)",refRegister,[[state objectForKey:refRegister] className]];
		}
		else
			[NSException raise:@"NSNotImplemented" format:@"Unknown reference register %@",refRegister];
	}
	else if ([self isRegisterOffset:destinationLocation]) {
		int registerOffset = [self registerOffsetFor:destinationLocation];
		NSString* registerFrom = [self registerFromOffset:destinationLocation];
		//NSLog(@"%d - %@",registerOffset,registerFrom);
		if (registerOffset%4)
			[NSException raise:@"NSNotImplemented" format:@"Not handled undivisible register offsets"];
		id destObject = [state objectForKey:registerFrom];
		if ([destObject isKindOfClass:[NSNumber class]]) {
			// calculate index in stack array
			//NSLog(@"dest object %@",destObject);
			[[state objectForKey:@"stack"] setValueAtIndex:[state objectForKey:registerFrom] withOffset:registerOffset/4 toValue:sourceObject];
			//NSLog(@"%@",[state objectForKey:@"stack"]);
		}
		else
			[NSException raise:@"NSNotImplemented" format:@"Unknown indexed %@",destObject];
	}
	else
		[NSException raise:@"NSNotImplemented" format:@"Unknown location %@",destinationLocation];
}

- (void)run_popl:(CDInstructionLine*)instr onState:(NSMutableDictionary*)state
{
	id destRegister = [[instr instructionComps] objectAtIndex:0];
	[state setObject:[[state objectForKey:@"stack"] popObject] forKey:destRegister];
}

- (void)run_popq:(CDInstructionLine*)instr onState:(NSMutableDictionary*)state
{
	id destRegister = [[instr instructionComps] objectAtIndex:0];
	[state setObject:[[state objectForKey:@"stack"] popObject] forKey:destRegister];
}

- (void)run_ret:(CDInstructionLine*)instr onState:(NSMutableDictionary*)state
{
	[state setObject:[[state objectForKey:@"stack"] popObject] forKey:@"%eip"];
}

- (void)run_pushl:(CDInstructionLine*)instr onState:(NSMutableDictionary*)state
{
	id currentValue = [state objectForKey:[[instr instructionComps] objectAtIndex:0]];
	if ([currentValue isKindOfClass:[CDRegVal class]])
		[[state objectForKey:@"stack"] pushObject:[currentValue copy]];
	else {
		NSLog(@"Warning: pushing non-existent value %@.  Setting to zero",[[instr instructionComps] objectAtIndex:0]);
		[[state objectForKey:@"stack"] pushObject:[[CDRegVal alloc] initWithValue:0]];
	}
}

- (void)run_pushq:(CDInstructionLine*)instr onState:(NSMutableDictionary*)state
{
	id currentValue = [state objectForKey:[[instr instructionComps] objectAtIndex:0]];
	if ([currentValue isKindOfClass:[CDRegVal class]])
		[[state objectForKey:@"stack"] pushObject:[currentValue copy]];
	else {
		NSLog(@"Warning: pushing non-existent value %@.  Setting to zero",[[instr instructionComps] objectAtIndex:0]);
		[[state objectForKey:@"stack"] pushObject:[[CDRegVal alloc] initWithValue:0]];
	}
}

- (id)dataAtAddress:(unsigned int)addr
{
	CDSymbol* symbol = [[mach sym] findByOffset:addr];
	if (symbol)
		return symbol;

	unsigned int* dataPtr = (unsigned int*)[mach pointerFromVMAddr:addr];
	if (dataPtr)
		return [[CDRegVal alloc] initWithValue:*dataPtr];
	else
		[NSException raise:@"NSNotImplemented" format:@"Cannot find data at %08x",addr];
	return nil;
}

@end
