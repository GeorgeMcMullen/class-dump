//
//  CDFunctionCall.m
//  code-dump
//
//  Created by Braden Thomas on 12/19/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "CDFunctionCall.h"
#import "CDMemorySimulator.h"
#import "CDRegVal.h"
#import "CDOCClass.h"
#import "CDOCMethod.h"
#import "CDOCProtocol.h"
#import "CDTypeFormatter.h"

@implementation CDFunctionCall

- (id)initWithDestination:(unsigned long)dest andState:(NSMutableDictionary*)state machOFile:(CDMachOFile*)macho symbolTable:(CDLCSymbolTable*)sym classDump:(CDClassDump*)cd class:(CDOCClass*)cl
{
	self = [super init];
	if (self != nil) {
		mach=macho;
		symbolTable=sym;
		functionInfo = [[NSMutableDictionary alloc] init];
		class=cl;
		classDump=cd;

		[functionInfo setValue:[symbolTable findByOffset:dest] forKey:@"FunctionSymbol"];
		[functionInfo setValue:[NSNumber numberWithInt:0] forKey:@"ArgStart"];

		if ([functionInfo objectForKey:@"FunctionSymbol"])
			[functionInfo setValue:[[classDump lookupTable] lookupSymbol:[functionInfo objectForKey:@"FunctionSymbol"]] forKey:@"FunctionElement"];
		if (![functionInfo objectForKey:@"FunctionElement"]) {
			[self handleSelectorWithState:state lookupTable:[classDump lookupTable]];		
			[functionInfo addEntriesFromDictionary:[[classDump lookupTable] lookupSelector:functionInfo]];
			[self resolveSelectorUncertainties];
		}
		[self findArgsInState:state];		
	}
	return self;
}

- (NSString*)heuristicType
{
	NSString* typeString=nil;
	if ([functionInfo objectForKey:@"Method"]&&[[functionInfo objectForKey:@"Method"] count]==1)
	{
		NSXMLElement* methodElem = [[functionInfo objectForKey:@"Method"] objectAtIndex:0];
		if ([methodElem elementsForName:@"retval"]&&[[methodElem elementsForName:@"retval"] count]==1)
		{
			NSXMLElement* retVal = [[methodElem elementsForName:@"retval"] objectAtIndex:0];
			if (![retVal attributeForName:@"declared_type"])
				[NSException raise:@"NSNotImplemented" format:@"Cannot handle return type %@",retVal];	
			
			typeString = [[retVal attributeForName:@"declared_type"] stringValue];
			
			// this is a heuristic: if method is returning type id, we assume it's the type of the class in which the method exists
			// this is only occasionally true, but quite useful for all init* functions and their autoreleasing brethren
			if ([typeString isEqualToString:@"id"])
			{
				if (![functionInfo objectForKey:@"Class"] || [[functionInfo objectForKey:@"Class"] count]!=1 || ![[[functionInfo objectForKey:@"Class"] objectAtIndex:0] attributeForName:@"name"])
					[NSException raise:@"NSNotImplemented" format:@"Cannot handle absorbing type from %@",functionInfo];		
				typeString = [[[[functionInfo objectForKey:@"Class"] objectAtIndex:0] attributeForName:@"name"] stringValue];
			}
		}
		else
			[NSException raise:@"NSNotImplemented" format:@"Cannot find return type %@",methodElem];

	}
	else
		[NSException raise:@"NSNotImplemented" format:@"Cannot get heuristic type from %@",functionInfo];
	return typeString;
}

