//
//  CDLine.m
//  class-dump
//
//  Created by Braden Thomas on 4/7/06.
//

#import "CDLine.h"
#import "CDRegVal.h"
#import "CDSymbol.h"
#import "CDLCSymbolTable.h"

@implementation CDLine

- (id)init:(CDLCSymbolTable*)symTab
{
	if ([super init]==nil)
		return nil;
	
	sym = symTab;
	data = [[NSMutableString alloc] init];
	type = [[NSMutableString alloc] init];
	bTarget = [[NSMutableArray alloc] init];
	reg = [[NSMutableArray alloc] initWithCapacity:32];
	creg = [[NSMutableArray alloc] initWithCapacity:8];
	int i;
	for (i=0;i<32;i++)
		[reg addObject:[[CDRegVal alloc] initInvalid]];
	for (i=0;i<8;i++)
		[creg addObject:[[CDRegVal alloc] initInvalid]];		
	ctrReg = [[CDRegVal alloc] initInvalid];
	opCache = nil;
	offset	=	0;
	pOffset	=	NO;
	showMe	=	YES;
	isBranch=	NO;
	isAsm	=	YES;
		
	return self;
}

- (id)init:(CDLCSymbolTable*)symTab withData:(NSString*)inData
{
	if ([self init:symTab]==nil)
		return nil;
		
	[data setString:inData];

	return self;
}

- (id)init:(CDLCSymbolTable*)symTab withData:(NSString*)inData offset:(long)inOff
{
	if ([self init:symTab]==nil)
		return nil;
		
	[data setString:inData];
	offset = inOff;

	return self;
}

- (id)initWithData:(NSString*)inData offset:(long)inOff old:(CDLine*)inOld
{
	if ([self init:[inOld symTab]]==nil)
		return nil;
		
	[data setString:inData];
	offset = inOff;
	[reg setArray:[inOld regs]];
	[creg setArray:[inOld cregs]];
	[bTarget setArray:[inOld bTarget]];
	[self setCtrData:[inOld ctrData]];

	return self;
}

- (CDLCSymbolTable*)symTab
{
	return sym;
}

- (void)setReg:(CDLine*)inOld
{
	[reg setArray:[inOld regs]];
	[creg setArray:[inOld cregs]];
	[bTarget setArray:[inOld bTarget]];
	[self setCtrData:[inOld ctrData]];
}

- (BOOL)regEqualTo:(CDLine*)b
{
	int i;
	for (i=9;i<32;i++)		// only check if registers r9-r31 have changed (arbitrary)
	{
		if (![[reg objectAtIndex:i] isEqualTo:[[b regs] objectAtIndex:i]])
			return NO;
	}
	for (i=0;i<8;i++)		// check compare registers too
	{
		if (![[creg objectAtIndex:i] isEqualTo:[[b cregs] objectAtIndex:i]])
			return NO;
	}
	return YES;
}

- (NSMutableArray*)regs
{
	return reg;
}

- (NSMutableArray*)cregs
{
	return creg;
}

- (NSMutableArray*)bTarget
{
	return bTarget;
}

- (void)setReg:(int)regNum data:(CDRegVal*)regData cond:(BOOL)isCond
{
	if (isCond)
	{
		if ((regNum<8)&&(regNum>=0))
			[creg replaceObjectAtIndex:regNum withObject:regData];
	}
	else
	{
		if ((regNum<32)&&(regNum>=0))
			[reg replaceObjectAtIndex:regNum withObject:regData];
	}
}

- (void)setOffset:(long)inOff
{
	offset = inOff;
}

- (void)setData:(NSString*)inData
{
	[data setString:inData];
}

- (void)setType:(NSString*)inData
{
	[type setString:inData];
}

- (NSString*)type
{
	return type;
}

- (NSString*)data
{
	return data;
}

- (BOOL)doComp
{
	NSRange found = [data rangeOfString:@"\t"];
	if (found.location == NSNotFound)
		return NO;
	NSString* tempOp = [data substringToIndex:found.location];
	if ([tempOp hasSuffix:@"."])
		return YES;
	return NO;
}

- (NSString*)op
{
	if (opCache)
		return opCache;

	NSRange found = [data rangeOfString:@"\t"];
	if (found.location == NSNotFound)
		return data;
	NSString* tempOp = [data substringToIndex:found.location];
	if ([tempOp hasSuffix:@"+"])
		return [data substringToIndex:found.location-1];
	if ([tempOp hasSuffix:@"-"])
		return [data substringToIndex:found.location-1];		
	if ([tempOp hasSuffix:@"."])
		return [data substringToIndex:found.location-1];
		
	opCache = tempOp;
	return tempOp;
}

