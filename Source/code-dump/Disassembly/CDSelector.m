//
//  CDSelector.m
//  class-dump
//
//  Created by Braden Thomas on 4/8/06.
//

#import "CDSelector.h"
#import "CDClassDump.h"
#import "CDTypeFormatter.h"
#import "CDOCModule.h"
#import "CDOCSymtab.h"
#import "CDOCClass.h"

@implementation CDSelector

- (id)init
{
	if ([super init]==nil)
		return nil;
	
	object = [[NSMutableString alloc] init];
	selector = [[NSMutableString alloc] init];	
	arguments = [[NSMutableArray alloc] init];
	argumentTypes = [[NSMutableArray alloc] init];
	frmArgs = [[NSMutableArray alloc] init];
	
	resultType = nil;
	objectType = nil;
	funcDef = nil;
	
	return self;
}

- (id)initWithMethod:(CDOCMethod*)meth classDump:(CDClassDump*)cd
{
	if ([self init]==nil)
		return nil;

	[selector setString:[meth name]];
	int i;
	for (i=0;i<[self selArgCnt];i++)
	{
		[arguments addObject:[[NSMutableString alloc] init]];
		[argumentTypes addObject:[[NSNull alloc] init]];
	}
	
	if ([self args])
		[self setArgsWithFrmString:[[cd methodTypeFormatter] formatMethodName:[meth name] type:[meth type]]];
	
	return self;		
}

- (int)selArgCnt
{
	int p=0,i;
	for (i=0;i<[selector length];i++)
		if ([selector characterAtIndex:i]==':')
			p++;
	return p;
}

- (BOOL)isCocoa:(NSString*)type
{
	return ([type hasPrefix:@"NS"])||
				([type isEqualToString:@"id"])||
				([type isEqualToString:@"SEL"])||
				([type isEqualToString:@"Class"])||
				([type isEqualToString:@"void *"]);
}

- (int)args
{
	return [arguments count];
}

- (NSString*)description
{
	NSMutableString* description = [[NSMutableString alloc] init];
	[description appendString:@"["];
	if (object==nil)
		[description appendString:@"UNKNOWN_OBJECT"];
	else
		[description appendString:object];
		
	[description appendString:@" "];	
	
	if ([self args]==0)
		[description appendString:selector];
	else
	{
		NSArray* selComp = [selector componentsSeparatedByString:@":"];
		int i;
		for (i=0;i<[self selArgCnt];i++)
		{
			[description appendFormat:@"%@:",[selComp objectAtIndex:i],nil];
			if (i>=[arguments count])
				[description appendString:@"UNKNOWN_ARGUMENT"];
			else if ([arguments objectAtIndex:i]==nil)
				[description appendString:@"UNKNOWN_ARGUMENT"];
			else
			{
				if ([[arguments objectAtIndex:i] isKindOfClass:[NSNumber class]])
				{
					if ([[argumentTypes objectAtIndex:i] isKindOfClass:[NSString class]])
					{
						// here put special case data argument types
						if ([[argumentTypes objectAtIndex:i] isEqualToString:@"BOOL"])
						{
							if ([[arguments objectAtIndex:i] boolValue]==NO)
								[description appendString:@"NO"];
							else
								[description appendString:@"YES"];
						}
						else
							[description appendString:[[arguments objectAtIndex:i] stringValue]];		
					}
					else
						[description appendString:[[arguments objectAtIndex:i] stringValue]];		
				}
				else if ([[arguments objectAtIndex:i] isKindOfClass:[NSString class]])
				{
					// this is an object type
					if ([[argumentTypes objectAtIndex:i] isKindOfClass:[NSString class]])
					{
						// explicit typing disabled
						//[description appendFormat:@"(%@)",[argumentTypes objectAtIndex:i],nil];
					
						// here put special case object argument types
						if ([[argumentTypes objectAtIndex:i] isEqualToString:@"SEL"]&&![[arguments objectAtIndex:i] isEqualToString:@"nil"])
							[description appendFormat:@"@selector(%@)",[arguments objectAtIndex:i],nil];
						else
							[description appendString:[arguments objectAtIndex:i]];
					}
					else
						[description appendString:[arguments objectAtIndex:i]];
				}
				else
					[description appendString:@"UNKNOWN_ARGUMENT"];
			}
			[description appendString:@" "];
		}
	}
	int i;
	for(i=0;i<[frmArgs count];i++)
	{
		[description appendString:@", "];
		[description appendString:[frmArgs objectAtIndex:i]];
	}
	
	[description appendString:@"]"];	
	return description;
}