- (void)resolveSelectorUncertainties
{
	if (![functionInfo objectForKey:@"Method"] || [[functionInfo objectForKey:@"Method"] count]<=1)
		return;
		
	// this uses heuristics to resolve selector uncertainties	
	if ([[functionInfo objectForKey:@"Class"] count]!=[[functionInfo objectForKey:@"Method"] count])
		[NSException raise:@"NSNotImplemented" format:@"Cannot handle uncertain method!=class %@",functionInfo];
	
	id objectValue = [functionInfo objectForKey:@"ObjectValue"];
	if ([objectValue isKindOfClass:[CDFunctionCall class]])
	{
		NSString* heurType = [(CDFunctionCall*)objectValue heuristicType];
		if (!heurType)
			[NSException raise:@"NSNotImplemented" format:@"Cannot handle null heuristic type %@",functionInfo];
		int i;
		BOOL foundObject=NO;
		for (i=0;i<[[functionInfo objectForKey:@"Class"] count];i++)
			if ([[[functionInfo objectForKey:@"Class"] objectAtIndex:i] attributeForName:@"name"] && [[[[[functionInfo objectForKey:@"Class"] objectAtIndex:i] attributeForName:@"name"] stringValue] isEqualToString:heurType])
			{
				foundObject=YES;
				break;
			}
		if (!foundObject)
			[NSException raise:@"NSNotImplemented" format:@"Cannot handle unfound heuristic %@ in %@",heurType,functionInfo];
		[functionInfo setValue:[NSArray arrayWithObject:[[functionInfo objectForKey:@"Class"] objectAtIndex:i]] forKey:@"Class"];
		[functionInfo setValue:[NSArray arrayWithObject:[[functionInfo objectForKey:@"Method"] objectAtIndex:i]] forKey:@"Method"];
	}
	else if ([functionInfo objectForKey:@"ObjectTypeName"])
	{
		int i = 0;
		NSString* checkClass = [functionInfo objectForKey:@"ObjectTypeName"];
		BOOL foundObject=NO;
		NSLog(@"check class %@",checkClass);
		while (checkClass && !foundObject)
		{
			foundObject=NO;
			for (i=0;i<[[functionInfo objectForKey:@"Class"] count];i++)
			{
				NSLog(@"checking %@ = %@",[[[[functionInfo objectForKey:@"Class"] objectAtIndex:i] attributeForName:@"name"] stringValue],checkClass);
				if ([[[functionInfo objectForKey:@"Class"] objectAtIndex:i] attributeForName:@"name"] && [[[[[functionInfo objectForKey:@"Class"] objectAtIndex:i] attributeForName:@"name"] stringValue] isEqualToString:checkClass])
				{
					foundObject=YES;
					break;
				}
			}
			if (!foundObject)
				// get subclass of check class
				checkClass = [[classDump lookupTable] subclassOf:checkClass];
		}
		if (!foundObject)
			[NSException raise:@"NSNotImplemented" format:@"Cannot handle unfound object type %@ in %@",[functionInfo objectForKey:@"ObjectTypeName"],functionInfo];
		[functionInfo setValue:[NSArray arrayWithObject:[[functionInfo objectForKey:@"Class"] objectAtIndex:i]] forKey:@"Class"];
		[functionInfo setValue:[NSArray arrayWithObject:[[functionInfo objectForKey:@"Method"] objectAtIndex:i]] forKey:@"Method"];	
		NSLog(@"functionInfo %@",functionInfo);
	}
	else
		[NSException raise:@"NSNotImplemented" format:@"Cannot find type for object %@",objectValue];	
}

