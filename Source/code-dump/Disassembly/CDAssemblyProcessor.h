//
//  CDAssemblyProcessor.h
//  code-dump
//
//  Created by Braden Thomas on 10/24/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CDOCMethod.h"
#import "CDDisassembly.h"
#import "CDOCClass.h"

@interface CDAssemblyProcessor : NSObject {
	CDDisassembly* disassembly;
	NSMutableArray* instructionArray;
	NSMutableDictionary* functionMap;
	NSString* architecture;
	NSMutableArray* functionEndPoints;
}

- (id)initWithDisassembly:(CDDisassembly*)disas andArchitecture:(NSString*)arch;
- (NSArray*)parseInstructions:(NSString*)disas;
- (void)detectFunctions;
- (NSArray*)getInstructionsForMethod:(CDOCMethod*)method inClass:(CDOCClass*)class;

@end
