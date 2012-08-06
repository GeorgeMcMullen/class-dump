//
//  CDARMV6Simulator.m
//  code-dump
//
//  Created by George McMullen on 4/7/12.
//  Copyright (c) 2012 Quixonic / mobiTeris. All rights reserved.
//

#import "CDARMV6Simulator.h"
#import "CDLine.h"
#import "CDRegVal.h"
#import "CDOCMethod.h"
#import "CDClassDump.h"
#import "CDOCClass.h"
#import "CDOCIvar.h"
#import "CDMachOFile.h"
#import "CDLCSymbolTable.h"

@implementation CDARMV6Simulator

- (NSMutableDictionary*)initializeProcessorState
{
	NSMutableDictionary* returnState=[super initializeProcessorState];
    //	[returnState setObject:<#(id)anObject#> forKey:<#(id)aKey#>
    //	put above into here
	return returnState;
}

- (id)initWithLines:(NSMutableArray*)inLines file:(CDMachOFile*)file meth:(CDOCMethod*)meth cd:(CDClassDump*)cd retValue:(BOOL)ret
{
	if ([super init]==nil)
		return nil;
    
	lineArray = inLines;
	retValue = ret;
	mach = file;
	method = meth;
	aClassDump = cd;
	return self;
}

- (void)cleanupInstructions
{
	// cosmetic removals
	// the instructions below don't really do much in terms of code-dump, and therefore
	//		are removed from view
	// instructions that are still shown are generally instructions that code-dump doesn't 
	//		know how to process, so we should remove these to avoid confusion
	
	// move from special purpose register
	if ([[curLine op] isEqualToString:@"mfspr"]||
        // store multiple word (this is here because it's generally part of the prolog,
        //		however it may be used in other places... should investigate)
		[[curLine op] isEqualToString:@"stmw"]||
        // similar to above
		[[curLine op] isEqualToString:@"lmw"]||
        // sign extend byte (doesn't really have much of an effect in code-dump currently)
		[[curLine op] isEqualToString:@"extsb"]||
        // no operation
		[[curLine op] isEqualToString:@"nop"]||
		[[curLine op] isEqualToString:@"stfd"]||
		[[curLine op] isEqualToString:@"lfd"])
		[curLine setShow:NO];
}

- (void)handleFinalInstructions
{
	// these two instructions generally come when the function is soon to end
	// the second one (mtspr) might be able to be removed now that unconditional selector branches
	//	are handled directly in selector code
	if ([[curLine op] isEqualToString:@"blr"]||[[curLine data] hasPrefix:@"mtspr\tlr"])
	{
		[curLine setShow:NO];
		if (retValue)
		{
			CDLine* addLine = [[CDLine alloc] initWithData:@"return" offset:curOff old:curLine];
			[addLine setAsm:NO];
			[lineArray addObject:addLine];
		}
	}
}

- (void)handleCompare
{
	if ([[curLine op] isEqualToString:@"cmpwi"]||[[curLine op] isEqualToString:@"cmpw"]||[[curLine op] isEqualToString:@"cmplw"])
	{
		NSString* statement;
		
		[curLine setShow:NO];
		NSString* outType;
		NSString* objectA = [method lookupObject:[curLine instrComp:1] line:curLine lineArray:lineArray file:mach outType:&outType];		
        
		// lookup second object if a register compare (don't if immediate)
		if (![[curLine op] isEqualToString:@"cmpwi"])
		{
			NSString* objectB = [method lookupObject:[curLine instrComp:2] line:curLine lineArray:lineArray file:mach outType:&outType];
			statement = [[NSString alloc] initWithFormat:@"(%@ %%s %@)",objectA,objectB,nil];
		}
		else
		{
			short immed = [curLine instrComp:2];
			statement = [[NSString alloc] initWithFormat:@"(%@ %%s %d)",objectA,immed,nil];
		}
		
		CDLine* addLine = [[CDLine alloc] initWithData:statement offset:curOff old:curLine];
		[addLine setAsm:NO];
		[addLine setShow:NO];
		[lineArray addObject:addLine];
		
		[addLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initWithLine:([lineArray count]-1)] cond:YES];
	}
}

- (void)handleForLoop
{
	/* For for loops that use the bdnz instruction 
	 *	this algorithm creates a for loop
	 *
	 * Todo: for loops generated starting with a conditional branch
	 *  have a brief section at the beginning that is executed
	 *	if the condition is false, ending with an unconditional branch.  This should be removed
	 *	or not shown.  Possibly code in that section should be moved after the loop, but I haven't
	 *	seen useful code in that section (usually just moving 1 to ctr to end loop and branching
	 *	to bdnz)
	 *
	 */
	if ([[curLine op] isEqualToString:@"bdnz"])
	{
		NSNumber *immediate;
		immediate = [[NSNumber alloc] initWithLong:[curLine instrComp:0]];
#ifdef DEBUG				
		NSLog(@"found for loop\n");
#endif
		NSInteger i;
		// find first instruction before branch, then increment
		for (i=[lineArray count]-2;i>=0;i--)
			if ([(CDLine *)[lineArray objectAtIndex:i ] offset]<[immediate longValue])
				break;
		i++;
		CDLine* startLine = [lineArray objectAtIndex:i];
        
		// this handles loops that start with conditions
		if ([[startLine ctrData] data]&&[[startLine ctrData] value]==1)
		{
#ifdef DEBUG			
			NSLog(@"condition-prefaced condition found\n");
#endif
			if ([[[lineArray objectAtIndex:i-1] op] isEqualToString:@"b"])
			{
				long brTarg = [[lineArray objectAtIndex:i-1] instrComp:0];
#ifdef DEBUG
				NSLog(@"unconditional branch to %08lx\n",brTarg);
#endif				
				if (brTarg==[curLine offset])
				{
#ifdef DEBUG
					NSLog(@"branch target equals bdnz offset\n");
#endif					
					[[lineArray objectAtIndex:i-1] setShow:NO];
                    
					for (i=[lineArray count]-2;i>=0;i--)
						if ([[[lineArray objectAtIndex:i ] bTarget] count]==[[curLine bTarget] count])
							break;
					i++;
					startLine = [lineArray objectAtIndex:i];
				}
			}
		}
        
		int startVal = 0;
		if ([startLine isCondBranch])
		{
			[startLine setShow:NO];
			startVal = 1;
		}
        
		if ([[startLine ctrData] isLineRef]||[[startLine ctrData] data])
		{
			[curLine setShow:NO];
			
			NSString* newStr;
			if ([[startLine ctrData] isLineRef])
			{
				NSUInteger lineNum = [[curLine ctrData] lineRef];
				newStr = [[NSString alloc] initWithFormat:@"for (i=%d; i<%@; i++) {",startVal,[(CDLine*)[lineArray objectAtIndex:lineNum] data],nil];
			}
			else if ([[startLine ctrData] data])
				newStr = [[NSString alloc] initWithFormat:@"for (i=%d; i<%ld; i++) {",startVal,[[startLine ctrData] value],nil];
            
#ifdef DEBUG				
			NSLog(@"adding %@\n",newStr);
#endif
			
			CDLine* addLine = [[CDLine alloc] initWithData:newStr offset:[startLine offset] old:startLine];
			[addLine setAsm:NO];
			
			// replace old if statement with new for statement
			if ([startLine isCondBranch])
				[lineArray replaceObjectAtIndex:i+1 withObject:addLine];
			else
			{
				[lineArray insertObject:addLine atIndex:i];
				
				NSNumber* curImm = [NSNumber numberWithLong:[curLine offset]];
#ifdef DEBUG				
				NSLog(@"adding btargets for for loop\n");
#endif
				// need to add bTarget for all lines in for loop
				NSUInteger j;
				for (j=i;j<[lineArray count];j++)
					[[[lineArray objectAtIndex:j] bTarget] addObject:curImm];
			}
		}
	}
}

