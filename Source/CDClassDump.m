// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2012 Steve Nygard.

#import "CDClassDump.h"

#import "CDFatArch.h"
#import "CDFatFile.h"
#import "CDLCDylib.h"
#import "CDMachOFile.h"
#import "CDObjectiveCProcessor.h"
#import "CDType.h"
#import "CDTypeFormatter.h"
#import "CDTypeParser.h"
#import "CDVisitor.h"
#import "CDLCSegment.h"
#import "CDLCSegment64.h"
#import "CDTypeController.h"
#import "CDSearchPathState.h"

#import "CDOCModule.h"
#import "CDLCSymbolTable.h"
#import "CDHeaderIndex.h"
#import "CDDisassembly.h"
#import "CDAssemblyProcessor.h"
#import "CDLCSegment.h"
#import "CDObjectiveC1Processor.h"
#import "CDObjectiveC2Processor.h"

#import <sys/mman.h>
#include <mach-o/arch.h>
#import <mach/mach.h>
#include <sys/sysctl.h>
#include <regex.h>

@interface CDClassDump ()
@end

#pragma mark -

@implementation CDClassDump
{
    CDSearchPathState *_searchPathState;
    
    BOOL _shouldProcessRecursively;
    BOOL _shouldSortClasses; // And categories, protocols
    BOOL _shouldSortClassesByInheritance; // And categories, protocols
    BOOL _shouldSortMethods;
    
    BOOL _shouldShowIvarOffsets;
    BOOL _shouldShowMethodAddresses;
    BOOL _shouldShowHeader;
    
    NSRegularExpression *_regularExpression;
    
    NSString *_sdkRoot;
    NSMutableArray *_machOFiles;
    NSMutableDictionary *_machOFilesByName;
    NSMutableArray *_objcProcessors;
    
    CDTypeController *_typeController;
    
    CDArch _targetArch;
    
    regex_t compiledRegex;
    BOOL shouldMatchRegex;
    BOOL shouldDecompile;
    NSString *decompileArch;
    CDOCModule *curMod;
    CDOCClass *curClass;
    CDHeaderIndex *lookupTable;
   	NSDictionary* lookupDict;
    NSMutableArray *allclasses;
    CDTypeFormatter *methodTypeFormatter;
}

- (id)init;
{
    if ((self = [super init])) {
        _searchPathState = [[CDSearchPathState alloc] init];
        _sdkRoot = nil;
        
        _machOFiles = [[NSMutableArray alloc] init];
        _machOFilesByName = [[NSMutableDictionary alloc] init];
        _objcProcessors = [[NSMutableArray alloc] init];
        
        _typeController = [[CDTypeController alloc] initWithClassDump:self];
        
        // These can be ppc, ppc7400, ppc64, i386, x86_64
        _targetArch.cputype = CPU_TYPE_ANY;
        _targetArch.cpusubtype = 0;
        
        _shouldShowHeader = YES;

        shouldDecompile = NO;
        allclasses = [[NSMutableArray alloc] init];
        
        methodTypeFormatter = [[CDTypeFormatter alloc] init];
        [methodTypeFormatter setShouldExpand:NO];
        [methodTypeFormatter setShouldAutoExpand:NO];
        [methodTypeFormatter setBaseLevel:0];
//        [methodTypeFormatter setDelegate:self];

    }

    return self;
}

#pragma mark -

@synthesize searchPathState;
@synthesize shouldProcessRecursively;
@synthesize shouldSortClasses;
@synthesize shouldSortClassesByInheritance;
@synthesize shouldSortMethods;
@synthesize shouldShowIvarOffsets;
@synthesize shouldShowMethodAddresses;
@synthesize shouldShowHeader;

@synthesize regularExpression;

@synthesize shouldDecompile;
@synthesize decompileArch;
@synthesize methodTypeFormatter;

#pragma mark - Regular expression handling

