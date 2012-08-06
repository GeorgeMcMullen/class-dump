// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2012 Steve Nygard.

#import <Foundation/Foundation.h>

#import "CDFile.h" // For CDArch
#import "CDHeaderIndex.h"

#define CLASS_DUMP_BASE_VERSION "3.3.4 (64 bit)"

#ifdef DEBUG
#define CLASS_DUMP_VERSION CLASS_DUMP_BASE_VERSION " (Debug version compiled " __DATE__ " " __TIME__ ")"
#else
#define CLASS_DUMP_VERSION CLASS_DUMP_BASE_VERSION
#endif

@class CDFile, CDMachOFile;
@class CDTypeController;
@class CDVisitor;
@class CDSearchPathState;
@class CDOCModule,CDOCClass, CDTypeFormatter;

@interface CDClassDump : NSObject

@property (readonly) CDSearchPathState *searchPathState;

@property (assign) BOOL shouldProcessRecursively;
@property (assign) BOOL shouldSortClasses;
@property (assign) BOOL shouldSortClassesByInheritance;
@property (assign) BOOL shouldSortMethods;
@property (assign) BOOL shouldShowIvarOffsets;
@property (assign) BOOL shouldShowMethodAddresses;
@property (assign) BOOL shouldShowHeader;

@property (strong) NSRegularExpression *regularExpression;
- (BOOL)shouldShowName:(NSString *)name;

@property (assign) BOOL shouldDecompile;
@property (strong) NSString *decompileArch;
@property (readonly) CDTypeFormatter *methodTypeFormatter;

@property (strong) NSString *sdkRoot;

@property (readonly) NSArray *machOFiles;
@property (readonly) NSArray *objcProcessors;

@property (assign) CDArch targetArch;

@property (nonatomic, readonly) BOOL containsObjectiveCData;
@property (nonatomic, readonly) BOOL hasEncryptedFiles;
@property (nonatomic, readonly) BOOL hasObjectiveCRuntimeInfo;

@property (readonly) CDTypeController *typeController;

- (BOOL)loadFile:(CDFile *)file;
- (void)processObjectiveCData;

- (void)recursivelyVisit:(CDVisitor *)visitor;

- (void)appendHeaderToString:(NSMutableString *)resultString;

- (void)registerTypes;

- (void)showHeader;
- (void)showLoadCommands;

#pragma mark - Decompile Methods
+ (NSString*)genSearchStrWithDef:(NSString*)def;
- (CDHeaderIndex*)lookupTable;
- (CDOCModule*)curMod;
- (void)setCurMod:(CDOCModule*)a;
- (CDOCClass*)curClass;
- (void)setCurClass:(CDOCClass*)a;
- (NSMutableArray*)allclasses;
//- (void)addClasses:(NSArray *)newClasses;
- (void)generateDecompile;
- (void)buildLookupTable;
- (void)buildLookupTableFromPPC;
- (BOOL)shouldMatchRegex;
- (void)setShouldMatchRegex:(BOOL)newFlag;
- (BOOL)setRegex:(char *)regexCString errorMessage:(NSString **)errorMessagePointer;
- (BOOL)regexMatchesString:(NSString *)aString;
- (NSDictionary*)lookupDict;
@end