- (NSString*)object
{
	return object;
}

- (NSString*)sel
{
	return selector;
}

- (NSString*)getFunctionDefinitionWithLines:(NSArray*)lineArray success:(BOOL*)success cd:(CDClassDump*)cd obj:(NSString**)selectObj
{
	*selectObj = [[NSString alloc] initWithString:object];
	if (!*selectObj)
		return nil;
#ifdef DEBUG
	NSLog(@"Get function defintion %@/%@\n",*selectObj,selector);
#endif
	if ([*selectObj hasPrefix:@"result_"])
	{
		int lineNum = [[*selectObj substringFromIndex:7] intValue];

		*selectObj = [[NSString alloc] initWithString:[(CDOCMethod*)[lineArray objectAtIndex:lineNum] type]];

		//NSLog(@"lookedup resulttype= %@\n",[[lineArray objectAtIndex:lineNum] type]);

		//remove pointer from end of type
		NSRange spaceRange = [*selectObj rangeOfString:@" "];
		if (spaceRange.location!=NSNotFound)
		{
			NSString* tmp = [[NSString alloc] initWithString:[*selectObj substringToIndex:spaceRange.location]];

			*selectObj = tmp;
		}
	}
	else if ([*selectObj hasPrefix:@"["])
	{
		if (objectType!=nil)
		{

			*selectObj = [[NSString alloc] initWithString:objectType];
			//remove pointer from end of type
			NSRange spaceRange = [*selectObj rangeOfString:@" "];
			if (spaceRange.location!=NSNotFound)
			{
				NSString* tmp = [[NSString alloc] initWithString:[*selectObj substringToIndex:spaceRange.location]];

				*selectObj = tmp;
			}
			//NSLog(@"set selectObj to type %@\n",objectType);
		}
	}
	else if ([*selectObj isEqualToString:@"self"]||[*selectObj isEqualToString:@"super"])
	{
		*selectObj = [[NSString alloc] initWithString:objectType];
#ifdef DEBUG
		NSLog(@"obj is self/super, setting to %@\n",*selectObj);
#endif
	}

	// check for special cases (NSApp)
	if ([*selectObj isEqualToString:@"NSApp"])
	{
        *selectObj = @"NSApplication";
	}

	// store function definition once we obtain it to refrain from repeated lookups
	if (funcDef!=nil)
	{
		*success=YES;
		return [[NSString alloc] initWithString:funcDef];
	}

	// check if this is a local class object
#ifdef DEBUG
	NSLog(@"check if %@ is local class obj\n",*selectObj);
#endif
	int i;
	NSArray* cl = [cd allclasses];
	for (i=0;i<[cl count];i++)
		if ([[[cl objectAtIndex:i] name] isEqualToString:*selectObj])
		{
#ifdef DEBUG
			NSLog(@"found local class %@!\n",*selectObj);
			//CFShow(cl);
#endif
			NSString* outfuncDef = [[cl objectAtIndex:i] getFuncDefMatching:self cd:cd];
			if (outfuncDef==nil)
			{
				// bugfix 4/21, added superclass lookups for local classes
				NSString* curObj=[[cl objectAtIndex:i] superClassName];
				while (1)
				{
					if ((curObj==nil)||(![curObj length]))
						break;				
					NSArray* objHeader = [[[cd lookupDict] objectForKey:@"class"] objectForKey:curObj];
					if (objHeader==nil)
						NSLog(@"Error: header for object %@ cannot be found\n",curObj);
					else
					{
						int j;
						for (j=0;j<[objHeader count];j++)
						{
							outfuncDef = [self getDefinition:[objHeader objectAtIndex:j]];
							if (outfuncDef!=nil)
								break;
						}
					}
					// yay, we found it in a superclass
					if (outfuncDef!=nil)
						break;
					
					//curObj = [[[cd lookupTable] objectForKey:@"subclass"] objectForKey:curObj];
                    curObj = [[cd lookupTable] subclassOf:curObj];
				}
			}

			// I've leaving this in here, even though it should be totally unnecessary
			// from above.  I'm leaving it in, just because there could be some weird
			// situtation where the above code doesn't work (perhaps if a class
			// subclasses a local class), in we want to at least get the NSObject selectors
			// plus, it doesn't really hurt
			if (outfuncDef==nil)
			{
				// lookup in NSObject
				outfuncDef = [self getDefinition:@"/System/Library/Frameworks/Foundation.framework/Headers/NSObject.h"];
				if (outfuncDef==nil)
				{
					*success=NO;
					return @"UNKNOWN_RES_TYPE";	
				}
			}
			*success=YES;
			funcDef = [[NSString alloc] initWithString:outfuncDef];
			return [[NSString alloc] initWithString:funcDef];	
		}

	// if this isn't a cocoa object
	if (![self isCocoa:*selectObj])
	{
		// it may be a class field
		if (objectType!=nil)
		{		
			// in this case, it's a class field
			*selectObj = [[NSString alloc] initWithString:objectType];
			
			//NSLog(@"class field type is %@\n",objectType);
			
			//remove pointer from end of type
			NSRange spaceRange = [*selectObj rangeOfString:@" "];
			if (spaceRange.location!=NSNotFound)
			{
				NSString* tmp = [[NSString alloc] initWithString:[*selectObj substringToIndex:spaceRange.location]];
				*selectObj = tmp;
			}

			//NSLog(@"set field selectObj to type %@\n",objectType);
		}
		else
		{
			*success=NO;
			return [[NSString alloc] initWithString:*selectObj];
		}
	}

	// special case, since this clearly won't be found in a header
	// we must guess the object type
	if (([*selectObj isEqualToString:@"id"])||([*selectObj isEqualToString:@"UNKNOWN_FIELD_TYPE"]))
	{
		NSString *outfuncDef = [self searchDB:[cd lookupTable] forSelector:selector];
		if (outfuncDef!=nil)
		{
			*success=YES;
			funcDef = [[NSString alloc] initWithString:outfuncDef];
			return [[NSString alloc] initWithString:funcDef];
		}
		else
		{
			*success=NO;
			return @"UNKNOWN_FIELD_TYPE";
		}
	}
#ifdef DEBUG
	NSLog(@"looking up headerpath for %@\n",*selectObj);
#endif
	NSArray* frameworkHeaderPath = [self headerPath:*selectObj cd:cd];
	if (frameworkHeaderPath==nil)
	{
		*success=NO;
		return @"UNKNOWN_RES_TYPE";
	}
#ifdef DEBUG
	NSLog(@"looking up selector %@ in %ld paths\n",selector,[frameworkHeaderPath count]);
#endif
	NSEnumerator* defEnum = [frameworkHeaderPath objectEnumerator];
	NSString *framePath;
	NSString* outfuncDef=nil;
	while ((framePath=[defEnum nextObject]))
	{
		outfuncDef = [self getDefinition:framePath];
		if (outfuncDef!=nil)
			break;
	}
	if (outfuncDef==nil)
		outfuncDef = [self getDefinition:@"/System/Library/Frameworks/Foundation.framework/Headers/NSObject.h"];
	
	if (outfuncDef==nil)
	{
		// this is a "last chance" mechanism that searches for selectors
		// is in case we somehow got a bad object type
#ifdef DEBUG
		NSLog(@"Can't find function definition with object type!\n");
#endif
		outfuncDef = [self searchDB:[cd lookupTable] forSelector:selector];
		if (outfuncDef!=nil)
		{
			*success=YES;
			funcDef = [[NSString alloc] initWithString:outfuncDef];
			return [[NSString alloc] initWithString:funcDef];			
		}
		else
		{
			*success=NO;
			return @"UNKNOWN_RES_TYPE";
		}		
	}
	*success=YES;
	funcDef = [[NSString alloc] initWithString:outfuncDef];
#ifdef DEBUG
	NSLog(@"funcdef stored %@\n",funcDef);
#endif
	return [[NSString alloc] initWithString:funcDef];	
}