- (BOOL)shouldShowName:(NSString *)name;
{
    if (self.regularExpression != nil) {
        NSTextCheckingResult *firstMatch = [self.regularExpression firstMatchInString:name options:0 range:NSMakeRange(0, [name length])];
        return firstMatch != nil;
    }

    return YES;
}

#pragma mark -

- (BOOL)containsObjectiveCData;
{
    for (CDObjectiveCProcessor *processor in self.objcProcessors) {
        if ([processor hasObjectiveCData])
            return YES;
    }

    return NO;
}

- (BOOL)hasEncryptedFiles;
{
    for (CDMachOFile *machOFile in self.machOFiles) {
        if ([machOFile isEncrypted]) {
            return YES;
        }
    }

    return NO;
}

- (BOOL)hasObjectiveCRuntimeInfo;
{
    return self.containsObjectiveCData || self.hasEncryptedFiles;
}

- (BOOL)loadFile:(CDFile *)file;
{
    //NSLog(@"targetArch: (%08x, %08x)", targetArch.cputype, targetArch.cpusubtype);
    CDMachOFile *aMachOFile = [file machOFileWithArch:_targetArch];
    //NSLog(@"aMachOFile: %@", aMachOFile);
    if (aMachOFile == nil) {
        fprintf(stderr, "Error: file doesn't contain the specified arch.\n\n");
        return NO;
    }

    // Set before processing recursively.  This was getting caught on CoreUI on 10.6
    assert([aMachOFile filename] != nil);
    [_machOFiles addObject:aMachOFile];
    _machOFilesByName[aMachOFile.filename] = aMachOFile;

    if ([self shouldProcessRecursively]) {
        @try {
            for (CDLoadCommand *loadCommand in [aMachOFile loadCommands]) {
                if ([loadCommand isKindOfClass:[CDLCDylib class]]) {
                    CDLCDylib *aDylibCommand = (CDLCDylib *)loadCommand;
                    if ([aDylibCommand cmd] == LC_LOAD_DYLIB) {
                        [self.searchPathState pushSearchPaths:[aMachOFile runPaths]];
                        [self machOFileWithName:[aDylibCommand path]]; // Loads as a side effect
                        [self.searchPathState popSearchPaths];
                    }
                }
            }
        }
        @catch (NSException *exception) {
            NSLog(@"Caught exception: %@", exception);
            return NO;
        }
    }

    return YES;
}

#pragma mark -

- (void)processObjectiveCData;
{
    for (CDMachOFile *machOFile in self.machOFiles) {
        CDObjectiveCProcessor *aProcessor = [[[machOFile processorClass] alloc] initWithMachOFile:machOFile];
        [aProcessor process];
        [_objcProcessors addObject:aProcessor];

        // Braden 5/6/06
        // adding classes to classdump
        [allclasses addObjectsFromArray:[aProcessor classes]];
    }
}

// This visits everything segment processors, classes, categories.  It skips over modules.  Need something to visit modules so we can generate separate headers.
- (void)recursivelyVisit:(CDVisitor *)visitor;
{
    [visitor willBeginVisiting];

    for (CDObjectiveCProcessor *processor in self.objcProcessors) {
        [processor recursivelyVisit:visitor];
    }

    [visitor didEndVisiting];
}

