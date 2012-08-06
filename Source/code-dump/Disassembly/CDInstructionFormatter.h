//
//  CDInstructionFormatter.h
//  code-dump
//
//  Created by Braden Thomas on 1/2/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CDInstructionSimulator.h"

@interface CDInstructionFormatter : NSObject {
	CDInstructionSimulator* instrSim;
}
- (id)initWithSimulator:(CDInstructionSimulator*)instr;
- (void)appendDecompile:(NSMutableString*)appendString;

@end
