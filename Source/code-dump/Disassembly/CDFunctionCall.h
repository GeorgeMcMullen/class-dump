//
//  CDFunctionCall.h
//  code-dump
//
//  Created by Braden Thomas on 12/19/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CDLCSymbolTable.h"
#import "CDHeaderIndex.h"
#import "CDMachOFile.h"
#import "CDClassDump.h"

@interface CDFunctionCall : NSObject {
	CDMachOFile* mach;
	CDLCSymbolTable* symbolTable;
	NSMutableDictionary* functionInfo;
	CDOCClass* class;
	CDClassDump* classDump;
}
- (id)initWithDestination:(unsigned long)dest andState:(NSMutableDictionary*)state machOFile:(CDMachOFile*)macho symbolTable:(CDLCSymbolTable*)sym classDump:(CDClassDump*)cd class:(CDOCClass*)cl;
- (void)handleSelectorWithState:(NSMutableDictionary*)state lookupTable:(CDHeaderIndex*)lookup;
- (void)findArgsInState:(NSMutableDictionary*)state;
- (void)resolveSelectorUncertainties;
- (NSString*)heuristicType;
@end