- (CDMachOFile *)machOFileWithName:(NSString *)name;
{
    NSString *adjustedName = nil;
    NSString *executablePathPrefix = @"@executable_path";
    NSString *rpathPrefix = @"@rpath";

    if ([name hasPrefix:executablePathPrefix]) {
        adjustedName = [name stringByReplacingOccurrencesOfString:executablePathPrefix withString:self.searchPathState.executablePath];
    } else if ([name hasPrefix:rpathPrefix]) {
        //NSLog(@"Searching for %@ through run paths: %@", anID, [searchPathState searchPaths]);
        for (NSString *searchPath in [self.searchPathState searchPaths]) {
            NSString *str = [name stringByReplacingOccurrencesOfString:rpathPrefix withString:searchPath];
            //NSLog(@"trying %@", str);
            if ([[NSFileManager defaultManager] fileExistsAtPath:str]) {
                adjustedName = str;
                //NSLog(@"Found it!");
                break;
            }
        }
        if (adjustedName == nil) {
            adjustedName = name;
            //NSLog(@"Did not find it.");
        }
    } else if (self.sdkRoot != nil) {
        adjustedName = [self.sdkRoot stringByAppendingPathComponent:name];
    } else {
        adjustedName = name;
    }

    CDMachOFile *machOFile = _machOFilesByName[adjustedName];
    if (machOFile == nil) {
        NSData *data = [[NSData alloc] initWithContentsOfMappedFile:adjustedName];
        CDFile *aFile = [CDFile fileWithData:data filename:adjustedName searchPathState:self.searchPathState];

        if (aFile == nil || [self loadFile:aFile] == NO)
            NSLog(@"Warning: Failed to load: %@", adjustedName);

        machOFile = _machOFilesByName[adjustedName];
        if (machOFile == nil) {
            NSLog(@"Warning: Couldn't load MachOFile with ID: %@, adjustedID: %@", name, adjustedName);
        }
    }

    return machOFile;
}

- (void)appendHeaderToString:(NSMutableString *)resultString;
{
    // Since this changes each version, for regression testing it'll be better to be able to not show it.
    if (self.shouldShowHeader == NO)
        return;

    [resultString appendString:@"/*\n"];
    [resultString appendFormat:@" *     Generated by class-dump %s.\n", CLASS_DUMP_VERSION];
    [resultString appendString:@" *\n"];
    [resultString appendString:@" *     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2012 by Steve Nygard.\n"];
    [resultString appendString:@" */\n\n"];

    if (self.sdkRoot != nil) {
        [resultString appendString:@"/*\n"];
        [resultString appendFormat:@" * SDK Root: %@\n", self.sdkRoot];
        [resultString appendString:@" */\n\n"];
    }
}

- (void)registerTypes;
{
    for (CDObjectiveCProcessor *processor in self.objcProcessors) {
        [processor registerTypesWithObject:self.typeController phase:0];
    }
    [self.typeController endPhase:0];

    [self.typeController workSomeMagic];
}

- (void)showHeader;
{
    if ([self.machOFiles count] > 0) {
        [[[self.machOFiles lastObject] headerString:YES] print];
    }
}

- (void)showLoadCommands;
{
    if ([self.machOFiles count] > 0) {
        [[[self.machOFiles lastObject] loadCommandString:YES] print];
    }
}