- (void)findArgsInState:(NSMutableDictionary*)state
{
	//NSLog(@"find args for %@",functionInfo);
	[functionInfo setValue:[NSMutableArray array] forKey:@"Arguments"];
	
	if (![functionInfo objectForKey:@"FunctionElement"] && !([functionInfo objectForKey:@"Method"] && [[functionInfo objectForKey:@"Method"] count]==1) && ![functionInfo objectForKey:@"SelectorMethod"])
		[NSException raise:@"NSNotImplemented" format:@"Function Element or Method not found: %@",functionInfo];
	if (![functionInfo objectForKey:@"ArgStart"])
		[NSException raise:@"NSNotImplemented" format:@"ArgStart not found: %@",functionInfo];

	NSArray* argElementArray=nil;
	if ([functionInfo objectForKey:@"FunctionElement"])
		argElementArray=[[functionInfo valueForKey:@"FunctionElement"] elementsForName:@"arg"];		
	else if ([functionInfo objectForKey:@"Method"] && [[functionInfo objectForKey:@"Method"] count])
		argElementArray=[[[functionInfo valueForKey:@"Method"] objectAtIndex:0] elementsForName:@"arg"];	
	else if ([functionInfo objectForKey:@"SelectorMethod"]) {
		CDTypeFormatter* aParser = [[CDTypeFormatter alloc] init];
		NSArray* typeArray = [aParser methodArgs:[(CDOCMethod*)[functionInfo objectForKey:@"SelectorMethod"] name] type:[(CDOCMethod*)[functionInfo objectForKey:@"SelectorMethod"] type]];
		if ([typeArray count]) {
			NSLog(@"types %@", typeArray);
			[NSException raise:@"NSNotImplemented" format:@"Cannot handle arguments of %@",typeArray];
		}
		return;
	}
		
	int stackOffset = [[functionInfo valueForKey:@"ArgStart"] intValue];
	for (NSXMLElement* arg in argElementArray)
	{
		NSLog(@"processing arg %@",arg);
		
		id argValue = [[state objectForKey:@"stack"] valueAtIndex:[state objectForKey:@"%esp"] withOffset:stackOffset++];
		if (!argValue) [NSException raise:@"NSNotImplemented" format:@"Cannot handle NULL arg: %@",functionInfo];
		
		if ([arg attributeForName:@"type"]) {
			NSString* argName = [[arg attributeForName:@"declared_type"] stringValue];
			// handle NSString arguments
			if ([argName isEqualToString:@"NSString*"])
			{
				NSString* argString=nil;
				if ([argValue isKindOfClass:[CDRegVal class]] && ((CDRegVal*)argValue).data)
				{
					char** pointerPtr = (char**)[mach pointerFromVMAddr:((CDRegVal*)argValue).value+8];
					if (!pointerPtr) [NSException raise:@"NSNotImplemented" format:@"Cannot process NSString pointer arg in %@",arg];

					char* dataPtr = (char*)[mach pointerFromVMAddr:(unsigned int)*pointerPtr];
					if (!dataPtr) [NSException raise:@"NSNotImplemented" format:@"Cannot process NSString pointer arg in %@",arg];
					
					argString = [[NSString alloc] initWithCString:dataPtr encoding:NSASCIIStringEncoding];
				}
				else if ([argValue isKindOfClass:[CDRegVal class]] && ((CDRegVal*)argValue).deref) {
					NSString* symName = [((CDRegVal*)argValue).symbol name];
					if ([symName hasPrefix:@"_"])
						argString = [symName substringFromIndex:1];
					else
						[NSException raise:@"NSNotImplemented" format:@"Cannot symbol deref %@",((CDRegVal*)argValue).symbol];
				}
				else
					[NSException raise:@"NSNotImplemented" format:@"Cannot handle non-register string %@",argValue];
				[[functionInfo objectForKey:@"Arguments"] addObject:argString];
			}
			else if ([argName isEqualToString:@"id"]||[argName isEqualToString:@"void*"])
			{
				if ([argValue isKindOfClass:[CDRegVal class]] && ((CDRegVal*)argValue).data)
				{
					CDSymbol* foundSym = [symbolTable findByOffset:((CDRegVal*)argValue).value];
					if (((CDRegVal*)argValue).value && foundSym) 
					{
						[[functionInfo objectForKey:@"Arguments"] addObject:foundSym];
					}
					else if (((CDRegVal*)argValue).value)
					{
						// handles NSString possibility
						char** pointerPtr = (char**)[mach pointerFromVMAddr:((CDRegVal*)argValue).value+8];
						unsigned int* lenPtr = (unsigned int*)[mach pointerFromVMAddr:((CDRegVal*)argValue).value+12];
						if (pointerPtr && lenPtr)
						{
							char* dataPtr = (char*)[mach pointerFromVMAddr:(unsigned int)*pointerPtr];
							unsigned int len = *lenPtr;
							if (dataPtr && len)
							{
								NSString* argString = [[NSString alloc] initWithCString:dataPtr encoding:NSASCIIStringEncoding];
								if ([argString length]==len)
									[[functionInfo objectForKey:@"Arguments"] addObject:argString];
								else
									[[functionInfo objectForKey:@"Arguments"] addObject:argValue];
							}
							else
								[[functionInfo objectForKey:@"Arguments"] addObject:argValue];
						}
						else
							[[functionInfo objectForKey:@"Arguments"] addObject:argValue];
					}
					else
						[[functionInfo objectForKey:@"Arguments"] addObject:argValue];
				}
				else if ([argValue isKindOfClass:[CDRegVal class]] && [argValue isSelf])
					[[functionInfo objectForKey:@"Arguments"] addObject:argValue];
				else
					[NSException raise:@"NSNotImplemented" format:@"Cannot handle non-register argument of type id %@",argValue];
			}
			else if ([argName isEqualToString:@"SEL"])
			{
				NSString* argString=nil;
				if ([argValue isKindOfClass:[CDRegVal class]] && ((CDRegVal*)argValue).data)
				{
					char* charPtr = (char*)[mach pointerFromVMAddr:((CDRegVal*)argValue).value];
					if (!charPtr)
						[NSException raise:@"NSNotImplemented" format:@"Cannot process selector arg in %@",arg];
					argString = [[NSString alloc] initWithCString:charPtr encoding:NSASCIIStringEncoding];
				}
				else
					[NSException raise:@"NSNotImplemented" format:@"Cannot handle non-register selectors"];
				[[functionInfo objectForKey:@"Arguments"] addObject:argString];
			}
			else if ([argName isEqualToString:@"BOOL"]) {
				[[functionInfo objectForKey:@"Arguments"] addObject:[NSNumber numberWithBool:((CDRegVal*)argValue).value]];
			}
			else if ([argName isEqualToString:@"NSRect"])
			{
				id argValue2 = [[state objectForKey:@"stack"] valueAtIndex:[state objectForKey:@"%esp"] withOffset:stackOffset++];
				if (!argValue2) 
					[NSException raise:@"NSNotImplemented" format:@"Cannot handle NULL arg: %@",functionInfo];
				id argValue3 = [[state objectForKey:@"stack"] valueAtIndex:[state objectForKey:@"%esp"] withOffset:stackOffset++];
				if (!argValue3) 
					[NSException raise:@"NSNotImplemented" format:@"Cannot handle NULL arg: %@",functionInfo];
				id argValue4 = [[state objectForKey:@"stack"] valueAtIndex:[state objectForKey:@"%esp"] withOffset:stackOffset++];
				if (!argValue4) 
					[NSException raise:@"NSNotImplemented" format:@"Cannot handle NULL arg: %@",functionInfo];
				[[functionInfo objectForKey:@"Arguments"] addObject:[NSArray arrayWithObjects:argValue,argValue2,argValue3,argValue4,nil]];
			}
			else
				[NSException raise:@"NSNotImplemented" format:@"Cannot handle argument of type '%@' in arg %@",argName,arg];
		}
		else
			[[functionInfo objectForKey:@"Arguments"] addObject:argValue];
	}
	
	NSLog(@"%@",[functionInfo objectForKey:@"Arguments"]);
	//exit(0);
/*
	if ([functionElement attributeForName:@"variadic"] && [[[functionElement attributeForName:@"variadic"] stringValue] isEqualToString:@"true"])
	{}
	else
		[NSException raise:@"NSNotImplemented" format:@"Not implemented static arg function"];
*/		
}