- (void)handleConditionalBranch
{
	// conditional branches are a bit tricky
	// essentially, we get the condition, "printf" in the conditional op, then add the target to a bTarget stack
	// the stack helps to determine the number of parens and such to print
	if ([[curLine op] isEqualToString:@"beq"]||[[curLine op] isEqualToString:@"bne"]||[[curLine op] isEqualToString:@"bge"]||[[curLine op] isEqualToString:@"blt"]||[[curLine op] isEqualToString:@"bgt"]||[[curLine op] isEqualToString:@"ble"])
	{
		NSMutableString* statement = [[NSMutableString alloc] initWithString:@"if "];	
		int condReg;
		NSNumber *immediate;
		// sometimes the condition register isn't shown, and default c-register cr0 is used
		if ([curLine ncomp]==1)
		{
			condReg = 0;
			immediate = [[NSNumber alloc] initWithLong:[curLine instrComp:0]];
		}
		else
		{
			condReg = [curLine instrComp:0];
			immediate = [[NSNumber alloc] initWithLong:[curLine instrComp:1]];
		}
		
		if ([[curLine regData:condReg cond:YES] isLineRef]) 
		{
			// get the line num
			NSUInteger lineNum = [[curLine regData:condReg cond:YES] lineRef];
            
			//NSLog(@"linenum %d data '%@'\n",lineNum,[(CDLine*)[lineArray objectAtIndex:lineNum] data]);
            
			if ([[curLine op] isEqualToString:@"beq"])
				[statement appendString:[(CDLine*)[lineArray objectAtIndex:lineNum] formatConditionWithString:@"!="]];
			else if ([[curLine op] isEqualToString:@"bne"])
				[statement appendString:[(CDLine*)[lineArray objectAtIndex:lineNum] formatConditionWithString:@"=="]];
			else if ([[curLine op] isEqualToString:@"bge"])
				[statement appendString:[(CDLine*)[lineArray objectAtIndex:lineNum] formatConditionWithString:@"<"]];
			else if ([[curLine op] isEqualToString:@"ble"])
				[statement appendString:[(CDLine*)[lineArray objectAtIndex:lineNum] formatConditionWithString:@">"]];
			else if ([[curLine op] isEqualToString:@"blt"])
				[statement appendString:[(CDLine*)[lineArray objectAtIndex:lineNum] formatConditionWithString:@">="]];
			else if ([[curLine op] isEqualToString:@"bgt"])
				[statement appendString:[(CDLine*)[lineArray objectAtIndex:lineNum] formatConditionWithString:@"<="]];
            
		}
		else
			[statement appendString:@"(UNKNOWN_CONDITION)"];
		
		[statement appendString:@" {"];
		[curLine setShow:NO];
		CDLine* addLine = [[CDLine alloc] initWithData:statement offset:curOff old:curLine];
		[addLine setAsm:NO];
        
		[curLine setCondBranch:YES];
		[addLine setCondBranch:YES];
        
		[[addLine bTarget] addObject:immediate];
		
		//NSLog(@"add bTarget %x (cur %x) and cond %@\n",[immediate longValue],offset,statement);		
		//CFShow([addLine bTarget]);
		
		[lineArray addObject:addLine];
		
	}
}

