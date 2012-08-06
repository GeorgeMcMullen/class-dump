//
//  CDInstructionSimulator.h
//  code-dump
//
//  Created by Braden Thomas on 10/28/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "CDLine.h"
#import "CDOCMethod.h"
#import "CDClassDump.h"
#import "CDMachOFile.h"
#import "CDLCSymbolTable.h"
#import "CDSelector.h"
#import "CDInstructionLine.h"

@interface CDInstructionSimulator : NSObject {

	BOOL retValue;
	CDOCClass* class;
	CDOCMethod* method;
	CDAssemblyProcessor* disas;
	CDSelector* callSelector;
	NSArray* instructions;
	NSMutableDictionary * processorStates;
	
	CDMachOFile* mach;
	CDClassDump* aClassDump;
	
	// not sure if I need these
	CDLine* curLine;
	long curOff;

}

- (id)initWithAssembly:(CDAssemblyProcessor*)inDis file:(CDMachOFile*)file meth:(CDOCMethod*)meth class:(CDOCClass*)incl cd:(CDClassDump*)cd retValue:(BOOL)ret;
- (void)simulateInstructions;
- (NSMutableDictionary*)initializeProcessorState;
- (void)simulateInstructionAtPathPoint:(NSMutableIndexSet*)currentPath;
- (void)runInstruction:(CDInstructionLine*)instr onState:(NSMutableDictionary*)state;
- (id)dataAtAddress:(unsigned int)addr;

@property(readonly) NSDictionary* processorStates;

@end
