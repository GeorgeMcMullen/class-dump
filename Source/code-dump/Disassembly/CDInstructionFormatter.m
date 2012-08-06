//
//  CDInstructionFormatter.m
//  code-dump
//
//  Created by Braden Thomas on 1/2/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "CDInstructionFormatter.h"


@implementation CDInstructionFormatter

- (id)initWithSimulator:(CDInstructionSimulator*)instr
{
	self = [super init];
	if (self != nil) {
		instrSim=instr;
	}
	return self;
}

- (void)appendDecompile:(NSMutableString*)appendString
{
	NSLog(@"appending decompile");
	
//	NSLog(@"%@",instrSim.processorStates);	
//	[NSException raise:@"NSNotImplemented" format:@"Instruction formatter not implemented"];
}

@end