- (void)setShow:(BOOL)newval
{
	showMe = newval;
}

- (void)setBranch:(BOOL)newval
{
	isBranch = newval;
}

- (void)setCondBranch:(BOOL)newval
{
	isCondBranch = newval;
}

- (void)setAsm:(BOOL)newval
{
	isAsm = newval;
}

- (NSString*)globalSymbol
{
	NSRange found = [data rangeOfString:@"\t"];		
	NSString *comps = [data substringFromIndex:found.location+1];
	NSMutableArray* compArray = [[NSMutableArray alloc] initWithArray:[comps componentsSeparatedByString:@","]];
	
	NSRange offRange = [[compArray objectAtIndex:([compArray count]-1)] rangeOfString:@"("];
	if (offRange.location!=NSNotFound)
	{
		NSString* offReg = [[compArray objectAtIndex:([compArray count]-1)] substringFromIndex:(offRange.location+1)];
		[compArray replaceObjectAtIndex:([compArray count]-1) withObject:[[compArray objectAtIndex:([compArray count]-1)] substringToIndex:offRange.location]];
		[compArray addObject:offReg];
	}

	int i;
	for(i=0;i<[compArray count];i++)
	{
		NSString* compString = [compArray objectAtIndex:i];
		// this is a global symbol
		if ([compString hasPrefix:@"_"])
			return [compString substringFromIndex:1];
	}
	return nil;
}

- (NSUInteger)ncomp
{
	NSRange found = [data rangeOfString:@"\t"];		
	NSString *comps = [data substringFromIndex:found.location+1];
	NSMutableArray* compArray = [[NSMutableArray alloc] initWithArray:[comps componentsSeparatedByString:@","]];
	NSRange offRange = [[compArray objectAtIndex:([compArray count]-1)] rangeOfString:@"("];
	if (offRange.location!=NSNotFound)
	{
		NSString* offReg = [[compArray objectAtIndex:([compArray count]-1)] substringFromIndex:(offRange.location+1)];
		[compArray addObject:offReg];
	}
	NSUInteger cnt = [compArray count];
	return cnt;
}

- (int)instrComp:(int)num
{
	// this is because the arrays created here use a lot of memmory
	//NSAutoreleasePool* compPool = [[NSAutoreleasePool alloc] init];

	NSRange found = [data rangeOfString:@"\t"];		
	NSString *comps = [data substringFromIndex:found.location+1];
	NSMutableArray* compArray = [[NSMutableArray alloc] initWithArray:[comps componentsSeparatedByString:@","]];
	
	NSRange offRange = [[compArray objectAtIndex:([compArray count]-1)] rangeOfString:@"("];
	if (offRange.location!=NSNotFound)
	{
		NSString* offReg = [[compArray objectAtIndex:([compArray count]-1)] substringFromIndex:(offRange.location+1)];
		[compArray addObject:offReg];
	}
	if ((num<0)||(num>=[compArray count]))
		return 0;
	
	int compData=0;
	NSString* compString = [compArray objectAtIndex:num];
	
	// this is a symbol
	if ([compString hasPrefix:@"_"])
	{
		CDSymbol* symbol = [sym findByName:compString];
		if (symbol)
			return [symbol value];
		else 
			return 0;
	}

	if ([compString hasPrefix:@"cr"])
		sscanf([compString cStringUsingEncoding:NSASCIIStringEncoding],"cr%d", &compData);
	else if ([compString hasPrefix:@"r"])
		sscanf([compString cStringUsingEncoding:NSASCIIStringEncoding],"r%d", &compData);
	else if ([compString hasPrefix:@"0x"])
		sscanf([compString cStringUsingEncoding:NSASCIIStringEncoding],"0x%x", &compData);		

	return compData;
}

- (CDRegVal*)regData:(int)regNum cond:(BOOL)isCond
{
	if (isCond)
	{
		if ((regNum<8)&&(regNum>=0))
			return [creg objectAtIndex:regNum];
	}
	else
	{
		if ((regNum<32)&&(regNum>=0))
			return [reg objectAtIndex:regNum];
	}
	return nil;
}

