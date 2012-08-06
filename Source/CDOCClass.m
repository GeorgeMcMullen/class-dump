// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2012 Steve Nygard.

#import "CDOCClass.h"

#import "CDClassDump.h"
#import "CDOCIvar.h"
#import "CDOCMethod.h"
#import "CDType.h"
#import "CDTypeController.h"
#import "CDTypeParser.h"
#import "CDVisitor.h"
#import "CDVisitorPropertyState.h"

#import "CDSelector.h"
#import "CDTypeFormatter.h"
#import "CDTypeFormatter.h"

@implementation CDOCClass
{
    NSString *_superClassName;
    NSArray *_ivars;
    
    BOOL _isExported;
}

- (id)init;
{
    if ((self = [super init])) {
        _superClassName = nil;
        _ivars = nil;
        
        _isExported = YES;
    }

    return self;
}

#pragma mark - Debugging

- (NSString *)description;
{
    return [NSString stringWithFormat:@"%@, exported: %@", [super description], self.isExported ? @"YES" : @"NO"];
}

#pragma mark -

- (void)registerTypesWithObject:(CDTypeController *)typeController phase:(NSUInteger)phase;
{
    [super registerTypesWithObject:typeController phase:phase];

    for (CDOCIvar *ivar in self.ivars) {
        [ivar.parsedType phase:phase registerTypesWithObject:typeController usedInMethod:NO];
    }
}

- (NSString *)methodSearchContext;
{
    NSMutableString *resultString = [NSMutableString string];

    [resultString appendFormat:@"@interface %@", self.name];
    if (self.superClassName != nil)
        [resultString appendFormat:@" : %@", self.superClassName];

    if ([self.protocols count] > 0)
        [resultString appendFormat:@" <%@>", self.protocolsString];

    return resultString;
}

- (void)recursivelyVisit:(CDVisitor *)visitor;
{
    if ([visitor.classDump shouldShowName:self.name]) {
        CDVisitorPropertyState *propertyState = [[CDVisitorPropertyState alloc] initWithProperties:self.properties];
        
        [visitor willVisitClass:self];
        
        [visitor willVisitIvarsOfClass:self];
        for (CDOCIvar *ivar in self.ivars)
            [visitor visitIvar:ivar];
        [visitor didVisitIvarsOfClass:self];
        
        //[aVisitor willVisitPropertiesOfClass:self];
        //[self visitProperties:aVisitor];
        //[aVisitor didVisitPropertiesOfClass:self];
        
        [self visitMethods:visitor propertyState:propertyState];
        // Should mostly be dynamic properties
        [visitor visitRemainingProperties:propertyState];
        [visitor didVisitClass:self];
    }
}

#pragma mark - CDTopologicalSort protocol

- (NSString *)identifier;
{
    return self.name;
}

- (NSArray *)dependancies;
{
    if (self.superClassName == nil)
        return @[];

    return @[self.superClassName];
}

#pragma mark - Decompilation
- (void)printDecompilation:(CDAssemblyProcessor*)disasm classDump:(CDClassDump *)aClassDump resString:(NSMutableString*)resultString file:(CDMachOFile*)mach;
{
    NSArray *methods;
    
	[aClassDump setCurClass:self];
    
    if ([aClassDump shouldMatchRegex] == YES && [aClassDump regexMatchesString:[self name]] == NO)
        return;
    
	NSLog(@"Starting class %@\n",[self name]);
    
    [resultString appendFormat:@"@implementation %@\n\n", [self name]];
    
    if ([aClassDump shouldSortMethods] == YES)
        methods = [[self classMethods] sortedArrayUsingSelector:@selector(ascendingCompareByName:)];
    else
        methods = [self classMethods];
    
	NSEnumerator* methEnum = [methods objectEnumerator];
	id meth;
    
	while ((meth = [methEnum nextObject]))
	{
//		NSAutoreleasePool *methPool;
//		methPool = [[NSAutoreleasePool alloc] init];
        
		[resultString appendString:@"+ "];
		[meth printDecompilation:disasm classDump:aClassDump resString:resultString file:mach forClass:self];
		[resultString appendString:@"\n"];
        
//		[methPool release];
        
	}
    
    if ([aClassDump shouldSortMethods] == YES)
        methods = [[self instanceMethods] sortedArrayUsingSelector:@selector(ascendingCompareByName:)];
    else
        methods = [self instanceMethods];
    
	methEnum = [methods objectEnumerator];
	while ((meth = [methEnum nextObject]))
	{	
//		NSAutoreleasePool *methPool;
//		methPool = [[NSAutoreleasePool alloc] init];
        
		[resultString appendString:@"- "];
		[meth printDecompilation:disasm classDump:aClassDump resString:resultString file:mach forClass:self];
		[resultString appendString:@"\n"];		
        
//		[methPool release];
	}
	
    if ([[self classMethods] count] > 0 || [[self instanceMethods] count] > 0)
        [resultString appendString:@"\n"];
    
    [resultString appendString:@"@end\n\n"];	
}

- (NSString*)getFuncDefMatching:(CDSelector*)selector cd:(CDClassDump*)cd
{
	if (![[selector sel] length])
		return nil;
    
	//NSLog(@"getfuncdefmatching %@\n",selector);
	
	NSEnumerator* methEnum = [[self classMethods] objectEnumerator];
	CDOCMethod* meth;
	while ((meth = [methEnum nextObject]))
	{
		if ([[meth name] isEqualToString:[selector sel]])
		{
			//NSLog(@"found matching selector %@!\n",[selector sel]);
			return [[NSString alloc] initWithString:[[cd methodTypeFormatter] formatMethodName:[meth name] type:[meth type]]];
		}
	}
	methEnum = [[self instanceMethods] objectEnumerator];
	while ((meth = [methEnum nextObject]))
	{
		if ([[meth name] isEqualToString:[selector sel]])
		{
			//NSLog(@"found matching selector %@!\n",[selector sel]);
			return [[NSString alloc] initWithString:[[cd methodTypeFormatter] formatMethodName:[meth name] type:[meth type]]];
		}
	}
	NSLog(@"couldn't find selector %@\n",[selector sel]);
	return nil;		
}

@end