- (NSString*)resultType:(NSArray*)lineArray cd:(CDClassDump*)cd
{
	if (resultType!=nil)
		return resultType;

	BOOL success;
	NSString* selObj;
	NSString* outfuncDef = [self getFunctionDefinitionWithLines:lineArray success:&success cd:cd obj:&selObj];
	if (success==NO||outfuncDef==nil)
		return @"UNKNOWN_RES_TYPE";
#ifdef DEBUG	
	NSLog(@"outfuncDef %@: selobj %@\n",outfuncDef,selObj);	
#endif	
	NSRange start = [outfuncDef rangeOfString:@"("];
	NSRange end = [outfuncDef rangeOfString:@")" options:0 range:NSMakeRange(start.location,[outfuncDef length]-start.location)];

	if ((start.location==NSNotFound)||(end.location==NSNotFound))
		return @"UNKNOWN_RES_TYPE";
	
	NSString* retObject = [[NSString alloc] initWithString:[outfuncDef substringWithRange:NSMakeRange(start.location+1,end.location-start.location-1)]];	

	// generally alloc/init functions return id, but are actually returning class type
	if ([retObject isEqualToString:@"id"])
	{
		if (selObj!=nil)
		{
			if (funcDef&&[funcDef hasPrefix:@"+"])
			{
				// although this may be a mistake, it's better to assign an incorrect type then assign no type
				// plus, most id-returning class methods are returning self-types
#ifdef DEBUG
				NSLog(@"class method returning id!!\n");
#endif
				if ([selObj isEqualToString:@"self"])
					retObject = [[NSString alloc] initWithFormat:@"%@ *",objectType,nil];
				else
					retObject = [[NSString alloc] initWithFormat:@"%@ *",selObj,nil];	
			}
			// special cases where out is id but actually returns class type
			else if (	([selector hasPrefix:@"alloc"])||
					([selector hasPrefix:@"init"])||
					([selector hasPrefix:@"default"]))
			{
				if ([selObj isEqualToString:@"self"])
					retObject = [[NSString alloc] initWithFormat:@"%@ *",objectType,nil];
				else
					retObject = [[NSString alloc] initWithFormat:@"%@ *",selObj,nil];	
			}
			
		}
	}
#ifdef DEBUG		
	NSLog(@"Got type %@\n",retObject);
#endif

	return retObject;
}