- (BOOL)showMe
{
	return showMe;
}

- (BOOL)isAsm
{
	return isAsm;
}

- (long)offset
{
	return offset;
}

- (BOOL)isBranch
{
	return isBranch;
}

- (BOOL)isCondBranch
{
	return isCondBranch;
}

- (BOOL)returnStruct
{
	if ([self isSelector])
	{
		long immed = [self instrComp:0];
		CDSymbol* found = [sym findByOffset:immed];
		if (found&&[[found name] hasPrefix:@"_objc_msgSend_stret"])
			return YES;
	}
	return NO;
}

- (BOOL)isSuperObj;
{
	if ([self isSelector])
	{
		long immed = [self instrComp:0];
		CDSymbol* found = [sym findByOffset:immed];
		if (found&&[[found name] hasPrefix:@"_objc_msgSendSuper"])
			return YES;
	}
	return NO;
}

// this applies to disassembly
- (BOOL)isSelector
{
	if ([[self op] isEqualToString:@"bl"]||[[self op] isEqualToString:@"b"])
	{
		long immed = [self instrComp:0];
		CDSymbol* found = [sym findByOffset:immed];
		if (found&&[[found name] hasPrefix:@"_objc_msgSend"])
			return YES;
	}
	// used for objective-C runtime pages
	if ([data isEqualToString:@"bla\t0xfffeff00"]||[data isEqualToString:@"ba\t0xfffeff00"])
		return YES;	
	return NO;
}
- (BOOL)isNSLog
{
	if ([[self op] isEqualToString:@"bl"]||[[self op] isEqualToString:@"b"])
	{
		long immed = [self instrComp:0];
		CDSymbol* found = [sym findByOffset:immed];
		if (found&&[[found name] hasPrefix:@"_NSLog"])
			return YES;
	}
	return NO;
}

- (BOOL)isNSBeep
{
	if ([[self op] isEqualToString:@"bl"]||[[self op] isEqualToString:@"b"])
	{
		long immed = [self instrComp:0];
		CDSymbol* found = [sym findByOffset:immed];
		if (found&&[[found name] hasPrefix:@"_NSBeep"])
			return YES;
	}
	return NO;}

- (BOOL)isVoid
{
	return ([type isEqualToString:@"void"]||[type isEqualToString:@"oneway void"]);
}

// this applies to post-disassembly decompiled code
- (BOOL)isSelectorLine
{
	NSRange selRange = [data rangeOfString:@"["];
	return ((selRange.location != NSNotFound)&&(isBranch));
}

- (BOOL)isReturnObject
{
	if ([self isVoid])
		return NO;
	if (!type)
		return NO;
	if (![type length])
		return NO;
	return ([type hasPrefix:@"NS"])||
				([type isEqualToString:@"id"])||
				([type isEqualToString:@"SEL"])||
				([type isEqualToString:@"Class"])||
				([type isEqualToString:@"void *"]);		
}

- (NSString*)formatConditionWithString:(NSString*)condition
{
	// this function is necessary due to a bugfix on 4/20/06
	// when conditions contain formatstrings themselves, it will cause a bus error
	//		when trying to format the wrong specifier
	// so the solution here is to split the condition by quote marks and ignore those
	// parts of the array that represent program strings
	// known bug/issue:
	//		this will actually format ALL format specifiers in the condition, instead of just the first,
	//		however, there should only be one per condition

	NSArray* quoteArray = [data componentsSeparatedByString:@"\""];
	if ([quoteArray count]%2!=1)
	{
		NSLog(@"condition formatting error\n");
		exit(0);
	}

	if ([quoteArray count]>1)
	{
		NSMutableString *outString = [[NSMutableString alloc] init];
		int i;
		for (i=0;i<[quoteArray count];i++)
		{
//			if (i%2==0)
//				[outString appendString:[NSString stringWithFormat:[quoteArray objectAtIndex:i],[condition cString],nil]];
//			else
				[outString appendString:[quoteArray objectAtIndex:i]];

			// add quotes back in
			if (i<[quoteArray count]-1)
				[outString appendString:@"\""];
		}
		return outString;
	}
	
	return [NSString stringWithFormat:data,[condition cStringUsingEncoding:NSASCIIStringEncoding],nil];
}

- (CDRegVal*)ctrData
{
	return ctrReg;
}

- (void)setCtrData:(CDRegVal*)regData
{
	ctrReg = regData;
}

@end
