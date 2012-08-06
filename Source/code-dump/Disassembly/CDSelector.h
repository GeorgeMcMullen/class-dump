//
//  CDSelector.h
//  class-dump
//
//  Created by Braden Thomas on 4/8/06.
//

#import <Cocoa/Cocoa.h>
#import "CDOCMethod.h"

@class CDClassDump;

@interface CDSelector : NSObject {

	NSString* resultType;
	NSString* objectType;
	NSMutableString* object;
	NSMutableString* selector;
	NSMutableArray* arguments;
	NSMutableArray* frmArgs;
	NSMutableArray* argumentTypes;
	NSString* funcDef;
}

- (id)init;
- (id)initWithMethod:(CDOCMethod*)met classDump:(CDClassDump*)cd;

- (int)args;
- (int)selArgCnt;

- (BOOL)isCocoa:(NSString*)type;

- (void)setArgsWithFrmString:(NSString*)frmString;

- (NSString*)argNum:(int)i;
- (NSString*)argTypeNum:(int)i;
- (NSString*)lastArg;

- (NSString*)description;
- (NSString*)object;
- (NSString*)sel;
- (NSString*)resultType:(NSArray*)lineArray cd:(CDClassDump*)cd;
- (BOOL)argumentIsCocoa:(int)arg withLines:(NSArray*)lineArray cd:(CDClassDump*)cd;

- (void)setObject:(NSString*)obj;
- (void)setObjectType:(NSString*)type;

- (void)addObjectArg:(int)n object:(NSString*)argObject;
- (void)addDataArg:(int)n data:(long)value;
- (void)addFormatArg:(NSString*)argObject;

- (NSString*)getFunctionDefinitionWithLines:(NSArray*)lineArray success:(BOOL*)success cd:(CDClassDump*)cd obj:(NSString**)selObj;

- (NSArray*)headerPath:(NSString*)object cd:(CDClassDump*)cd;
- (NSString*)getDefinition:(NSString*)path;
- (NSString*)searchDB:(NSDictionary*)db forSelector:(NSString*)sel;

- (BOOL)formatString;
+ (int)formatCompon:(NSString*)fstring;

@end