#pragma mark - Decompile Methods
- (void)buildLookupTable
{		
    // TODO: can't currently cache lookup table cuz NSXMLDocument doesn't support NSCoding
    //	if ([[NSFileManager defaultManager] fileExistsAtPath:[@"~/Library/Caches/ClassDumpLookupTable" stringByExpandingTildeInPath]])
    //		lookupTable = [NSUnarchiver unarchiveObjectWithFile:[@"~/Library/Caches/ClassDumpLookupTable" stringByExpandingTildeInPath]];
	
	NSLog(@"Building lookup table...");
	NSMutableArray* paths = [[NSMutableArray alloc] initWithObjects:@"/System/Library/Frameworks/",nil];
	lookupTable = [[CDHeaderIndex alloc] init];
    
	NSMutableArray* bridgepathArray=[NSMutableArray array];
	NSMutableArray* headerpathArray=[NSMutableArray array];
	int i;
	for (i=0;i<[paths count];i++)
	{
		NSDirectoryEnumerator* direnum = [[NSFileManager defaultManager] enumeratorAtPath:[paths objectAtIndex:i]];
		if (!direnum)
			return;
		NSString* pname;
		while ((pname = [direnum nextObject]))
			if ([[pname pathExtension] isEqualToString:@"bridgesupport"] && ![[[pname lastPathComponent] stringByDeletingPathExtension] isEqualToString:@"PyObjCOverrides"])
				[bridgepathArray addObject:[[paths objectAtIndex:i] stringByAppendingPathComponent:pname]];
			else if ([[pname pathExtension] isEqualToString:@"h"])
				[headerpathArray addObject:[[paths objectAtIndex:i] stringByAppendingPathComponent:pname]];
        
	}
    // Here we just look for duplicates and get rid of them
	for (i=0;i<[bridgepathArray count];i++)
	{
		NSString* path = [bridgepathArray objectAtIndex:i];
		NSString* fullPath = [[NSString alloc] initWithFormat:@"%@/%@Full.bridgesupport",[path stringByDeletingLastPathComponent],[[path lastPathComponent] stringByDeletingPathExtension]];
		if ([bridgepathArray containsObject:fullPath]) {
			[bridgepathArray removeObjectAtIndex:i];
			i=0;
		}
	}

	for (NSString* path in bridgepathArray)
	{
        NSError *error;
        NSString* frameworkFile = [[NSMutableString alloc] initWithContentsOfFile:path encoding:NSASCIIStringEncoding error:&error];
		//NSLog(@"Adding framework file: %@", path);
        [lookupTable addHeaderData:frameworkFile];
	}

	for (i=0;i<[bridgepathArray count];i++) [bridgepathArray removeObjectAtIndex:i];

	for (NSString* path in headerpathArray)
	{
        NSError *error;
        NSString* frameworkFile = [[NSMutableString alloc] initWithContentsOfFile:path encoding:NSASCIIStringEncoding error:&error];
		//NSLog(@"Adding framework file: %@", path);
		[lookupTable addSubclassData:frameworkFile];
	}
    for (i=0;i<[headerpathArray count];i++) [headerpathArray removeObjectAtIndex:i];
    
    //	[NSArchiver archiveRootObject:lookupTable toFile:[@"~/Library/Caches/ClassDumpLookupTable" stringByExpandingTildeInPath]];
	
	NSLog(@"Finished lookup table");
}

- (void)buildLookupTableFromPPC
{
	NSMutableDictionary* output = [[NSMutableDictionary alloc] init];
	NSMutableDictionary* outClass = [[NSMutableDictionary alloc] init];
	NSMutableDictionary* outSelector = [[NSMutableDictionary alloc] init];
	NSMutableDictionary* outSubclass = [[NSMutableDictionary alloc] init];
    
	NSMutableArray* paths = [[NSMutableArray alloc] init];
	[paths addObject:@"/System/Library/Frameworks/Foundation.framework/Headers/"];
	[paths addObject:@"/System/Library/Frameworks/AppKit.framework/Headers/"];
    
	int i;
	for (i=0;i<[paths count];i++)
	{
		NSDirectoryEnumerator* direnum = [[NSFileManager defaultManager] enumeratorAtPath:[paths objectAtIndex:i]];
		if (!direnum)
			return;
		NSString* pname;
		while ((pname = [direnum nextObject]))
			if ([pname hasSuffix:@".h"])
			{
				NSString* path = [[NSString alloc] initWithFormat:@"%@%@",[paths objectAtIndex:i],pname,nil];
                NSError *error;
                NSString* frameworkFile = [[NSMutableString alloc] initWithContentsOfFile:path encoding:NSASCIIStringEncoding error:&error];
				NSArray* lineArray = [frameworkFile componentsSeparatedByString:@"\n"];
				NSEnumerator* lineEnum = [lineArray objectEnumerator];
				NSString* line;
				while ((line = [lineEnum nextObject]))
				{
					// this allows for searching for paths based on class name
					if ([line hasPrefix:@"@interface "])
					{
						NSString* className = [line substringFromIndex:11];
						
						NSRange spFound = [className rangeOfString:@" "];
						if (spFound.location!=NSNotFound)
							className = [className substringToIndex:spFound.location];
						NSRange parFound = [className rangeOfString:@"("];
						if (parFound.location!=NSNotFound)
							className = [className substringToIndex:parFound.location];
						spFound = [className rangeOfString:@":"];
						if (spFound.location!=NSNotFound)
							className = [className substringToIndex:spFound.location];
                        
                        // add subclasses to subclass dict
						NSString* subClasses=nil;
						if ([line length]>12+[className length])
						{
							subClasses = [line substringFromIndex:11+[className length]];
							NSRange protFind = [subClasses rangeOfString:@"<"];
							if (protFind.location!=NSNotFound)
								subClasses = [subClasses substringToIndex:protFind.location];
							while ([subClasses hasPrefix:@":"]||[subClasses hasPrefix:@" "])
								subClasses = [subClasses substringFromIndex:1];
							while ([subClasses hasSuffix:@" "]||[subClasses hasSuffix:@"{"]||[subClasses hasSuffix:@"}"])
								subClasses = [subClasses substringToIndex:[subClasses length]-1];
							
							if (!([subClasses hasPrefix:@"("]||[subClasses hasSuffix:@")"]))
								[outSubclass setObject:[[NSString alloc] initWithString:subClasses] forKey:className];
							else 
								subClasses = nil;
						}
                        
						// class name maps to multiple files :=/
						NSMutableArray* current = [outClass objectForKey:className];
						if (current==nil)
							[outClass setObject:[[NSMutableArray alloc] initWithObjects:path,nil] forKey:className];
						else
							[current addObject:path];
					}
					// this allows for searching for funcdefs based on selector name (w/o knowing object)
					if (([line hasPrefix:@"+ ("])||([line hasPrefix:@"- ("]))
					{
						NSString* searchStr = [CDClassDump genSearchStrWithDef:line];
						if (searchStr)
						{
							// selectors can map to multiple function def's
							NSMutableArray* current = [outSelector objectForKey:searchStr];
							if (current==nil)
								[outSelector setObject:[[NSMutableArray alloc] initWithObjects:[[NSString alloc] initWithString:line],nil] forKey:searchStr];
							else
								[current addObject:[[NSString alloc] initWithString:line]];
						}
					}
				}
            }
    }
	[output setObject:outClass forKey:@"class"];
	[output setObject:outSelector forKey:@"selector"];
	[output setObject:outSubclass forKey:@"subclass"];
	
	lookupDict = [[NSDictionary alloc] initWithDictionary:output];
}