- (BOOL)argumentIsCocoa:(int)arg withLines:(NSArray*)lineArray cd:(CDClassDump*)cd
{
	BOOL success;
	NSString* selObj;
	NSString* outfuncDef = [[NSString alloc] initWithString:[self getFunctionDefinitionWithLines:lineArray success:&success cd:(CDClassDump*)cd obj:&selObj]];
	if (success==NO)
		return NO;
#ifdef DEBUG
	NSLog(@"outfuncDef %@: selobj %@\n",outfuncDef,selObj);
#endif
	NSArray* selComp = [outfuncDef componentsSeparatedByString:@":"];
	if ([selComp count]<=arg+1)
		return NO;

	NSRange start = [[selComp objectAtIndex:(arg+1)] rangeOfString:@"("];
	NSRange end = [[selComp objectAtIndex:(arg+1)] rangeOfString:@")" options:0 range:NSMakeRange(start.location,[[selComp objectAtIndex:(arg+1)] length]-start.location)];

	if ((start.location==NSNotFound)||(end.location==NSNotFound))
		return NO;
	
	NSString* retObject = [[NSString alloc] initWithString:[[selComp objectAtIndex:(arg+1)] substringWithRange:NSMakeRange(start.location+1,end.location-start.location-1)]];	
#ifdef DEBUG	
	NSLog(@"argument %d retobject %@\n",arg,retObject);
#endif
	[argumentTypes replaceObjectAtIndex:arg withObject:retObject];

	return [self isCocoa:retObject];
}

