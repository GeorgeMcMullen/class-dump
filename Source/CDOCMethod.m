// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2012 Steve Nygard.

#import "CDOCMethod.h"

#import "CDClassDump.h"
#import "CDTypeFormatter.h"
#import "CDTypeParser.h"
#import "CDTypeController.h"

#import "CDLine.h"
#import "CDRegVal.h"
#import "CDSelector.h"
#import "CDMachOFile.h"
#import "CDOCClass.h"
//#import "CDSymbol.h"
#import "CDLCSymbolTable.h"
#import "CDInstructionSimulator.h"
#import "CDPPCSimulator.h"
#import "CDX86Simulator.h"
#import "CDX8664Simulator.h"
#import "CDARMSimulator.h"
#import "CDARMV6Simulator.h"
#import "CDARMV7Simulator.h"
#import "CDInstructionFormatter.h"

@implementation CDOCMethod
{
    NSString *_name;
    NSString *_type;
    NSUInteger _imp;
    
    BOOL _hasParsedType;
    NSArray *_parsedMethodTypes;
    
    NSMutableDictionary *_stack;
}

@synthesize stack;

- (id)init;
{
    [NSException raise:@"RejectUnusedImplementation" format:@"-initWithName:type:imp: is the designated initializer"];
    return nil;
}

- (id)initWithName:(NSString *)name type:(NSString *)type imp:(NSUInteger)imp;
{
    if ((self = [self initWithName:name type:type])) {
        [self setImp:imp];
    }

    return self;
}