- (void)generateDecompile
{
    // If there is no decompiler arch specified, we assume that we want to decompile for the same arch we are running on.
    // TODO: Extend this so that it tests the file's arch first and just decompiles the first one if there are no matches.
	if (!decompileArch) {
		const NXArchInfo *archInfo = NXGetLocalArchInfo();
		if (archInfo->cputype==NXGetArchInfoFromName("x86_64")->cputype)
			decompileArch=@"x86_64";
        else if (archInfo->cputype==NXGetArchInfoFromName("i386")->cputype)
        {
            cpu_type_t  cpuType=0;
            size_t      cpuTypeSize;
            int         mib[CTL_MAXNAME];
            size_t      mibLen;
            mibLen  = CTL_MAXNAME;
            int err = sysctlnametomib("sysctl.proc_cputype", mib, &mibLen);
            if (err == -1) {
                err = errno;
            }
            if (err == 0) {
                assert(mibLen < CTL_MAXNAME);
                mib[mibLen] = getpid();
                mibLen += 1;

                cpuTypeSize = sizeof(cpuType);
                err = sysctl(mib, mibLen, &cpuType, &cpuTypeSize, NULL, 0);
                if (err == -1) {
                    err = errno;
                }
            }

            if (cpuType == CPU_TYPE_X86_64)
            {
                decompileArch=@"x86_64";
            }
            else decompileArch=@"i386";
        }
		else if (archInfo->cputype==NXGetArchInfoFromName("ppc")->cputype)
			decompileArch=@"ppc";
		else if (archInfo->cputype==NXGetArchInfoFromName("arm")->cputype)	
			decompileArch=@"arm";
		else if (archInfo->cputype==NXGetArchInfoFromName("armv6")->cputype)	
			decompileArch=@"armv6";
		else if (archInfo->cputype==NXGetArchInfoFromName("armv7")->cputype)	
			decompileArch=@"armv7";
	}
	[self buildLookupTable];
	
	NSMutableString *resultString = [[NSMutableString alloc] init];
    
	NSEnumerator *procEnum = [_objcProcessors objectEnumerator];
	CDObjectiveCProcessor *proc;
    
	while ((proc = [procEnum nextObject]))
	{
		// fixes indirect symbols
		[[proc machOFile] fixupIndirectSymbols];
		// fixes relocations
		[[proc machOFile] fixupRelocs];
        
		NSEnumerator* loadEnum=[[[proc machOFile] loadCommands] objectEnumerator];
		CDLoadCommand* com;
		CDSection* textSec=nil;
		while ((com = [loadEnum nextObject]))
		{
			if ((![com isKindOfClass:[CDLCSegment class]]) || (![com isKindOfClass:[CDLCSegment64 class]]))
				continue;
			CDLCSegment* segcom = (CDLCSegment*)com;
			if ([[segcom name] isEqualToString:@"__TEXT"])
			{
				textSec = [segcom sectionWithName:@"__text"];
				if (textSec)
					break;
			}
		}
        
		CDDisassembly* theAsm;
		if ([decompileArch isEqualToString:@"ppc"])
			theAsm = [[CDPPCDisassembly alloc] initWithFile:[[proc machOFile] filename]];
		else if ([decompileArch isEqualToString:@"x86_64"])
			theAsm = [[CDX8664Disassembly alloc] initWithFile:[[proc machOFile] filename]];
		else if ([decompileArch isEqualToString:@"i386"])
			theAsm = [[CDX86Disassembly alloc] initWithFile:[[proc machOFile] filename]];
		else if ([decompileArch isEqualToString:@"arm"])
			theAsm = [[CDARMDisassembly alloc] initWithFile:[[proc machOFile] filename]];
		else if ([decompileArch isEqualToString:@"armv6"])
			theAsm = [[CDARMV6Disassembly alloc] initWithFile:[[proc machOFile] filename]];
		else if ([decompileArch isEqualToString:@"armv7"])
			theAsm = [[CDARMV7Disassembly alloc] initWithFile:[[proc machOFile] filename]];
        
		if (!theAsm) {
			printf("Error: Unable to get disassembly of binary");
			return;
		}	
        
		[theAsm getDisassemblyForHeader:nil atOffset:nil];
		// text section is used for backup in case disassembly using otool fails
		[theAsm setSection:textSec];
		
		CDAssemblyProcessor* asmProc = [[CDAssemblyProcessor alloc] initWithDisassembly:theAsm andArchitecture:decompileArch];
		NSLog(@"%@",asmProc);
		
        if ([proc isKindOfClass:[CDObjectiveC1Processor class]])
        {
            // enumerate file's modules
            NSEnumerator* modEnum = [[(CDObjectiveC1Processor *)proc modules] objectEnumerator];
            CDOCModule *mod;
            while ((mod = [modEnum nextObject]))
            {
                //NSLog(@"print decom %@",mod);
                [mod printDecompilation:asmProc classDump:self resString:resultString file:[proc machOFile]];
            }
        }
        else if ([proc isKindOfClass:[CDObjectiveC2Processor class]])
        {
            // enumerate file's classes
            NSEnumerator* classEnum = [[(CDObjectiveC2Processor *)proc classes] objectEnumerator];
            CDOCClass *class;
            while ((class = [classEnum nextObject]))
            {
                //NSLog(@"print decom %@",[class name]);
                [class printDecompilation:asmProc classDump:self resString:resultString file:[proc machOFile]];
            }
        }
	}
	
	NSData* data = [resultString dataUsingEncoding:NSUTF8StringEncoding];
    [(NSFileHandle *)[NSFileHandle fileHandleWithStandardOutput] writeData:data];
}

