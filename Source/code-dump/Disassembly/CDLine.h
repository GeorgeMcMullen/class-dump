//
//  CDLine.h
//  class-dump
//
//  Created by Braden Thomas on 4/7/06.
//

#import <Cocoa/Cocoa.h>

@class CDRegVal,CDLCSymbolTable;

@interface CDLine : NSObject {

	CDLCSymbolTable* sym;

	NSMutableString* data;
	// return type of this line
	NSMutableString* type;
	// registers
	NSMutableArray* reg;
	// comparison registers
	NSMutableArray* creg;
	// targets of a conditional branch
	NSMutableArray* bTarget;
	CDRegVal* ctrReg;
	
	NSString* opCache;
	
	long offset;
	// sometimes we may want to print an offset
	BOOL pOffset;
	BOOL showMe;
	BOOL isBranch;
	BOOL isCondBranch;	
	BOOL isAsm;

}

- (id)init:(CDLCSymbolTable*)symTab;
- (id)init:(CDLCSymbolTable*)symTab withData:(NSString*)data;
- (id)init:(CDLCSymbolTable*)symTab withData:(NSString*)data offset:(long)offset;
- (id)initWithData:(NSString*)data offset:(long)offset old:(CDLine*)old;

- (NSString*)globalSymbol;
- (CDLCSymbolTable*)symTab;
- (void)setReg:(CDLine*)inOld;
- (NSString*)data;
- (NSString*)type;
- (NSString*)op;
- (NSMutableArray*)regs;
- (NSMutableArray*)cregs;
- (long)offset;
- (NSMutableArray*)bTarget;

- (BOOL)returnStruct;
- (BOOL)regEqualTo:(CDLine*)b;
- (CDRegVal*)regData:(int)num cond:(BOOL)isCond;
- (CDRegVal*)ctrData;
- (void)setReg:(int)regNum data:(CDRegVal*)regData cond:(BOOL)isCond;
- (void)setCtrData:(CDRegVal*)regData;
- (int)instrComp:(int)num;
- (NSUInteger)ncomp;

- (void)setShow:(BOOL)newval;
- (void)setAsm:(BOOL)newval;
- (void)setBranch:(BOOL)newval;
- (void)setCondBranch:(BOOL)newval;
- (void)setData:(NSString*)data;
- (void)setType:(NSString*)data;
- (void)setOffset:(long)data;

- (BOOL)doComp;
- (BOOL)isVoid;

- (BOOL)isReturnObject;

- (BOOL)isBranch;
- (BOOL)isCondBranch;
- (BOOL)isSelector;
- (BOOL)isSuperObj;
- (BOOL)isNSLog;
- (BOOL)isNSBeep;
- (BOOL)isSelectorLine;
- (BOOL)showMe;
- (BOOL)isAsm;

- (NSString*)formatConditionWithString:(NSString*)condition;

@end
