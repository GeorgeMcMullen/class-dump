// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2012 Steve Nygard.

#import <Foundation/Foundation.h>

@class CDTypeController;
@class CDLine, CDOCClass, CDMachOFile, CDAssemblyProcessor, CDClassDump;

@interface CDOCMethod : NSObject <NSCopying>

- (id)initWithName:(NSString *)name type:(NSString *)type imp:(NSUInteger)imp;
- (id)initWithName:(NSString *)name type:(NSString *)type;

@property (readonly) NSString *name;
@property (readonly) NSString *type;
@property (assign) NSUInteger imp;

@property (strong) NSMutableDictionary *stack;

- (NSArray *)parsedMethodTypes;

- (void)appendToString:(NSMutableString *)resultString typeController:(CDTypeController *)typeController;

- (NSComparisonResult)ascendingCompareByName:(CDOCMethod *)otherMethod;

#pragma mark - Decompilation
- (void)printDecompilation:(CDAssemblyProcessor*)disasm classDump:(CDClassDump *)aClassDump resString:(NSMutableString*)resultString file:(CDMachOFile*)mach forClass:(CDOCClass*)class;
- (NSString*)lookupObject:(int)reg line:(CDLine*)line lineArray:(NSArray*)lineArray file:(CDMachOFile*)mach outType:(NSString**)type;
- (BOOL)canCombine:(CDLine*)aLine otherLine:(CDLine*)old lineArray:(NSArray*)disLines;
- (void)appendLines:(NSArray*)lineArray toString:(NSMutableString*)resultString ret:(BOOL)retValue file:(CDMachOFile*)mach;

@end