- (id)initWithName:(NSString *)name type:(NSString *)type;
{
    if ((self = [super init])) {
        _name = name;
        _type = type;
        _imp = 0;
        
        _hasParsedType = NO;
        _parsedMethodTypes = nil;
        _stack = [[NSMutableDictionary alloc] init];
    }

    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone;
{
    return [[CDOCMethod alloc] initWithName:self.name type:self.type imp:self.imp];
}

#pragma mark - Debugging

- (NSString *)description;
{
    return [NSString stringWithFormat:@"[%@] name: %@, type: %@, imp: 0x%016lx",
            NSStringFromClass([self class]), self.name, self.type, self.imp];
}

#pragma mark -

- (NSArray *)parsedMethodTypes;
{
    if (_hasParsedType == NO) {
        NSError *error = nil;

        CDTypeParser *parser = [[CDTypeParser alloc] initWithType:self.type];
        _parsedMethodTypes = [parser parseMethodType:&error];
        if (_parsedMethodTypes == nil)
            NSLog(@"Warning: Parsing method types failed, %@", self.name);
        _hasParsedType = YES;
    }

    return _parsedMethodTypes;
}

- (void)appendToString:(NSMutableString *)resultString typeController:(CDTypeController *)typeController;
{
    NSString *formattedString = [typeController.methodTypeFormatter formatMethodName:self.name type:self.type];
    if (formattedString != nil) {
        [resultString appendString:formattedString];
        [resultString appendString:@";"];
        if (typeController.shouldShowMethodAddresses && self.imp != 0) {
            if (typeController.targetArchUses64BitABI)
                [resultString appendFormat:@"\t// IMP=0x%016lx", self.imp];
            else
                [resultString appendFormat:@"\t// IMP=0x%08lx", self.imp];
        }
    } else
        [resultString appendFormat:@"    // Error parsing type: %@, name: %@", self.type, self.name];
}

#pragma mark - Sorting

- (NSComparisonResult)ascendingCompareByName:(CDOCMethod *)otherMethod;
{
    return [self.name compare:otherMethod.name];
}

#pragma mark - Decompilation
- (void)printDecompilation:(CDAssemblyProcessor*)disasm classDump:(CDClassDump *)aClassDump resString:(NSMutableString*)resultString file:(CDMachOFile*)mach forClass:(CDOCClass*)class
{
	NSLog(@"Decompiling %@\n",_name);
    
    NSString *formattedString;
	formattedString = [[aClassDump methodTypeFormatter] formatMethodName:_name type:_type];
	if (formattedString == nil)
	{
		[resultString appendFormat:@"    // Error parsing type: %@, name: %@", _type, _name];
		return;
	}
	[resultString appendString:formattedString];
	[resultString appendString:@"\n{\n"];
    
	// determine whether this function has a return value
	BOOL retValue = ([_type characterAtIndex:0]!='v');
    
    //	BOOL firstLine = YES;
	CDInstructionSimulator* instrSimulator;
	CDInstructionFormatter* instrFormatter;
	
	if ([[aClassDump decompileArch] isEqualToString:@"x86_64"])
		instrSimulator = [[CDX8664Simulator alloc] initWithAssembly:disasm file:mach meth:self class:class cd:aClassDump retValue:retValue];
	else if ([[aClassDump decompileArch] isEqualToString:@"i386"])
		instrSimulator = [[CDX86Simulator alloc] initWithAssembly:disasm file:mach meth:self class:class cd:aClassDump retValue:retValue];
	else if ([[aClassDump decompileArch] isEqualToString:@"ppc"])
		instrSimulator = [[CDPPCSimulator alloc] initWithAssembly:disasm file:mach meth:self class:class cd:aClassDump retValue:retValue];
	else if ([[aClassDump decompileArch] isEqualToString:@"arm"])
		instrSimulator = [[CDARMSimulator alloc] initWithAssembly:disasm file:mach meth:self class:class cd:aClassDump retValue:retValue];
	else if ([[aClassDump decompileArch] isEqualToString:@"armv6"])
		instrSimulator = [[CDARMV6Simulator alloc] initWithAssembly:disasm file:mach meth:self class:class cd:aClassDump retValue:retValue];
	else if ([[aClassDump decompileArch] isEqualToString:@"armv7"])
		instrSimulator = [[CDARMV7Simulator alloc] initWithAssembly:disasm file:mach meth:self class:class cd:aClassDump retValue:retValue];
	else {
		NSLog(@"Unknown decompilation architecture: %@",[aClassDump decompileArch]);
		exit(-1);
	}
	instrFormatter=[[CDInstructionFormatter alloc] initWithSimulator:instrSimulator];
    
	[instrSimulator simulateInstructions];
	[instrFormatter appendDecompile:resultString];
	[resultString appendString:@"}\n"];
}


- (void)appendLines:(NSArray*)lineArray toString:(NSMutableString*)resultString ret:(BOOL)retValue file:(CDMachOFile*)mach
{
	NSEnumerator* lineEnum = [lineArray objectEnumerator];
	CDLine* line;
	// popTargets is used to keep track of how many entries need to be popped off of the bTargets array
	//int popTargets = 0;
	BOOL getLine = YES;
	BOOL hitReturn = NO;
	NSUInteger lastTargs=0;
	while (1)
	{
		if (getLine)
			line = [lineEnum nextObject];
		else
			getLine = YES;
        
		if (line == nil)
			break;
		
		if ([line showMe]==NO)
			continue;
		
		NSUInteger toTab=[[line bTarget] count];
        
		// this kludge fixup the toTab value
		// ugly kludge
		NSRange parenRange = [[line data] rangeOfString:@"{"];
		if (parenRange.location!=NSNotFound)
			toTab--;	
        
		//NSLog(@"toTab: %d\n",toTab);
		int i;
        
		if (!hitReturn)
			for (i=0;i<toTab+1;i++)
				[resultString appendString:@"\t"];
        
		//NSLog(@"line %@\n",[line data]);
		//NSLog(@"on offset %x btargetoff %x\n",[line offset],[[[line bTarget] lastObject] longValue]);
        
		if (lastTargs>toTab)
		{	
			NSUInteger missTab = lastTargs-toTab-1;
			for (i=0;i<missTab;i++)
				[resultString appendString:@"\t"];
            
			// this is a bugfix because currently no tabs on a paren after a return
			if (hitReturn)
				for (i=0;i<toTab+1;i++)
					[resultString appendString:@"\t"];			
			
			[resultString appendString:@"}\n"];
			lastTargs--;
			getLine = NO;
			hitReturn = NO;
			continue;
		}
		lastTargs = toTab;
        
		if ([[line data] isEqualToString:@"return"]&&hitReturn)
		{
			//NSLog(@"ignoring second return\n");
			[line setShow:NO];
		}
		else if ([[line data] isEqualToString:@"return"]&&!hitReturn)
		{
			hitReturn = YES;
			
			[resultString appendString:@"return "];
            
			NSString* outtype;
			NSString* object = [self lookupObject:3 line:line lineArray:lineArray file:mach outType:&outtype];
			//NSLog(@"looking up return value in lines %x %d\n",object,[object length]);
			[resultString appendFormat:@"%@;\n",object,nil];
		}
		else if (([line isSelectorLine])&&(!hitReturn))
		{
			if ([line isVoid])
			{
				//NSLog(@"%@ isvoid!\n",[line data]);
				NSString *frmtLine = [[NSString alloc] initWithFormat:@"%@;\n",[line data],nil];
				[resultString appendString:frmtLine];
			}
			else
			{
				NSString *frmtLine = [[NSString alloc] initWithFormat:@"%@ result_%ld = %@;\n",[line type],[lineArray indexOfObject:line],[line data],nil];
				[resultString appendString:frmtLine];
			}
		}
		else if (([line isSelectorLine])&&hitReturn)
		{
			[resultString appendString:[line data]];
			[resultString appendString:@";\n"];
            
			hitReturn=NO;
		}
		else if (![line isAsm])
		{
			[resultString appendString:[line data]];
			[resultString appendString:@"\n"];
		}
		else
		{
			[resultString appendString:@"\t//"];
			[resultString appendString:[line data]];
			[resultString appendString:@"\n"];
		}		
	}
	
	// close up any remaining parentheses that are necessary
	while (lastTargs>0)
	{
		int i;
		for (i=0;i<lastTargs;i++)
			[resultString appendString:@"\t"];
		[resultString appendString:@"}\n"];
		lastTargs--;
	}
}


- (BOOL)canCombine:(CDLine*)aLine otherLine:(CDLine*)bLine lineArray:(NSArray*)lines
{
	NSUInteger oldPos = [lines indexOfObject:bLine];
	if (oldPos==NSNotFound)
		return false;
	NSUInteger newPos = [lines indexOfObject:aLine];
	if (newPos==NSNotFound)
		return false;
	if (newPos < oldPos)
		return false;
	if ([bLine showMe]==NO)
		return false;
    
	BOOL isOk = YES;
	NSUInteger i;
	for (i=oldPos+1;i<newPos;i++)
	{
		if ([[lines objectAtIndex:i] showMe])
			isOk = NO;
	}
	// registers must be equal
	if (![aLine regEqualTo:bLine])
		isOk = NO;		
	return isOk;
}


- (NSString*)lookupObject:(int)reg line:(CDLine*)line lineArray:(NSArray*)lineArray file:(CDMachOFile*)mach outType:(NSString**)outType;
{
	*outType = [[NSString alloc] init];
	if ([[line regData:reg cond:NO] data])
	{
		uint32_t objValue = (uint32_t)[[line regData:reg cond:NO] value];
		
		NSString *object;		
		char *dataPtr = (char*)[mach pointerFromVMAddr:objValue];
		if (dataPtr==NULL)
		{
			if ([mach hasDifferentByteOrder]==YES)
			{
				objValue = CFSwapInt32(objValue);
				dataPtr = (char*)[mach pointerFromVMAddr:objValue];
				if (dataPtr==NULL)
				{
					if (objValue==0)
						return @"nil";
					// this is fugly
					if (objValue==1)
						return @"1";
					
					return @"UKNOWN_OBJECT";	
                    
				}
			}
			else
			{
				if (objValue==0)
					return @"nil";
				// this is fugly
				if (objValue==1)
					return @"1";
				
				return @"UKNOWN_OBJECT";				
			}			
		}
		
		// a null string
		if (*dataPtr==0)
		{
			// this may be an indirectly addressed symbol
			//lookup in symbol table					
			CDSymbol* symbol = [[mach sym] findByOffset:objValue];
			if (symbol!=nil)
			{
				// found symbol in global table
				// this is not actually data, but a reference to an indirectly linked symbol
				//NSLog(@"lookupobj found symbol %@\n",symbol);
                
				NSString* lineName = [symbol name];
				if ([lineName hasPrefix:@"_"]);
                lineName = [lineName substringFromIndex:1];
                
				// special case where constant CFString is loaded
				if ([lineName isEqualToString:@"__CFConstantStringClassReference"])
				{
					NSMutableString* constString;
					uint32_t cStringPtr;
					// adding 8 because constant CFStrings store their c-string pointers at +8 bytes
					dataPtr = (char*)[mach pointerFromVMAddr:objValue+8];					
					if (dataPtr!=NULL)
					{
						memcpy(&cStringPtr,dataPtr,4);
					    if ([mach hasDifferentByteOrder] == YES)
							cStringPtr = CFSwapInt32(cStringPtr);
						
						constString = [[NSMutableString alloc] initWithString:
                                        [[NSString alloc] initWithFormat:@"@\"%@\"",[[NSString alloc] initWithCString:[mach pointerFromVMAddr:cStringPtr] encoding:NSASCIIStringEncoding],nil]];
						// remove newlines
						[constString replaceOccurrencesOfString:@"\n" withString:@"\\n" options:0 range:NSMakeRange(0,[constString length])];
						return constString;
					}
				}
				// special case where constant NSString is loaded
				if ([lineName isEqualToString:@"_NSConstantStringClassReference"])
				{
					NSMutableString* constString;
					uint32_t cStringPtr;
					// adding 4 because constant NSStrings store their c-string pointers at +4 bytes
					dataPtr = (char*)[mach pointerFromVMAddr:objValue+4];
					if (dataPtr!=NULL)
					{
						memcpy(&cStringPtr,dataPtr,4);
					    if ([mach hasDifferentByteOrder] == YES)
							cStringPtr = CFSwapInt32(cStringPtr);
						
						//NSLog(@"got cstringptr %x\n",cStringPtr);
						constString = [[NSMutableString alloc] initWithString:
                                        [[NSString alloc] initWithFormat:@"@\"%@\"",[[NSString alloc] initWithCString:[mach pointerFromVMAddr:cStringPtr] encoding:NSASCIIStringEncoding],nil]];
						// remove newlines
						[constString replaceOccurrencesOfString:@"\n" withString:@"\\n" options:0 range:NSMakeRange(0,[constString length])];
						return constString;
					}
				}				
                
				return [[NSString alloc] initWithFormat:@"&%@",lineName,nil];
			}
			else
				return [[NSString alloc] initWithFormat:@"nil(0x%x)",objValue,nil];
		}
		
		object = [[NSString alloc] initWithCString:dataPtr encoding:NSASCIIStringEncoding];
		return object;
	}
	else if ([[line regData:reg cond:NO] isSelf])
	{
		return @"self";
	}
	else if ([[line regData:reg cond:NO] isLineRef])					// see if object is result of previous function
	{
		NSLog(@"lookup lineref\n");
		NSString* object;
		int lineNum = [[line regData:reg cond:NO] lineRef];
#ifdef DEBUG		
		NSLog(@"lookup object is lineref to %d\n",lineNum);
#endif		
		if ([self canCombine:line otherLine:[lineArray objectAtIndex:lineNum] lineArray:lineArray])
		{
			// make the result the new object
			object = [[NSString alloc] initWithString:[(CDLine*)[lineArray objectAtIndex:lineNum] data]];
			// remove old line from shown lines b/c incorporated into new
			[[lineArray objectAtIndex:lineNum] setShow:NO];
			// set type of new line to old line
			*outType = [[NSString alloc] initWithString:[(CDOCMethod*)[lineArray objectAtIndex:lineNum] type]];
		}
		// this is false when it's a class data field
		else if ([[lineArray objectAtIndex:lineNum] showMe]==NO)
		{
			// make the result the name of the class variable
			object = [[NSString alloc] initWithString:[(CDLine*)[lineArray objectAtIndex:lineNum] data]];
			*outType = [[NSString alloc] initWithString:[(CDOCMethod*)[lineArray objectAtIndex:lineNum] type]];
		}
		else
		{
			object = [[NSString alloc] initWithFormat:@"result_%d",lineNum];
		}
		return object;
	}
    
	return @"UKNOWN_OBJECT";
}

@end
