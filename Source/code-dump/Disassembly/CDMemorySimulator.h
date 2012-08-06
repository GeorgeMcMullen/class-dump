//
//  CDMemorySimulator.h
//  code-dump
//
//  Created by Braden Thomas on 12/17/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface CDMemorySimulator : NSObject {
	NSMutableArray* memoryRep;
	NSMutableArray* indexes;
}
- (void) pushObject:(id)object;
- (id) copyValueForIndex:(int)index;
- (void) offsetIndex:(NSNumber*)index byAmount:(int)amount;
- (id) valueAtIndex:(NSNumber*)ind withOffset:(int)off;
- (void) setValueAtIndex:(NSNumber*)index withOffset:(int)offset toValue:(id)object;
- (id) popObject;
@end