- (void)setObjectType:(NSString*)type
{
	objectType = [[NSString alloc] initWithString:type];
}


- (void)setObject:(NSString*)obj
{
	[object setString:obj];
}

- (void)addObjectArg:(int)n object:(NSString*)argObject
{
	[arguments replaceObjectAtIndex:n withObject:argObject];
}

- (void)addFormatArg:(NSString*)argObject
{
	[frmArgs addObject:argObject];
}


- (void)addDataArg:(int)n data:(long)value
{
	[arguments replaceObjectAtIndex:n withObject:[[NSNumber alloc] initWithLong:value]];
}

// headerPath: gets framework header path for class
- (NSArray*)headerPath:(NSString*)inObj cd:(CDClassDump*)cd
{
	NSMutableArray* frameworkHeaderPaths = [[NSMutableArray alloc] init];

	if ([inObj hasPrefix:@"UNKNOWN_"])
		return frameworkHeaderPaths;

	NSString *curObj = inObj;
	while (1)
	{
		if ((curObj==nil)||(![curObj length]))
			break;
        NSLog(@"***** WARNING!!!! WE ARE IN AN AREA THAT NEEDS TO BE FIXED! (CDSelector / headerPath) *****");

#pragma mark - NEED TO FIX!!! THIS LOOKS UP THE FRAMEWORK HEADERS
		//NSArray* objHeader = [[[cd lookupTable] objectForKey:@"class"] objectForKey:curObj];
		//if (objHeader==nil)
//			NSLog(@"Error: header for object %@ cannot be found\n",curObj);
//		else
//			[frameworkHeaderPaths addObjectsFromArray:objHeader];
			
		//curObj = [[[cd lookupTable] objectForKey:@"subclass"] objectForKey:curObj];
        curObj = [[cd lookupTable] subclassOf:curObj];
	}
	return frameworkHeaderPaths;
}

