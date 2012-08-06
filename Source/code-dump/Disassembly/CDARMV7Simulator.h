//
//  CDARMV7Simulator.h
//  code-dump
//
//  Created by Braden Thomas on 4/21/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "CDInstructionSimulator.h"

@class CDLine,CDMachOFile,CDOCMethod,CDClassDump;

@interface CDARMV7Simulator : CDInstructionSimulator {
	NSMutableArray* lineArray;
}

- (id)initWithLines:(NSMutableArray*)lineArray file:(CDMachOFile*)mach meth:(CDOCMethod*)meth cd:(CDClassDump*)cd retValue:(BOOL)ret;
- (void)simulateLine:(CDLine*)thisLine withOffset:(long)offset;

- (void)cleanupInstructions;

@end