- (void)handleRtype
{
	// 
	// This is a special purpose instruction that directly moves a register
	//
	if ([[curLine op] isEqualToString:@"mtspr"])
	{
		[curLine setShow:NO];
		[curLine setCtrData:[curLine regData:[curLine instrComp:1] cond:NO]];
	}
    
	//
	// the following instructions have only TWO components (one dst, one src), where src is immediate or register
	//
	if ([[curLine op] isEqualToString:@"li"]||
		[[curLine op] isEqualToString:@"lis"]||
		[[curLine op] isEqualToString:@"neg"])
	{
		// one-src (src=register) instructions where src is a reference
		if ([[curLine op] isEqualToString:@"neg"]&&
			![[curLine regData:[curLine instrComp:1] cond:NO] data])
		{
			NSUInteger lineNum = [[curLine regData:[curLine instrComp:1] cond:NO] lineRef];
			NSString* refLineStr = [(CDLine*)[lineArray objectAtIndex:lineNum] data];
			NSString* newStr;
			
			// generate the new strings based on the assembly
			if ([[curLine op] isEqualToString:@"neg"])
				newStr = [[NSString alloc] initWithFormat:@"(-%@)",refLineStr,nil];
			
			CDLine* addLine = [[CDLine alloc] initWithData:newStr offset:curOff old:curLine];
			[addLine setAsm:NO];
			[addLine setShow:NO];
            
			NSUInteger refLine = [lineArray count];
			[addLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initWithLine:refLine] cond:NO];
			[lineArray addObject:addLine];						
		}
		// src is either data or immediate (in which case is also data)
		else
		{
			long immed = 0;
			// requires shifting
			if ([[curLine op] isEqualToString:@"lis"])
				immed = [curLine instrComp:1]<<16;
			// neg's source IS a register
			else if ([[curLine op] isEqualToString:@"neg"])
				immed = -1*[[curLine regData:[curLine instrComp:1] cond:NO] value];
			// just sign-extending
			else if ([[curLine op] isEqualToString:@"li"])
			{
				short tmpimmed = [curLine instrComp:1];
				immed = tmpimmed;
			}
			[curLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initWithValue:immed] cond:NO];
			[curLine setShow:NO];
		}
	}
    
	//
	// the following instructions make use of the register component 1 and an immediate value in component 2
	//	
	else if ([[curLine op] isEqualToString:@"subfic"]||
             [[curLine op] isEqualToString:@"xori"]||
             [[curLine op] isEqualToString:@"addi"]||
             [[curLine op] isEqualToString:@"addis"]||
             [[curLine op] isEqualToString:@"addic"]||
             [[curLine op] isEqualToString:@"ori"])
	{	
		long immed;
		// requires shifting
		if ([[curLine op] isEqualToString:@"addis"])
			immed = [curLine instrComp:2]<<16;
		// just sign-extending
		else
		{
			short tmpimmed = [curLine instrComp:2];
			immed = tmpimmed;
			if (immed != tmpimmed)
			{
				NSLog(@"sign ext error\n");
				exit(0);
			}
		}
        
        NSLog(@"add to %@\n",[curLine regData:[curLine instrComp:1] cond:NO]);
        
		//	check if they're actually referencing a line reference
		if ([[curLine regData:[curLine instrComp:1] cond:NO] isLineRef])
		{
			[curLine setShow:NO];
			
			NSUInteger lineNum = [[curLine regData:[curLine instrComp:1] cond:NO] lineRef];
			NSString* refLineStr = [(CDLine*)[lineArray objectAtIndex:lineNum] data];
			NSString* newStr;
			
			// generate the new strings based on the assembly (many of these are improbable)
			if ([[curLine op] isEqualToString:@"subfic"])
			{
				if (immed==0)
					newStr = [[NSString alloc] initWithFormat:@"(-%@)",refLineStr,nil];
				else
					newStr = [[NSString alloc] initWithFormat:@"(%ld-%@)",immed,refLineStr,nil];
			}
			else if ([[curLine op] isEqualToString:@"xori"])
				newStr = [[NSString alloc] initWithFormat:@"(%@^%ld)",refLineStr,immed,nil];
			else if ([[curLine op] isEqualToString:@"addi"]||[[curLine op] isEqualToString:@"addic"]||[[curLine op] isEqualToString:@"addis"])
			{
				if (immed>0)
					newStr = [[NSString alloc] initWithFormat:@"(%@+%ld)",refLineStr,immed,nil];
				else
					newStr = [[NSString alloc] initWithFormat:@"(%@-%ld)",refLineStr,-immed,nil];
			}
			else if ([[curLine op] isEqualToString:@"ori"])
				newStr = [[NSString alloc] initWithFormat:@"(%@|%ld)",refLineStr,immed,nil];
			
			CDLine* addLine = [[CDLine alloc] initWithData:newStr offset:curOff old:curLine];
			[addLine setAsm:NO];
			[addLine setShow:NO];
            
			NSUInteger refLine = [lineArray count];
			[addLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initWithLine:refLine] cond:NO];
			[lineArray addObject:addLine];			
		}
		// check if this is data
		else if ([[curLine regData:[curLine instrComp:1] cond:NO] data])
		{
			long newData;
            
			if ([[curLine op] isEqualToString:@"subfic"])
				newData = immed-[[curLine regData:[curLine instrComp:1] cond:NO] value];
			else if ([[curLine op] isEqualToString:@"xori"])
				newData = [[curLine regData:[curLine instrComp:1] cond:NO] value]^immed;
			else if ([[curLine op] isEqualToString:@"ori"])
				newData = [[curLine regData:[curLine instrComp:1] cond:NO] value]|immed;
			else // add instructions
				newData = [[curLine regData:[curLine instrComp:1] cond:NO] value]+immed;
			
			//NSLog(@"%@: 0x%08x = 0x%08x _%@_ 0x%08x\n",[curLine op],newData,[[curLine regData:[curLine instrComp:1] cond:NO] value],[curLine op],immed);
			
			[curLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initWithValue:newData] cond:NO];	
			[curLine setShow:NO];
			
			// register added was zero, then this may be just loading a global symbol
			// or if just doing a one-component operation
			if (newData==[curLine instrComp:2])
			{
				NSString* globSym = [curLine globalSymbol];
				if (globSym!=nil)
				{
					CDLine* addLine = [[CDLine alloc] initWithData:globSym offset:curOff old:curLine];
					[addLine setAsm:NO];
					[addLine setShow:NO];
                    
					NSUInteger refLine = [lineArray count];
					[addLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initWithLine:refLine] cond:NO];
					[lineArray addObject:addLine];
					
					//NSLog(@"reg %d set to global sym %@\n",[curLine instrComp:0],globSym);
				}
			}
			
		}		
        
	}
    
	// special case, this is equivalent to an "mr" pseudoinstruction
	else if ([[curLine op] isEqualToString:@"or"]&&([curLine instrComp:1]==[curLine instrComp:2]))
	{
		// just copy register
		[curLine setReg:[curLine instrComp:0] data:[curLine regData:[curLine instrComp:1] cond:NO] cond:NO];
		[curLine setShow:NO];
	}
	
	//
	// the following instructions make use of two register components 1 and 2
	//	
	else if ([[curLine op] isEqualToString:@"or"]||
             [[curLine op] isEqualToString:@"adde"]||
             [[curLine op] isEqualToString:@"subfe"]||
             [[curLine op] isEqualToString:@"subfc"])
	{
		if ([[curLine regData:[curLine instrComp:1] cond:NO] data]&&[[curLine regData:[curLine instrComp:1] cond:NO] data])
		{
			long newData = 0;
			if ([[curLine op] isEqualToString:@"or"])
				newData = [[curLine regData:[curLine instrComp:1] cond:NO] value]|[[curLine regData:[curLine instrComp:2] cond:NO] value];
			else if ([[curLine op] isEqualToString:@"adde"])
				newData = [[curLine regData:[curLine instrComp:1] cond:NO] value]+[[curLine regData:[curLine instrComp:2] cond:NO] value];
			else if ([[curLine op] isEqualToString:@"subfe"]||[[curLine op] isEqualToString:@"subfc"])
				newData = [[curLine regData:[curLine instrComp:2] cond:NO] value]-[[curLine regData:[curLine instrComp:1] cond:NO] value];
            
            
			[curLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initWithValue:newData] cond:NO];
			[curLine setShow:NO];
			
			// if a certain bit is set in some instructions, the default register will be updated
			if ([curLine doComp])
			{
				NSString* outType;
				NSString* object = [method lookupObject:[curLine instrComp:1] line:curLine lineArray:lineArray file:mach outType:&outType];
				NSString* statement = [[NSString alloc] initWithFormat:@"(%@ %%s %d)",object,0];
				CDLine* addLine = [[CDLine alloc] initWithData:statement offset:curOff old:curLine];
				[addLine setAsm:NO];
				[addLine setShow:NO];
				[lineArray addObject:addLine];				
				[addLine setReg:0 data:[[CDRegVal alloc] initWithLine:([lineArray count]-1)] cond:YES];
			}
		}
		else if ([[curLine regData:[curLine instrComp:1] cond:NO] isLineRef]||[[curLine regData:[curLine instrComp:2] cond:NO] isLineRef])
		{
			[curLine setShow:NO];
			
			NSString* refLineStrA,*refLineStrB;
			NSMutableString* newStr = [[NSMutableString alloc] init];
			if ([[curLine regData:[curLine instrComp:1] cond:NO] isLineRef])
			{
				NSUInteger lineNum = [[curLine regData:[curLine instrComp:1] cond:NO] lineRef];
				refLineStrA = [(CDLine*)[lineArray objectAtIndex:lineNum] data];
			}
			if ([[curLine regData:[curLine instrComp:2] cond:NO] isLineRef])
			{
				NSUInteger lineNum = [[curLine regData:[curLine instrComp:2] cond:NO] lineRef];
				refLineStrB = [(CDLine*)[lineArray objectAtIndex:lineNum] data];
			}			
			
			// compiler will sometimes add/subtract two identical operands to get 0
			// it typically does this in strange and unpredictable ways that totally fuck up code-dump
			// it's really annoying
			// the following makes some attempt to detect this
			BOOL specialCase = NO;
			if ([[curLine regData:[curLine instrComp:2] cond:NO] isLineRef]&&[[curLine regData:[curLine instrComp:1] cond:NO] isLineRef])
			{
				NSRange inA = [refLineStrA rangeOfString:refLineStrB];
				NSRange inB = [refLineStrB rangeOfString:refLineStrA];
				if (inA.location!=NSNotFound||inB.location!=NSNotFound)
				{
					if ([[curLine op] hasPrefix:@"sub"])
					{
						// n - n = 0
						if ([refLineStrA isEqualToString:refLineStrB])
						{
							// set register to 0
							[curLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initWithValue:0] cond:NO];
							specialCase = YES;
						}
						// b - (b +/- x) = -1* (+/- x)
						else if (inA.location!=NSNotFound)
						{
							// this code will probably fail if refLines are very complicated combinations of selectors
							if ([refLineStrA length]>(inA.location+[refLineStrB length]))
							{
								NSString* xStr = [refLineStrA substringFromIndex:(inA.location+[refLineStrB length])];
								NSRange parenRange = [xStr rangeOfString:@")"];
								if (parenRange.location!=NSNotFound)
									xStr = [xStr substringToIndex:parenRange.location];
								
								NSNumber* xNum = [[[NSNumberFormatter alloc] init] numberFromString:xStr];
								if (xNum)
								{
									// set register to -x
									[curLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initWithValue:-1*[xNum longValue]] cond:NO];
									specialCase = YES;	
								}
							}
						}
					}
					else if ([[curLine op] hasPrefix:@"add"])
					{
						// (-b) + b = 0
						if ([[NSString stringWithFormat:@"(-%@)",refLineStrB,nil] isEqualToString:refLineStrA])
						{
							// set register to 0
							[curLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initWithValue:0] cond:NO];
							specialCase = YES;							
						}
					}
					//NSLog(@"operands may be negative copies of each other:\n%@\n%@\n",refLineStrA,refLineStrB);
					if (!specialCase)
						NSLog(@"Error: special case not handled!\n");
				}
			}
			
			[newStr appendString:@"("];
            
			// generate left side of expression
			// note that the SECOND instruction component comes FIRST
			// I did this because subfe requires it (because subfe/subfc is second component - first component)
			// should make sure that no other instruction requires it the other way around
			if ([[curLine regData:[curLine instrComp:2] cond:NO] isLineRef])
				[newStr appendString:refLineStrB];
			else if ([[curLine regData:[curLine instrComp:2] cond:NO] data])
				[newStr appendFormat:@"%ld",[[curLine regData:[curLine instrComp:2] cond:NO] value],nil];
            
			// generate expression operation
			if ([[curLine op] isEqualToString:@"or"])
				[newStr appendString:@"|"];
			else if ([[curLine op] isEqualToString:@"adde"])
				[newStr appendString:@"+"];
			else if ([[curLine op] isEqualToString:@"subfe"]||[[curLine op] isEqualToString:@"subfc"])
				[newStr appendString:@"-"];
            
			// generate right side of expression
			if ([[curLine regData:[curLine instrComp:1] cond:NO] isLineRef])
				[newStr appendString:refLineStrA];
			else if ([[curLine regData:[curLine instrComp:1] cond:NO] data])
				[newStr appendFormat:@"%ld",[[curLine regData:[curLine instrComp:1] cond:NO] value],nil];
            
            
			[newStr appendString:@")"];
            
			if (!specialCase)
			{
				CDLine* addLine = [[CDLine alloc] initWithData:newStr offset:curOff old:curLine];
				[addLine setAsm:NO];
				[addLine setShow:NO];
                
				NSUInteger refLine = [lineArray count];
				[addLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initWithLine:refLine] cond:NO];
				[lineArray addObject:addLine];
			}
		}
	}		
    
    
	// special stack case (r1)
	if ([[curLine op] hasPrefix:@"add"]&&[curLine ncomp]>1&&[curLine instrComp:1]==1)
	{
		//popping stack
		[curLine setShow:NO];
		CDLine* addLine = [[CDLine alloc] initWithData:[[NSString alloc] initWithFormat:@"popping stack %d",[curLine instrComp:0],nil] offset:curOff old:curLine];
		[lineArray addObject:addLine];		
		[addLine setShow:NO]; // don't show stack stuff
		
		[[method stack] removeAllObjects];
	}
}