- (void)handleSelectorWithState:(NSMutableDictionary*)state lookupTable:(CDHeaderIndex*)lookup
{
	id objectValue=nil;
	id selectorValue=nil;
	if ([[[functionInfo objectForKey:@"FunctionSymbol"] name] isEqualToString:@"_objc_msgSend"])
	{
		objectValue = [[state objectForKey:@"stack"] valueAtIndex:[state objectForKey:@"%esp"] withOffset:0];
		if (objectValue) [functionInfo setValue:objectValue forKey:@"ObjectValue"];

		selectorValue = [[state objectForKey:@"stack"] valueAtIndex:[state objectForKey:@"%esp"] withOffset:1];
		if (selectorValue) [functionInfo setValue:selectorValue forKey:@"SelectorValue"];
		
		[functionInfo setValue:[NSNumber numberWithInt:2] forKey:@"ArgStart"];
	}
	else if ([[[functionInfo objectForKey:@"FunctionSymbol"] name] isEqualToString:@"_objc_msgSend_stret"])
	{
		objectValue = [[state objectForKey:@"stack"] valueAtIndex:[state objectForKey:@"%esp"] withOffset:1];
		if (objectValue) [functionInfo setValue:objectValue forKey:@"ObjectValue"];

		selectorValue = [[state objectForKey:@"stack"] valueAtIndex:[state objectForKey:@"%esp"] withOffset:2];
		if (selectorValue) [functionInfo setValue:selectorValue forKey:@"SelectorValue"];
		
		id returnLocation = [[state objectForKey:@"stack"] popObject];
		NSLog(@"Return location %@",returnLocation);
		if (returnLocation) [functionInfo setValue:returnLocation forKey:@"ReturnLocation"];
		
		[functionInfo setValue:[NSNumber numberWithInt:3] forKey:@"ArgStart"];
	}	
	else if ([[[functionInfo objectForKey:@"FunctionSymbol"] name] isEqualToString:@"_objc_msgSendSuper"])
	{
		id objectPointer = [[state objectForKey:@"stack"] valueAtIndex:[state objectForKey:@"%esp"] withOffset:0];
		if (!objectPointer || ![objectPointer isKindOfClass:[NSNumber class]])
			[NSException raise:@"NSNotImplemented" format:@"Cannot handle call to super with struct %@",objectPointer];
		
		objectValue = [[state objectForKey:@"stack"] valueAtIndex:objectPointer withOffset:0];
		if (objectValue) [functionInfo setValue:objectValue forKey:@"ObjectValue"];
		id objectType = [[state objectForKey:@"stack"] valueAtIndex:objectPointer withOffset:1];
		if (objectType) [functionInfo setValue:objectType forKey:@"ObjectType"];

		selectorValue = [[state objectForKey:@"stack"] valueAtIndex:[state objectForKey:@"%esp"] withOffset:1];
		if (selectorValue) [functionInfo setValue:selectorValue forKey:@"SelectorValue"];
		
		[functionInfo setValue:[NSNumber numberWithInt:2] forKey:@"ArgStart"];
	}	
	else
		[NSException raise:@"NSNotImplemented" format:@"Handling symbol %@ with state %@",[functionInfo objectForKey:@"FunctionSymbol"],state];
		
	if ([selectorValue isKindOfClass:[CDRegVal class]] && [(CDRegVal*)selectorValue data])
	{
		unsigned long selPtr = (unsigned long)[(CDRegVal*)selectorValue value];
		CDSymbol* foundSym = [symbolTable findByOffset:selPtr];
		if (foundSym) [functionInfo setValue:foundSym forKey:@"SelectorSymbol"];
		
		char* dataPtr = (char*)[mach pointerFromVMAddr:selPtr];
		NSString* selectorString;
		if (dataPtr==NULL)
			[NSException raise:@"NSNotImplemented" format:@"Cannot init selector with invalid pointer: %@",selectorValue];
		else
			selectorString = [[NSString alloc] initWithCString:dataPtr encoding:NSASCIIStringEncoding];
		if (selectorString) [functionInfo setValue:selectorString forKey:@"SelectorName"];				
	}
	else
		[NSException raise:@"NSNotImplemented" format:@"Can't handle selector value %@",selectorValue];		
		
	if ([objectValue isKindOfClass:[CDRegVal class]] && [(CDRegVal*)objectValue data])
	{
		unsigned long objPtr = (unsigned long)[(CDRegVal*)objectValue value];
		CDSymbol* foundSym = [symbolTable findByOffset:objPtr];
		if (foundSym) [functionInfo setValue:foundSym forKey:@"ObjectSymbol"];
		
		char* dataPtr = (char*)[mach pointerFromVMAddr:objPtr];
		NSString* classString=nil;
		if (dataPtr==NULL)
			[NSException raise:@"NSNotImplemented" format:@"Cannot init object with invalid pointer: %@",objectValue];
		else
			classString = [[NSString alloc] initWithCString:dataPtr encoding:NSASCIIStringEncoding];
		if (classString) [functionInfo setValue:classString forKey:@"ObjectName"];
	}
	else if ([objectValue isKindOfClass:[CDRegVal class]] && [(CDRegVal*)objectValue isSelf] && ![functionInfo objectForKey:@"ObjectType"])
	{
		[functionInfo setValue:class forKey:@"ObjectClass"];
		BOOL foundMethod=NO;
		for (CDOCMethod* imethod in [class instanceMethods])
			if ([[imethod name] isEqualToString:[functionInfo objectForKey:@"SelectorName"]])
			{
				foundMethod=YES;
				[functionInfo setValue:imethod forKey:@"SelectorMethod"];
				break;
			}
		if (!foundMethod)
		{
			NSString* curClassName = [class superClassName];
			// look in local classes
			for (CDOCClass* localClass in [classDump allclasses])
				if ([[localClass name] isEqualToString:curClassName])
					[NSException raise:@"NSNotImplemented" format:@"Local class selectors not supported"];
		}
	}
	else if ([objectValue isKindOfClass:[CDRegVal class]] && [(CDRegVal*)objectValue isSelf] && [functionInfo objectForKey:@"ObjectType"])
	{
		[functionInfo setValue:class forKey:@"ObjectClass"];
        NSLog(@"***** WARNING!!!! WE ARE IN AN AREA THAT NEEDS TO BE FIXED! (CDFunctionCall / handleSelectorWithState) *****");
#pragma mark - NEED TO FIX!!! GET THE TYPE AND CAST IT
		//unsigned long typePtr = (unsigned long)[[functionInfo objectForKey:@"ObjectType"] value];		
		char* dataPtr = (char*)[mach pointerFromVMAddr:typePtr];
		NSString* typeString;
		if (dataPtr==NULL)
			[NSException raise:@"NSNotImplemented" format:@"Cannot init object type with invalid pointer: %@",[functionInfo objectForKey:@"ObjectType"]];
		else
			typeString = [[NSString alloc] initWithCString:dataPtr encoding:NSASCIIStringEncoding];
		if (typeString) [functionInfo setValue:typeString forKey:@"ObjectTypeName"];				
	}	
	else if (![objectValue isKindOfClass:[CDFunctionCall class]] && ![objectValue isKindOfClass:[CDRegVal class]])
		[NSException raise:@"NSNotImplemented" format:@"Can't handle object value %@",objectValue];
		
	NSLog(@"selector info %@",functionInfo);
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"%@", functionInfo];
}

@end