- (BOOL)shouldMatchRegex;
{
    return shouldMatchRegex;
}

- (void)setShouldMatchRegex:(BOOL)newFlag;
{
    if (shouldMatchRegex == YES && newFlag == NO)
        regfree(&compiledRegex);
    
    shouldMatchRegex = newFlag;
}

- (BOOL)setRegex:(char *)regexCString errorMessage:(NSString **)errorMessagePointer;
{
    int result;
    
    if (shouldMatchRegex == YES)
        regfree(&compiledRegex);
    
    result = regcomp(&compiledRegex, regexCString, REG_EXTENDED);
    if (result != 0) {
        char regex_error_buffer[256];
        
        if (regerror(result, &compiledRegex, regex_error_buffer, 256) > 0) {
            if (errorMessagePointer != NULL) {
                *errorMessagePointer = [NSString stringWithCString:regex_error_buffer encoding:NSASCIIStringEncoding];
            }
        } else {
            if (errorMessagePointer != NULL)
                *errorMessagePointer = nil;
        }
        
        return NO;
    }
    
    [self setShouldMatchRegex:YES];
    
    return YES;
}

- (BOOL)regexMatchesString:(NSString *)aString;
{
    int result;
    
    result = regexec(&compiledRegex, [aString UTF8String], 0, NULL, 0);
    if (result != 0) {
        if (result != REG_NOMATCH) {
            char regex_error_buffer[256];
            
            if (regerror(result, &compiledRegex, regex_error_buffer, 256) > 0)
                NSLog(@"Error with regex matching string, %@", [NSString stringWithCString:regex_error_buffer encoding:NSASCIIStringEncoding]);
        }
        
        return NO;
    }
    
    return YES;
}

