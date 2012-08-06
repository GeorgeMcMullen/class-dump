// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2012 Steve Nygard.

#import "CDOCModule.h"

#import "CDObjectiveC1Processor.h"
#import "CDOCSymtab.h"
#import "CDClassDump.h"

@implementation CDOCModule
{
    uint32_t _version;
    NSString *_name;
    CDOCSymtab *_symtab;
}

- (id)init;
{
    if ((self = [super init])) {
        _version = 0;
        _name = nil;
        _symtab = nil;
    }

    return self;
}

#pragma mark - Debugging

- (NSString *)description;
{
    return [NSString stringWithFormat:@"[%@] name: %@, version: %u, symtab: %@", NSStringFromClass([self class]), self.name, self.version, self.symtab];
}

#pragma mark -

- (NSString *)formattedString;
{
    return [NSString stringWithFormat:@"/*\n * %@\n */\n", self.name];
}

#pragma mark - Decompilation
- (void)printDecompilation:(CDAssemblyProcessor*)disasm classDump:(CDClassDump *)aClassDump resString:(NSMutableString*)resultString file:(CDMachOFile*)mach
{
	// enumerate classes in module
	NSEnumerator* classEnum = [[_symtab classes] objectEnumerator];
	id class;
	
	while ((class = [classEnum nextObject]))
	{
		//NSAutoreleasePool *classPool = [[NSAutoreleasePool alloc] init];
		
		[aClassDump setCurMod:self];
		[class printDecompilation:disasm classDump:aClassDump resString:resultString file:mach];
		
		//[classPool release];
	}
}

@end