// getDefinition: this function actually opens the file and copies the function definition
- (NSString*)getDefinition:(NSString*)path
{
    NSError *error;
	NSMutableString* frameworkFile = [[NSMutableString alloc] initWithContentsOfFile:path encoding:NSASCIIStringEncoding error:&error];
	// remove comments
	while (1)
	{
		NSRange oneLineComm = [frameworkFile rangeOfString:@"//"];
		if (oneLineComm.location!=NSNotFound)
		{
			NSRange endofComm = [frameworkFile rangeOfString:@"\n" options:0 range:NSMakeRange(oneLineComm.location,[frameworkFile length]-oneLineComm.location)];
			if (endofComm.location!=NSNotFound)
			{
				[frameworkFile deleteCharactersInRange:NSMakeRange(oneLineComm.location,endofComm.location-oneLineComm.location)];
				continue;
			}
		}
		NSRange multiComm = [frameworkFile rangeOfString:@"/*"];
		if (multiComm.location!=NSNotFound)
		{
			NSRange multiCommEnd = [frameworkFile rangeOfString:@"*/" options:0 range:NSMakeRange(multiComm.location+1,[frameworkFile length]-multiComm.location-1)];
			if (multiCommEnd.location!=NSNotFound)
			{
				[frameworkFile deleteCharactersInRange:NSMakeRange(multiComm.location,multiCommEnd.location-multiComm.location+2)];
				continue;
			}
		}
		
		break;
	}
	
	if ([self selArgCnt]==0)
	{
		NSString* searchStr = [[NSString alloc] initWithFormat:@")%@;",selector,nil];
		NSRange found = [frameworkFile rangeOfString:searchStr];
		if (found.location==NSNotFound)
		{
			//NSLog(@"Cannot find selector %@ in file %@\n",selector,path);
			//[frameworkFile release];
			return nil;
		}
		NSRange start = [frameworkFile rangeOfString:@"\n" options:NSBackwardsSearch range:NSMakeRange(0,found.location)];
		NSRange end = [frameworkFile rangeOfString:@"\n" options:0 range:NSMakeRange(found.location,[frameworkFile length]-found.location)];
		if ((start.location==NSNotFound)||(end.location==NSNotFound))
		{
			//[frameworkFile release];
			return nil;
		}
		NSString* retVal = [[NSString alloc] initWithString:[frameworkFile substringWithRange:NSMakeRange(start.location+1,end.location-start.location-1)]];
		NSString* compare = [CDClassDump genSearchStrWithDef:retVal];
		if (![compare isEqualToString:selector])
		{
			//[retVal release];
			retVal = nil;
		}

		//[frameworkFile release];
		return retVal;		
	}

	// if the selector has arguments
	NSArray* frameArray = [frameworkFile componentsSeparatedByString:@"\n"];
	NSArray* selArray = [selector componentsSeparatedByString:@":"];
	if (![selArray count])
	{
		//[frameworkFile release];
		return nil;
	}
	
	NSString* outDef = nil;
	int i;
	// complicated loops which verifies that all components of selector exist in found selector
	for (i=0;i<[frameArray count];i++)
	{
		NSRange findRange = [[frameArray objectAtIndex:i] rangeOfString:[selArray objectAtIndex:0]];
		if (findRange.location==NSNotFound)
			continue;
		int j;
		BOOL gFound=YES;
		for (j=1;j<[selArray count];j++)
		{
			if (![[selArray objectAtIndex:j] length])
				continue;
			NSRange findRange2 = [[frameArray objectAtIndex:i] rangeOfString:[selArray objectAtIndex:j]];
			if (findRange2.location==NSNotFound)
			{
				gFound=NO;
				break;
			}
		}
		if (gFound==YES)
		{
			outDef = [[NSString alloc] initWithString:[frameArray objectAtIndex:i]];
#ifdef DEBUG
			NSLog(@"Found selector in %@\n",path);
#endif
			break;
		}
	}

	//[frameworkFile release];
	return outDef;
}