+ (NSString*)genSearchStrWithDef:(NSString*)def
{
	// invalid definition
	NSRange semiRange = [def rangeOfString:@";"];
	if (semiRange.location==NSNotFound)
		return nil;
    
	// remove ';'
	// autoreleased
	def = [def substringToIndex:semiRange.location];
	
	// autoreleased
	NSArray* defComp = [def componentsSeparatedByString:@":"];	
	NSMutableString* strOut = [[NSMutableString alloc] init];
    
	int i;
	for (i=0;i<[defComp count];i++)
	{
		NSString* curComp = [defComp objectAtIndex:i];
		
		NSRange typeRange = [curComp rangeOfString:@"("];
		if (typeRange.location!=NSNotFound)
		{
			NSRange typeEndRange = [curComp rangeOfString:@")" options:0 range:NSMakeRange(typeRange.location,[curComp length]-typeRange.location)];
            
			if ((typeEndRange.location==NSNotFound)||(typeEndRange.location>[curComp length]-2))
				return nil;
            
			NSRange spRange = [curComp rangeOfString:@" " options:0 range:NSMakeRange(typeEndRange.location+1,[curComp length]-typeEndRange.location-1)];
            
			if ((spRange.location!=NSNotFound)&&(spRange.location<[curComp length]-2))
			{
				if ([[curComp substringFromIndex:spRange.location+1] isEqualToString:@"..."])
					continue;
				[strOut appendString:[curComp substringFromIndex:spRange.location+1]];
			}
			else if (i<[defComp count]-1)
				[strOut appendString:[curComp substringFromIndex:typeEndRange.location+1]];
			else if ([defComp count]==1)
				[strOut appendString:[curComp substringFromIndex:typeEndRange.location+1]];
		}
		else
			[strOut appendString:curComp];
        
		if (([defComp count]>1)&&(i<[defComp count]-1))
			[strOut appendString:@":"];
	}
	
	return strOut;
}

- (CDHeaderIndex*)lookupTable
{
	return lookupTable;
}

- (NSDictionary*)lookupDict
{
	return lookupDict;
}

- (CDOCModule*)curMod
{
	return curMod;
}

- (void)setCurMod:(CDOCModule*)a
{
	curMod = a;
}

- (NSMutableArray*)allclasses
{
	return allclasses;
}

- (CDOCClass*)curClass
{
	return curClass;
}

- (void)setCurClass:(CDOCClass*)a
{
	curClass = a;
}

@end