- (void)handleStore
{
	if ([[curLine op] isEqualToString:@"stw"]||[[curLine op] isEqualToString:@"stwu"]||[[curLine op] isEqualToString:@"stb"])
	{
		// special stack case (r1)
		if ([curLine instrComp:2]==1)
		{
			[curLine setShow:NO];
			CDLine* addLine = [[CDLine alloc] initWithData:[[NSString alloc] initWithFormat:@"save r%d on stack",[curLine instrComp:0],nil] offset:curOff old:curLine];
			[lineArray addObject:addLine];
			
			[addLine setShow:NO]; // don't show stack stuff
			
			NSNumber* offset = [NSNumber numberWithLong:[curLine instrComp:1]];
			[[method stack] setObject:[curLine regData:[curLine instrComp:0] cond:NO] forKey:offset];
		}
		else
		{
			//first handle stored reg
			NSString* outType;
			NSString* stored = [method lookupObject:[curLine instrComp:0] line:curLine lineArray:lineArray file:mach outType:&outType];
			
			//now handle storage location
			if ([[curLine regData:[curLine instrComp:2] cond:NO] isSelf])
			{
				BOOL found=NO;
				int i;
				for (i=0;i<[[[aClassDump curClass] ivars] count];i++)
					if ([(CDOCIvar *)[[[aClassDump curClass] ivars] objectAtIndex:i] offset]==[curLine instrComp:1])
					{
						found=YES;
						break;
					}
				// load ivar
				if (found)
				{
					[curLine setShow:NO];
					NSString* statement = [[NSString alloc] initWithFormat:@"%@ = %@;",[[[[aClassDump curClass] ivars] objectAtIndex:i] name],stored,nil];
					CDLine* addLine = [[CDLine alloc] initWithData:statement offset:curOff old:curLine];
					[addLine setAsm:NO];
					[lineArray addObject:addLine];
				}
			}
			else if ([[curLine regData:[curLine instrComp:2] cond:NO] isLineRef])
			{
				if ([curLine instrComp:1]==0)
				{
					//NSLog(@"deref lineref for storage\n");
					[curLine setShow:NO];						
					NSUInteger lineNum = [[curLine regData:[curLine instrComp:2] cond:NO] lineRef];
					NSString* refLineStr = [(CDLine*)[lineArray objectAtIndex:lineNum] data];
					NSString* newStr = [[NSString alloc] initWithFormat:@"*%@ = %@;",refLineStr,stored,nil];						
					CDLine* addLine = [[CDLine alloc] initWithData:newStr offset:curOff old:curLine];
					[addLine setAsm:NO];
					[lineArray addObject:addLine];
					
				}
			}
		}
	}	
}

