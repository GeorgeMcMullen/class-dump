//
//  CDMemorySimulator.m
//  code-dump
//
//  Created by Braden Thomas on 12/17/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "CDMemorySimulator.h"
#import "CDRegVal.h"

@implementation CDMemorySimulator

- (id) init
{
	self = [super init];
	if (self != nil) {
		memoryRep = [[NSMutableArray alloc] init];
		indexes = [[NSMutableArray alloc] init];
		// represents the %esp stack pointer
		[indexes addObject:[NSNumber numberWithInt:0]];
	}
	return self;
}

- (void) pushObject:(id)object
{
	// insert object before %esp pointer
	[memoryRep insertObject:object atIndex:[[indexes objectAtIndex:0] intValue]];
	
	// adjust all indexes
	NSEnumerator* inEnum = [indexes objectEnumerator];
	NSNumber* index;
	NSMutableArray* newIndexes=[NSMutableArray array];
	for (index=[inEnum nextObject]; index; index=[inEnum nextObject])
		[newIndexes addObject:[NSNumber numberWithInt:([index intValue]+1)]];
	[indexes replaceObjectsInRange:NSMakeRange(0, [indexes count]) withObjectsFromArray:newIndexes];
	// adjust esp
	[indexes replaceObjectAtIndex:0 withObject:[NSNumber numberWithInt:([[indexes objectAtIndex:0] intValue]-1)]];
}

- (id) popObject
{
	id outObject = [memoryRep objectAtIndex:[[indexes objectAtIndex:0] intValue]];
	// adjust esp
	[indexes replaceObjectAtIndex:0 withObject:[NSNumber numberWithInt:([[indexes objectAtIndex:0] intValue]+1)]];

	return outObject;
}


- (id) copyValueForIndex:(int)index
{
	NSNumber* newIndex = [[indexes objectAtIndex:index] copy];
	[indexes addObject:newIndex];
	return [NSNumber numberWithInt:([indexes count]-1)];
}

- (void) offsetIndex:(NSNumber*)index byAmount:(int)amount
{
	int currentValue=[[indexes objectAtIndex:[index intValue]] intValue];
	int futureValue=currentValue+amount;
	if (futureValue < 0)
	{
		int i;
		for (i=0;i<-futureValue;i++)
			[memoryRep insertObject:[[CDRegVal alloc] initWithValue:0] atIndex:0];

		// adjust all indexes
		NSEnumerator* inEnum = [indexes objectEnumerator];
		NSNumber* index2;
		NSMutableArray* newIndexes=[NSMutableArray array];
		for (index2=[inEnum nextObject]; index2; index2=[inEnum nextObject])
			[newIndexes addObject:[NSNumber numberWithInt:([index2 intValue]-futureValue)]];
		[indexes replaceObjectsInRange:NSMakeRange(0, [indexes count]) withObjectsFromArray:newIndexes];
		
		// adjust index in question to 0
		[indexes replaceObjectAtIndex:[index2 intValue] withObject:[NSNumber numberWithInt:0]];
	}
	else if (futureValue > [memoryRep count])
	{
		[NSException raise:@"NSNotImplemented" format:@"Not implemented offset index %@ by %d",index,amount];
	}
	else
	{
		if ([index intValue]>[indexes count] || [index intValue]<0)
			[NSException raise:@"UnexpectedData" format:@"Unexpected index value %@",index];	
			
		[indexes replaceObjectAtIndex:[index intValue] withObject:[NSNumber numberWithInt:futureValue]];
	}
}

- (void) setValueAtIndex:(NSNumber*)index withOffset:(int)offset toValue:(id)object
{
	int currentValue=[[indexes objectAtIndex:[index intValue]] intValue];
	int offsetValue=currentValue+offset;
	if (offsetValue < 0)
	{
		[NSException raise:@"NSNotImplemented" format:@"Not implemented (negative) set value at index %@ offset %d",index,offset];
	}
	else if (offsetValue > [memoryRep count])
	{
		[NSException raise:@"NSNotImplemented" format:@"Not implemented (past end) set value at index %@ offset %d",index,offset];
	}
	else
	{
		[memoryRep replaceObjectAtIndex:offsetValue withObject:object];
	}
}

- (id) valueAtIndex:(NSNumber*)index withOffset:(int)offset
{
	int currentValue=[[indexes objectAtIndex:[index intValue]] intValue];
	int offsetValue=currentValue+offset;
	if (offsetValue < 0)
	{
		[NSException raise:@"NSNotImplemented" format:@"Not implemented (negative) value at index %@ offset %d",index,offset];
	}
	else if (offsetValue > [memoryRep count])
	{
		[NSException raise:@"NSNotImplemented" format:@"Not implemented (past end) value at index %@ offset %d",index,offset];
	}
	else
	{
		return [memoryRep objectAtIndex:offsetValue];
	}
	return nil;
}

- (NSString*) description
{
	return [NSString stringWithFormat:@"%@, %@",memoryRep,indexes];
}

@end
