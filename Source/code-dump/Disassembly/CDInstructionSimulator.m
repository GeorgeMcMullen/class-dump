//
//  CDInstructionSimulator.m
//  code-dump
//
//  Created by Braden Thomas on 10/28/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "CDInstructionSimulator.h"
#import "CDAssemblyProcessor.h"
#import "CDTypeFormatter.h"

@implementation CDInstructionSimulator

- (id)initWithAssembly:(CDAssemblyProcessor*)inDis file:(CDMachOFile*)file meth:(CDOCMethod*)meth class:(CDOCClass*)inClass cd:(CDClassDump*)cd retValue:(BOOL)ret
{
	self = [super init];
	if (self != nil) {
		disas = inDis;
		retValue = ret;
		mach = file;
		method = meth;
		aClassDump = cd;
		class = inClass;
		
		callSelector = [[CDSelector alloc] initWithMethod:method classDump:cd];
		processorStates = [[NSMutableDictionary alloc] init];
		instructions = [disas getInstructionsForMethod:method inClass:class];
		NSLog(@"method has %ld instructions",[instructions count]);
	}
	return self;
}

- (NSMutableDictionary*)initializeProcessorState
{
	return [[NSMutableDictionary alloc] init];
}

- (void)simulateInstructions
{
	// initialize processor states with first state
	NSDictionary* processorState = [self initializeProcessorState];
	NSMutableIndexSet* startPath = [[NSMutableIndexSet alloc] initWithIndex:0];
	[processorStates setObject:processorState forKey:startPath];

	//NSLog(@"first state: %@",processorState);
	
	[self simulateInstructionAtPathPoint:startPath];
}

- (void)simulateInstructionAtPathPoint:(NSMutableIndexSet*)currentPath
{
	if ([currentPath lastIndex]>=[instructions count])
		return;

	CDInstructionLine* currentInstruction = [instructions objectAtIndex:[currentPath lastIndex]];

	NSMutableDictionary* procState = [[processorStates objectForKey:currentPath] mutableCopy];
	[self runInstruction:currentInstruction onState:procState];

	[currentPath addIndex:[currentPath lastIndex]+1];
	[processorStates setObject:procState forKey:currentPath];
	return [self simulateInstructionAtPathPoint:currentPath];
}

- (void)runInstruction:(CDInstructionLine*)instr onState:(NSMutableDictionary*)state {}
- (id)dataAtAddress:(unsigned int)addr {return nil;}

@synthesize processorStates;

@end