- (void)handleLoad
{
	if ([[curLine op] isEqualToString:@"lbzx"])
	{
		// todo: this requires locals
		//NSLog(@"lbz r%d:%@\n",[curLine instrComp:2],[curLine regData:[curLine instrComp:2] cond:NO]);
	}
    
	if (([[curLine op] isEqualToString:@"lwz"])||([[curLine op] isEqualToString:@"lbz"]))
	{
		if ([[curLine regData:[curLine instrComp:2] cond:NO] data])
		{
			short offset = [curLine instrComp:1];
			unsigned long total = [[curLine regData:[curLine instrComp:2] cond:NO] value]+offset;
            
			//NSLog(@"lwz total: %08x + off = %08x\n",[[curLine regData:[curLine instrComp:2] cond:NO] value],total);
            
			if (total>0)
			{
				long data;
				
				//lookup in symbol table					
				CDSymbol* symbol = [[mach sym] findByOffset:total];
				if (symbol!=nil)
				{
					// found symbol in global table
					// this is not actually data, but a reference to an indirectly linked symbol
					//NSLog(@"found symbol %@\n",symbol);
                    
					NSString* lineName = [symbol name];
					if ([lineName length]>2&&[lineName hasPrefix:@"_"])
						lineName = [lineName substringFromIndex:1];
                    
					CDLine* addLine = [[CDLine alloc] initWithData:[[NSString alloc] initWithFormat:@"&%@",lineName,nil] offset:curOff old:curLine];
					[addLine setAsm:NO];
					[addLine setShow:NO];
					[curLine setShow:NO];
					
					NSUInteger refLine = [lineArray count];
					[addLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initWithLine:refLine] cond:NO];
					[lineArray addObject:addLine];
				}
				else
				{
					// data is not in symbol table so it's actual data (probably)
					char * dataPtr = (char*)[mach pointerFromVMAddr:total];
					if (dataPtr!=NULL)
					{
						memcpy(&data,dataPtr,4);					
						//NSLog(@"data out is %x\n",data);
						[curLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initWithValue:data] cond:NO];
						// don't need to show this line anymore
						[curLine setShow:NO];
						
						// added this so nil loaded values also show their addresses (which would otherwise be lost)
						// this is useful when global variables are loaded that are initialized to zero but modified at runtime
						if (data==0)
						{
#ifdef DEBUG
							NSLog(@"lwz loading nil value\n");
#endif
							CDLine* addLine = [[CDLine alloc] initWithData:[[NSString alloc] initWithFormat:@"global_%x",dataPtr,nil] offset:curOff old:curLine];
							[addLine setAsm:NO];
							[addLine setShow:NO];
							
							NSUInteger refLine = [lineArray count];
							[addLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initWithLine:refLine] cond:NO];
							[lineArray addObject:addLine];
						}
					}
					else
						[curLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initInvalid] cond:NO];
				}
			}
			else
				[curLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initInvalid] cond:NO];
		}
		// instance variable
		else if ([[curLine regData:[curLine instrComp:2] cond:NO] isSelf])
		{
			BOOL found=NO;
			int i;
			for (i=0;i<[[[aClassDump curClass] ivars] count];i++)
				if ([(CDOCIvar *)[[[aClassDump curClass] ivars] objectAtIndex:i] offset]==[curLine instrComp:1])
				{
					found=YES;
					break;
				}
            
			if (found)
			{
				// load ivar
				[curLine setShow:NO];
				CDLine* addLine = [[CDLine alloc] initWithData:[[[[aClassDump curClass] ivars] objectAtIndex:i] name] offset:curOff old:curLine];
				[addLine setAsm:NO];
				[addLine setShow:NO];
                
				// remove quotes and @ shite
				NSString* typeString = [((CDOCIvar*)[[[aClassDump curClass] ivars] objectAtIndex:i]) frmString];
				//NSLog(@"accessing ivar %@: frmString %@\n",[[[[aClassDump curClass] ivars] objectAtIndex:i] name],typeString);				
				
				// remove prefixing spaces
				while ([typeString hasPrefix:@" "])
					typeString = [typeString substringFromIndex:1];
				
				// remove suffixing spaces
				NSRange spRange = [typeString rangeOfString:@" "];
				if (spRange.location!=NSNotFound)
					typeString = [typeString substringToIndex:spRange.location];
				else
					typeString = @"UNKNOWN_TYPE";
                
				[addLine setType:typeString];	
				
				NSUInteger refLine = [lineArray count];
				[addLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initWithLine:refLine] cond:NO];
				[lineArray addObject:addLine];
			}
		}
		else if ([[curLine regData:[curLine instrComp:2] cond:NO] isLineRef])
		{
			if ([curLine instrComp:1]==0)
			{
				//NSLog(@"deref lineref\n");
				[curLine setShow:NO];
				
				NSUInteger lineNum = [[curLine regData:[curLine instrComp:2] cond:NO] lineRef];
				NSString* refLineStr = [(CDLine*)[lineArray objectAtIndex:lineNum] data];
				NSString* newStr;
				if ([refLineStr hasPrefix:@"&"])
					newStr = [[NSString alloc] initWithString:[refLineStr substringFromIndex:1]];
				else
					newStr = [[NSString alloc] initWithFormat:@"*%@",refLineStr,nil];
				
				CDLine* addLine = [[CDLine alloc] initWithData:newStr offset:curOff old:curLine];
				[addLine setAsm:NO];
				[addLine setShow:NO];
				
				NSUInteger refLine = [lineArray count];
				[addLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initWithLine:refLine] cond:NO];
				[lineArray addObject:addLine];
				
			}
			else
				[curLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initInvalid] cond:NO];
		}
		else
			[curLine setReg:[curLine instrComp:0] data:[[CDRegVal alloc] initInvalid] cond:NO];
		
		// special stack case (r1)
		if ([curLine instrComp:2]==1)
		{
			[curLine setShow:NO];
			CDLine* addLine = [[CDLine alloc] initWithData:[[NSString alloc] initWithFormat:@"restore r%d on stack",[curLine instrComp:0],nil] offset:curOff old:curLine];
			[lineArray addObject:addLine];
			
			[addLine setShow:NO]; // don't show stack stuff
			
			NSNumber* offset = [NSNumber numberWithLong:[curLine instrComp:1]];
            //			NSLog(@"found on stack %@\n",[[method stack] objectForKey:offset]);
			if ([[method stack] objectForKey:offset])
				[addLine setReg:[curLine instrComp:0] data:[[method stack] objectForKey:offset] cond:NO];
		}
	}
}