- (NSString*)searchDB:(NSDictionary*)db forSelector:(NSString*)sel
{
	if (!sel||![sel length])
		return nil;

#ifdef DEBUG
	NSLog(@"search db result:\n");
#endif
	NSDictionary* dbDict = [db objectForKey:@"selector"];
	NSArray* outRes = [dbDict objectForKey:sel];
	if (outRes==nil)
	{
		NSLog(@"%@ not found\n",sel);
		return nil;
	}

	if ([outRes count]==1)
		return [outRes objectAtIndex:0];
	
	// see if all selectors found are equal... hrm... there could be better ways
	// e.g. check if equal PER argument.
	// additionally, we could queue the possible classes for a field, and as more selectors are called, 
		// our knowledge of the type increases
		
	NSMutableArray* typeArray = [[NSMutableArray alloc] init];
	NSArray* parArray = [[outRes objectAtIndex:0] componentsSeparatedByString:@")"];

	for (int j=0;j<[parArray count];j++)
	{
		NSRange pRange = [[parArray objectAtIndex:j] rangeOfString:@"("];
		if (pRange.location!=NSNotFound)
			[typeArray addObject:[[parArray objectAtIndex:j] substringFromIndex:pRange.location+1]];
	}

	// alright, changed this to strip out names of variables which do change and only consider types
	int i;
	for (i=0;i<[outRes count];i++)
	{	
		if (![[outRes objectAtIndex:i] isEqualToString:[outRes objectAtIndex:0]])
		{
			NSMutableArray* curtypeArray = [[NSMutableArray alloc] init];
			NSArray* parArray2 = [[outRes objectAtIndex:i] componentsSeparatedByString:@")"];

			for (int j=0;j<[parArray2 count];j++)
			{
				NSRange pRange = [[parArray2 objectAtIndex:j] rangeOfString:@"("];
				if (pRange.location!=NSNotFound)
					[curtypeArray addObject:[[parArray2 objectAtIndex:j] substringFromIndex:pRange.location+1]];
			}
			if ([curtypeArray count]!=[typeArray count])
				return nil;
			for (int j=0;j<[typeArray count];j++)
				if (![[curtypeArray objectAtIndex:j] isEqualToString:[typeArray objectAtIndex:j]])
				{
#ifdef DEBUG
					NSLog(@"types differ!\n");
#endif
					//CFShow(typeArray);
					//CFShow(curtypeArray);
					//CFShow([outRes objectAtIndex:0]);
					return nil;
				}
		}
	}

	//return first def which others are equal/equivalent to
	return [outRes objectAtIndex:0];
}

- (void)setArgsWithFrmString:(NSString*)frmString
{
#ifdef DEBUG
	NSLog(@"setting args from frmString %@\n",frmString);
#endif
	NSArray* defComp = [frmString componentsSeparatedByString:@":"];
	if ([defComp count]<[arguments count])
	{
		NSLog(@"error parsing arguments\n");
		return;
	}

	int i;
	for (i=0;i<[arguments count];i++)
	{
		NSString* curArg = [defComp objectAtIndex:i+1];

		NSRange typeRange = [curArg rangeOfString:@"("];
		if (typeRange.location==NSNotFound)
			continue;
		NSRange typeEndRange = [curArg rangeOfString:@")"];
		if (typeEndRange.location==NSNotFound)
			continue;
		if ([curArg length]<typeEndRange.location+2)
			continue;

		NSRange spRange = [curArg rangeOfString:@" " options:0 range:NSMakeRange(typeEndRange.location,[curArg length]-typeEndRange.location)];
		if (spRange.location!=NSNotFound)
			curArg = [curArg substringToIndex:spRange.location];

		NSString* curArgType = [curArg substringWithRange:NSMakeRange(typeRange.location+1,typeEndRange.location-typeRange.location-1)];
		NSString* curArgName = [curArg substringFromIndex:typeEndRange.location+1];
		
		[arguments replaceObjectAtIndex:i withObject:curArgName];
		[argumentTypes replaceObjectAtIndex:i withObject:curArgType];
	}
}

- (BOOL)formatString
{
	if (funcDef)
		if ([funcDef hasSuffix:@"...;"])
			return YES;
	return NO;
}

+ (int)formatCompon:(NSString*)fstring
{
	NSUInteger i=0;
	int retVal=0;
	while (1)
	{
		NSRange compFind = [fstring rangeOfString:@"%" options:0 range:NSMakeRange(i,[fstring length]-i)];
		if (compFind.location==NSNotFound)
			break;
		i=compFind.location+1;
		if ([fstring characterAtIndex:i]=='%')
			continue;
		retVal++;
	}
	return retVal;
}

- (NSString*)argNum:(int)i
{
	return [arguments objectAtIndex:i];
}

- (NSString*)argTypeNum:(int)i
{
	return [argumentTypes objectAtIndex:i];
}

- (NSString*)lastArg
{
	return [arguments lastObject];
}

@end