- (void)simulateLine:(CDLine*)thisLine withOffset:(long)offset
{
	// this function is sad because of how little it gets to do :(
	
	[NSException raise:@"NSNotImplemented" format:@"ARM Simulation is not implemented"];
	
	curLine = thisLine;
	curOff = offset;
    
	[self cleanupInstructions];
	[self handleFinalInstructions];
    
	[self handleCompare];
    
	[self handleForLoop];
	[self handleConditionalBranch];
	
	[self handleRtype];
    
	[self handleStore];
	[self handleLoad];
}

@end


/*
 int disEnum;
 for (disEnum=0;disEnum<[disArray count];disEnum++)
 {
 NSString* dis = [disArray objectAtIndex:disEnum];
 if ([dis length]<9)
 continue;
 
 CDLine* thisLine = [[[CDLine alloc] init:[mach sym]] autorelease];
 
 long offset;
 if (sscanf([[dis substringToIndex:8] cString],"%x",&offset)!=1)
 continue;
 
 [thisLine setOffset:offset];
 [thisLine setData:[dis substringFromIndex:9]];
 
 
 if (firstLine)
 {
 firstLine = NO;
 // set r3 to self
 [thisLine setReg:3 data:[[[CDRegVal alloc] initWithSelf] autorelease] cond:NO];
 // set r5... to arguments
 // bugfix: if selector returns a struct, start arguments at r6
 
 // bugfix: add selector offset to r12
 // hopefully this is true in all versions of objc_msgSend (should verify)
 [thisLine setReg:12 data:[[[CDRegVal alloc] initWithValue:imp] autorelease] cond:NO];
 
 CDSelector* callSelector = [[[CDSelector alloc] initWithSelector:name] autorelease];
 if ([callSelector args])
 {
 BOOL retStruct;
 [callSelector setArgsWithFrmString:[[aClassDump methodTypeFormatter] formatMethodName:name type:type symbolReferences:nil] retStruct:&retStruct];
 int i;
 for(i=0;i<[callSelector args];i++)
 {				
 int refLine = [lineArray count];
 
 #ifdef DEBUG					
 NSLog(@"setting arg %d (%@) line %d\n",i,[callSelector argNum:i],refLine);
 #endif					
 if (retStruct)
 [thisLine setReg:6+i data:[[[CDRegVal alloc] initWithLine:refLine] autorelease] cond:NO];
 else
 [thisLine setReg:5+i data:[[[CDRegVal alloc] initWithLine:refLine] autorelease] cond:NO];
 
 // add a line describing this argument :-/
 CDLine* addLine = [[[CDLine alloc] initWithData:[callSelector argNum:i] offset:offset old:thisLine] autorelease];
 [addLine setAsm:NO];
 [addLine setShow:NO];
 if (![[callSelector argTypeNum:i] isKindOfClass:[NSNull class]])
 [addLine setType:[callSelector argTypeNum:i]];
 
 [lineArray addObject:addLine];
 
 }
 }
 }
 / *
 * If this isn't the first line, then let's set the registers to be the same as the last line
 *
 * todo: last line is not enough (in case of conditional branches and unconditional branching)
 *	this is currently one of the most serious design flaws in code-dump
 * For example, if we branch on some condition, and modify the registers during the branch,
 *	if we just choose last line, branch is always shown as taken in code-dump
 *	if we just choose line BEFORE branch, branch is always shown as not taken in code-dump
 *  EITHER WAY, we have a problem -- the solution is to pull whatever actions are taken after the branch
 *	back into the branch, IF they are affected by the branch
 *		This is currently not implemented, and considered difficult to implement (although certainly possible)
 *
 *  The current implementation shows code as if the branch was NOT taken (by setting registers to last
 *    line where bTargets count = current bTargest count
 * note that because often actions are taken WITHIN a branch (instead of just modifying registers), this will work
 *	additionally, often branch blocks contain unconditional branches at the end.  Since unconditional branches
 *	DO currently pull later actions into the branch (based on certain factors, like amount being pulled in), this
 *	will take care of the conditional branches too (often, but not always)
 */
/*
 if ([lineArray count])
 {
 [thisLine setReg:[lineArray lastObject]];
 int i;
 BOOL hitBranchTarget=NO;
 for (i=0;i<[[thisLine bTarget] count];i++)
 // also do a check to see if we've hit a branch target
 if (offset>=[[[thisLine bTarget] objectAtIndex:i] longValue])
 {
 //NSLog(@"%x is greater than %x, removing\n",offset,[[[thisLine bTarget] objectAtIndex:i] longValue]);
 [[thisLine bTarget] removeObject:[[thisLine bTarget] objectAtIndex:i]];
 i=0;
 hitBranchTarget=YES;
 }
 
 // NOW search backwards to find the last time the bTargets equalled our current btargets, and set our
 // registers to equal that line
 if (hitBranchTarget==YES)
 {
 #ifdef DEBUG
 NSLog(@"search backwards for conditional branch\n");
 #endif
 for (i=[lineArray count]-1;i>=0;i--)
 {
 NSArray* searchTarg = [[lineArray objectAtIndex:i] bTarget];
 if ([searchTarg count]==[[thisLine bTarget] count])
 {
 // found an instruction with the same target count
 // since bTargets is a stack, this means they're equal
 // which means we're going to set our registers to this (which is the beginning of a conditional branch)
 //NSLog(@"found branch start %@\n",[(CDLine*)[lineArray objectAtIndex:i] data]);
 [thisLine setReg:[lineArray objectAtIndex:i]];
 break;
 }
 }
 }
 }
 
 [lineArray addObject:thisLine];
 // debugging
 #ifdef DEBUG
 NSLog(@"%@\n",dis);
 #endif
 // do arm simulation using fancy new simulator class
 [armSimulator simulateLine:thisLine withOffset:offset];
 
 // I'm not really sure how to handle the NS-functions
 // they're not Cocoa functions.  Maybe there's some way to augment the class data with
 // their type information.  Doing them by hand (as below) is just not a valid option
 // (there are actually quite a few more, like the NSAlert functions and such)
 if ([thisLine isNSBeep])
 {
 [thisLine setShow:NO];
 CDLine* addLine = [[[CDLine alloc] initWithData:@"NSBeep();" offset:offset old:thisLine] autorelease];
 [addLine setAsm:NO];
 [lineArray addObject:addLine];
 }
 else if ([thisLine isNSLog])
 {
 NSLog(@"isnslog\n");
 
 [thisLine setShow:NO];
 NSString* outType;
 NSString* logString = [self lookupObject:3 line:thisLine lineArray:lineArray file:mach outType:&outType];
 NSMutableString* logCall = [[[NSMutableString alloc] initWithFormat:@"NSLog(%@",logString,nil] autorelease];
 
 int nComp = [CDSelector formatCompon:logString];
 int j;
 for (j=0;j<nComp;j++)
 {
 NSString* outType;
 NSString* argObject = [self lookupObject:4+j line:thisLine lineArray:lineArray file:mach outType:&outType];					
 [logCall appendString:@", "];
 [logCall appendString:argObject];
 }
 [logCall appendString:@");"];
 
 CDLine* addLine = [[[CDLine alloc] initWithData:logCall offset:offset old:thisLine] autorelease];
 [addLine setAsm:NO];
 [lineArray addObject:addLine];
 
 }
 // The great selector handler!
 // this is the real meat of everything, since selectors are the most important assembly
 else if ([thisLine isSelector])
 {
 NSLog(@"is selec\n");
 
 [thisLine setShow:NO];
 [thisLine setBranch:YES];
 
 int regOffset = [thisLine returnStruct] ? 1 : 0;
 
 // get selector
 CDSelector* selector;
 if ([[thisLine regData:4+regOffset cond:NO] data])
 {			
 unsigned long selPtr = (unsigned long)[[thisLine regData:4+regOffset cond:NO] value];
 if ([mach hasDifferentByteOrder]==YES)
 selPtr = CFSwapInt32(selPtr);									
 char* dataPtr = (char*)[mach pointerFromVMAddr:selPtr];
 if (dataPtr==NULL)
 selector = [[[CDSelector alloc] init] autorelease];
 else
 selector = [[[CDSelector alloc] initWithSelector:[[[NSString alloc] initWithCString:dataPtr encoding:NSASCIIStringEncoding] autorelease]] autorelease];
 }
 else
 {
 NSLog(@"bad selector: %@\n",[thisLine regData:4+regOffset cond:NO]);
 selector = [[[CDSelector alloc] init] autorelease];
 }
 
 // get object and type -- type only if local class field
 NSString* outType;
 if ([thisLine isSuperObj])
 {
 [selector setObject:@"super"];
 [selector setObjectType:[[aClassDump curClass] name]];
 }
 else
 {
 NSString* object = [self lookupObject:3+regOffset line:thisLine lineArray:lineArray file:mach outType:&outType];
 
 [selector setObject:object];
 if ([object isEqualToString:@"self"])
 [selector setObjectType:[[aClassDump curClass] name]];
 else
 [selector setObjectType:outType];
 }
 #ifdef DEBUG			
 NSLog(@"%@\n",[selector description]);
 #endif
 int i;
 for (i=0;i<[selector args];i++)
 {
 // we need to know to print this argument as an object or an integer
 BOOL isArgumentObject = [selector argumentIsCocoa:i withLines:lineArray cd:aClassDump];
 #ifdef DEBUG
 NSLog(@"argument %d isobj %d\n",i,isArgumentObject);
 #endif
 if (isArgumentObject)
 {
 NSString* outType;
 NSString* argObject = [self lookupObject:5+i+regOffset line:thisLine lineArray:lineArray file:mach outType:&outType];
 //NSLog(@"argObject = %@\n",argObject);
 [selector addObjectArg:i object:argObject];
 }
 else
 {
 if ([[thisLine regData:5+i+regOffset cond:NO] isLineRef])
 {
 NSString* outType;
 NSString* argObject = [self lookupObject:5+i+regOffset line:thisLine lineArray:lineArray file:mach outType:&outType];
 #ifdef DEBUG
 NSLog(@"argObject = %@\n",argObject);
 #endif
 [selector addObjectArg:i object:argObject];						
 }
 else
 [selector addDataArg:i data:[[thisLine regData:5+i+regOffset cond:NO] value]];
 }
 }
 
 if ([selector formatString])
 {
 int nComp = [CDSelector formatCompon:[selector lastArg]];
 int j;
 for (j=0;j<nComp;j++)
 {
 NSString* outType;
 NSString* argObject = [self lookupObject:5+i+regOffset line:thisLine lineArray:lineArray file:mach outType:&outType];					
 [selector addFormatArg:argObject];
 i++;
 }
 }
 
 CDLine* addLine = [[[CDLine alloc] initWithData:[selector description] offset:offset old:thisLine] autorelease];
 [addLine setAsm:NO];
 [addLine setBranch:YES];
 [addLine setType:[selector resultType:lineArray cd:aClassDump]];
 #ifdef DEBUG			
 NSLog(@"selector result type is %@\n",[addLine type]);
 #endif			
 [lineArray addObject:addLine];
 
 // this happens when some function end with an unconditional branch to objc_msgSend
 // we have to add "return" to signify that it's the end
 // alternatively, this can happen if we're in a branch section and we're returning
 //
 if ([[thisLine op] isEqualToString:@"b"]||[[thisLine op] isEqualToString:@"ba"])
 {
 #ifdef DEBUG
 NSLog(@"uncond branch to selector\n");
 //NSLog(@"adding last line ref to %d\n",[lineArray count]-1);
 #endif
 // we need to preset r3 because adding a return line will no longer render this condition true below
 [(CDLine*)[lineArray lastObject] setReg:3 data:[[[CDRegVal alloc] initWithLine:([lineArray count]-1)] autorelease] cond:NO];
 
 // we're setting addLine to NO because it's going to be incorporated in the return statement
 // this may cause some issues (?)
 [addLine setShow:NO];
 
 // use addLine as line ref
 CDLine* retLine = [[[CDLine alloc] initWithData:@"return" offset:offset old:addLine] autorelease];
 [retLine setAsm:NO];
 [lineArray addObject:retLine];
 }
 }
 / *	C-style function calls are handled only to the degree that we show them used
 *		argument passing has not been implemented
 *//*
    else if ([[thisLine op] isEqualToString:@"bl"])
    {		
    long immed = [thisLine instrComp:0];
    
    NSLog(@"immed! %08x\n",immed);
    
    CDSymbol* found = [[mach sym] findByOffset:immed];
    if (found)
    {
    [thisLine setShow:NO];
    
    NSString* funcName = [[[NSString alloc] initWithFormat:@"%@()",[found name],nil] autorelease];
    if ([funcName hasPrefix:@"_"])
    funcName = [funcName substringFromIndex:1];
    #ifdef DEBUG
    NSLog(@"C-style branch to %@\n",funcName);
    #endif
    
    CDLine* addLine = [[[CDLine alloc] initWithData:funcName offset:offset old:thisLine] autorelease];
    [addLine setAsm:NO];
    [addLine setBranch:YES];
    [lineArray addObject:addLine];
    }
    else
    NSLog(@"Unknown C-style branch 0x%08x!\n",immed);
    
    }
    else if ([[thisLine op] isEqualToString:@"b"])
    {
    #ifdef DEBUG
    NSLog(@"handling unconditional branch\n");
    #endif
    / * Unconditional branches are hard
    *
    * in the best case, they are used to bail on an error, jumping to the end of the function
    * in the worst case, they are used in for loops
    *
    * first, we must check if the target is within the current function.  if not, we can't handle it
    *
    * this is a simple solution to unconditional branches that copies all the instructions from the
    *    destination of the branch to the source of the branch
    * it could use some added logic to verify that this is a good idea (e.g. looking at the branch length,
    *    and comparing that to the length of code after the destination
    *
    * Some research should be invested how Cocoa programs are compiled... how long branches are compiled
    * as opposed to short branches.  Presumably, this would be the same in any gcc compiled ARM binary
    *//*
       unsigned long targOff = [thisLine instrComp:0];
       #ifdef DEBUG
       NSLog(@"offset %x targOff %x start %x end %x\n",offset,targOff,startOff,endOff);
       #endif
       unsigned long branchDist = abs(targOff-offset);
       unsigned long afterBrDist = endOff-targOff;
       #ifdef DEBUG
       NSLog(@"brDist %d afterDist %d\n",branchDist,afterBrDist);
       #endif
       // sigh, this will be true if we're currently looking at code which is in a branch
       // if we try to process a branch while currently processing the same branch,
       // we can get into an infinite loop
       //
       // this happens in for loops
       //
       BOOL inBranch=NO;
       if ([lineArray count]>2&&offset == [[lineArray objectAtIndex:[lineArray count]-2] offset])
       {
       #ifdef DEBUG
       NSLog(@"but already in branch\n");
       #endif
       inBranch = YES;
       }
       
       //
       // this will use the code-copy hack if the amount of 
       // code after the branch is less than 20 instructions
       //
       // this is the currently the only unconditional branch algorithm
       //
       //NSLog(@"code-copy hack from %x\n",targOff);
       // we're using createDisassemblyArrayForOffset to get the correct number
       //	of instructions to copy (end of branch isn't always end of method)
       //
       // additionally, we need to check that the current offset is not in the disassem array
       //
       NSArray* copyArray = [self createDisassemblyArrayForOffset:targOff withDisas:disasm file:mach];
       //CFShow(copyArray);
       
       if (targOff > offset	// forward branch
       ||(targOff < offset && (offset-targOff)/4 > [copyArray count]))	// backwards branch where num instructions less than num instructions between
       {																	// target and source -- this is only the case when we branch back, but return and
       // don't make it back to the source
       if ([copyArray count]<20&&!inBranch)
       {
       #ifdef DEBUG
       NSLog(@"copying.....\n");
       #endif
       [thisLine setShow:NO];						
       // copy loop instructions from destination to current location
       int i;
       int curLoc = disEnum;
       for (i=0;i<[copyArray count];i++)
       {
       NSString* nxtDis = [copyArray objectAtIndex:i];
       if ([nxtDis length]<9)
       continue;
       long nxtOff;
       if (sscanf([[nxtDis substringToIndex:8] cString],"%x",&nxtOff)!=1)
       continue;
       if (nxtOff>=targOff)
       {
       curLoc++;
       // replace offset of line copied with current offset
       // that's right, all lines copied will have current offset... hrm.. could cause probs(?)
       NSString* replaceLine = [[[NSString alloc] initWithFormat:@"%08x%@",offset,[nxtDis substringFromIndex:8],nil] autorelease];
       [disArray insertObject:replaceLine atIndex:curLoc];
       #ifdef DEBUG
       NSLog(@"found %x targOff: %x.  endOff=%x\n",nxtOff,targOff,endOff);
       #endif
       }
       }
       }
       
       }
       }
       
       //NSLog(@"linesize %d\n",[lineArray count]);
       
       // branching or calling functions affect r3
       if ([(CDLine*)[lineArray lastObject] isBranch])
       [(CDLine*)[lineArray lastObject] setReg:3 data:[[[CDRegVal alloc] initWithLine:([lineArray count]-1)] autorelease] cond:NO];
       
       }
       if (disArray)
       [disArray release];
       
       // all done, now append the results to the string	
       [self appendLines:lineArray toString:resultString ret:retValue file:mach];
       */