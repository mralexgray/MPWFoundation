//
//  MPWSmallStringTable.m
//  MPWFoundation
//
//  Created by Marcel Weiher on 29/3/07.
//  Copyright 2007-2012 by Marcel Weiher. All rights reserved.
//

#import "MPWSmallStringTable.h"
#import "DebugMacros.h"
#if FULL_MPWFOUNDATION && !WINDOWS && !LINUX
#import "MPWRusage.h"
#endif

@implementation MPWSmallStringTable

idAccessor( defaultValue, setDefaultValue )

#if GATHER_STATISTICS
static int numKeys=0;
static int keyBytes=0;
static int maxLen=0;
static int sizes[256];
static id allkeys=nil;
#endif

IMP __stringTableLookupFun=NULL;

+(void)inititialize
{
	[MPWObject initialize];
}

+(void)printStats
{
#if GATHER_STATISTICS
	int i;
	int cumulative=0;
	NSLog(@"keys: %d length: %d avg. size: %g max size=%d",numKeys,keyBytes,keyBytes/(double)numKeys);
	for ( i=0;i<maxLen;i++ ) {
		cumulative+=sizes[i];
		NSLog(@"%d -> %d  %d%% of total, cumulative %d%%",i,sizes[i],(sizes[i]*100)/numKeys,(cumulative*100)/numKeys);
	}
	NSLog(@"%d distinct keys (%d%%)",[allkeys count],(100*[allkeys count])/numKeys);
	NSLog(@"allKeys: %@",[[allkeys allObjects] sortedArrayUsingSelector:@selector(compare:)]); 
#endif	
}

-initWithObjects:(id*)values forKeys:(id*)keys count:(NSUInteger)count
{
//	NSLog(@"%p initWithObjects:forKeys:count: %d --- ",self,count);
//	NSLog(@"will super init");
    int encoding=NSUTF8StringEncoding;
#if WINDOWS
    encoding=NSISOLatin1StringEncoding;
#endif
    
#ifndef WINDOWS
	self=[super init];
#endif
	if ( self ) {
		int i;
		int lengths[ count +1 ];
        maxLen=0;
        NSAssert2(count<255, @"%@ - total number of strings %d > 255", [self class], count);

		int totalStringLen=0;
		unsigned char *curptr;
//		NSLog(@"super init");
		for (i=0;i<count;i++) {
            int thisLength=[keys[i] lengthOfBytesUsingEncoding:encoding];
			lengths[i]=thisLength;
			totalStringLen+=thisLength+3;
            NSAssert3(thisLength<255, @"%@ - length of string '%@' %d > 255", [self class], keys[i], thisLength);
            if (thisLength>maxLen ) {
                maxLen=thisLength;
            }
		}
//        NSLog(@"totalLen=%d maxLen=%d",totalStringLen,maxLen);
        int stringsOfLen[ maxLen + 2];
        bzero(stringsOfLen, sizeof(int) * maxLen );
        chainStarts=calloc( maxLen+2, sizeof(int));
        tableOffsetsPerLength=calloc( maxLen+2, sizeof(int));
		tableLength=count;
		table=malloc( totalStringLen +1 );
        tableIndex=calloc( count + 1, sizeof(StringTableIndex));
        for (int i=0;i<=maxLen;i++) {
            chainStarts[i]=-1;
        }
		tableValues=calloc( (count+5),  sizeof(id) );
//		NSLog(@"tableValues=%p",tableValues);
//		memcpy( tableValues, values, count * sizeof(id));
		curptr=table;
//		NSLog(@"table=%p curptr=%p",table,curptr);
        
		for (i=0;i<tableLength;i++) {\
			int len=lengths[i];
            tableIndex[i].length=len;
            tableIndex[i].index=i;
            tableIndex[i].next=chainStarts[len];
            chainStarts[len]=i;
//            NSLog(@"setup tableIndex[%d], len=%d",i,len);
        }
        
        //--- gather lengths
        
        for (i=0;i<=maxLen;i++) {
            int curIndex=chainStarts[i];
//            NSLog(@"len[%d], start=%d",i,curIndex);
            int number=0;
            while (curIndex>=0) {
                curIndex=tableIndex[curIndex].next;
                number++;
            }
            stringsOfLen[i]=number;
            if ( number) {
//                NSLog(@"strings of length %d: %d",i,number);
            }
        }
    
        //---- write the table in ascending order of lengths
        
#if 1
        for (i=0;i<=maxLen;i++) {
            if ( stringsOfLen[i]>0) {
 //               NSLog(@"%d strings of length %d",stringsOfLen[i], i);
                tableOffsetsPerLength[i]=curptr-table;
                *curptr++ = i;
                *curptr++ = stringsOfLen[i];
                int curIndex=chainStarts[i];
                while (curIndex>=0) {
                    
                    int theIndex = tableIndex[curIndex].index;
                    int len=lengths[theIndex];
                    NSString* key=keys[theIndex];
//                  NSLog(@"add string: %@",key);
//                    NSLog(@"theIndex: %d",theIndex);
                    if ( theIndex > tableLength){
                        NSLog(@"===index %d outside of table",theIndex);
                    }
                    *curptr++=theIndex;   // store the key's index
                    [key getCString:(char*)curptr maxLength:len+1 encoding:encoding];
                    tableIndex[curIndex].offset=curptr-table;
                    
                    
//                    NSLog(@"retain value[%d]: %p/%@ (of %d)",theIndex,values[theIndex],values[theIndex],tableLength);
                    tableValues[theIndex]=[values[theIndex] retain];
                    curptr+=len;

                    curIndex=tableIndex[curIndex].next;
                }
            } else {
                tableOffsetsPerLength[i]=-1;

            }
        }
//        NSLog(@"curptr: %p table: %p used length: %d",curptr,table,curptr-table);
      

#else
        
        
		for (i=0;i<tableLength;i++) {
			NSString* key=keys[i];
			int len=lengths[i];
			id value=values[i];
            
			*curptr++=len;
            *curptr++=1;            //  number of entries of this length
            *curptr++=i;
            tableIndex[i].offset=curptr-table;
			tableValues[i]=[value retain];
			[key getCString:curptr maxLength:len+1 encoding:encoding];
			curptr+=len;
//			table[i].offset=0;
			
			
#if GATHER_STATISTICS
			numKeys++;
			sizes[len]++;
			keyBytes+=table[i].length;
			if ( len > maxLen ) {
				maxLen=len;
			}
			if ( !allkeys ) {
				allkeys=[[NSMutableSet set] retain];
			}
			[allkeys addObject:key];
#endif			
		}
#endif
		if ( !__stringTableLookupFun ) {
			__stringTableLookupFun=[self methodForSelector:@selector(objectForCString:length:)];
		}
		[self setDefaultValue:nil];
	}
//   NSLog(@"returning initialized MPWSmallStringTable: %p",self);
//    NSLog(@"returning initialized MPWSmallStringTable: %@",[self class]);
//    NSLog(@"returning initialized MPWSmallStringTable: %@",self);
    
	return self;

}

-initWithKeys:(NSArray*)keys values:(NSArray*)values
{
//	NSLog(@"initWithKeys: %d values: %d",[keys count],[values count]);
    int keyCount = [keys count];
	id keyArray[ keyCount +1 ];
	id valueArray[ [values count] + 1];
    NSAssert2([keys count]==[values count], @"different numbers of keys and values", [keys count], [values count]);
    [keys getObjects:keyArray];
    [values getObjects:valueArray];
//    NSLog(@"keys: %@",keys);
//	NSLog(@"will initWithObjects:forKeys:count");
	return [self initWithObjects:valueArray forKeys:keyArray count:[keys count]];
}

-(NSUInteger)count
{
	return tableLength;
}

-objectForKey:(NSString*)key
{
    if ( tableLength ) {
        int encoding=NSUTF8StringEncoding;
#if WINDOWS
        encoding=NSISOLatin1StringEncoding;
#endif
        int len=[key lengthOfBytesUsingEncoding:encoding];
        char buffer[len+20];
        [key getCString:buffer maxLength:len+10 encoding:encoding];
        buffer[len]=0;
        return [self objectForCString:buffer length:len];
    } else {
        return defaultValue;
    }
}

-objectAtIndex:(NSUInteger)anIndex
{
	if ( anIndex < tableLength ) {
		return tableValues[anIndex];
	} else {
		return nil;
	}
}

- (void)replaceObjectAtIndex:(NSUInteger)anIndex withObject:(id)anObject
{
	if (  anIndex < tableLength ) {
		[anObject retain];
		[tableValues[anIndex] release];
		tableValues[anIndex]=anObject;
	} else {
		[NSException raise:@"indexOutOfBounds" format:@"index %d out bounds",(int)anIndex];
	}
}

-keyAtIndex:(NSUInteger)anIndex
{
	if ( anIndex < tableLength ) {
        for (int i=0; i<tableLength;i++) {
            if ( tableIndex[i].index == anIndex) {
                return [[[NSString alloc] initWithBytes:table + tableIndex[i].offset length:tableIndex[i].length encoding:NSUTF8StringEncoding] autorelease];
            }
        }
	}
    return nil;
}

static inline int offsetOfCStringWithLengthInTableOfLength( const unsigned char  *table, int *tableOffsets, const char *cstr, NSUInteger len, int *chainStarts, StringTableIndex *tableIndex)
{
#if 1
    if (  tableOffsets[len] >= 0 )  {
        int i;
        const unsigned char *curptr=table+tableOffsets[len];
        for (i=0; i<1;i++ ) {
            int entryLen=*curptr++;
            int numEntries=*curptr++;
//            NSLog(@"len: %d entryLen: %d",len,entryLen);
            if ( len==entryLen ) {
                int offset=entryLen-1;
                for (int  j=0;j<numEntries;j++) {
                    int index=*curptr++;
                    const unsigned char *tablestring=curptr;
//                    NSLog(@"'%.*s' = '%.*s' ?",len,cstr,entryLen,tablestring);
                    if ( (cstr[offset])==(tablestring[offset]) ) {
                        int j;
                        BOOL matches=YES;
                        for ( j=0;j<len-1;j++) {
                            if ( cstr[j] != tablestring[j] ) {
                                matches=NO;
                                break;
                            }
                        }
                        if ( matches ){
//                            NSLog(@"return index: %d",index);
                            return index;
                        }
                    }
                    curptr+=entryLen;
                }
            } else {
                curptr+=(entryLen+1)*numEntries;
            }
        }
    }
#else
//    else
    {
        int currentIndex=chainStarts[len];
        while ( currentIndex >= 0 ) {
            StringTableIndex *cur=tableIndex+currentIndex;
            int firstCheckOffset=len-1;
            const char *tablePtr=table + cur->offset;
            if ( cstr[firstCheckOffset] == tablePtr[firstCheckOffset]) {
                BOOL matches=YES;
                for (int i=0;i<len;i++) {
                    if ( cstr[i] != tablePtr[i] ) {
                        matches=NO;
                        break;
                    }
                }
                if ( matches) {
                    return cur->index;
                }
            }
            currentIndex=cur->next;
        }
    }
#endif
    return -1;
}

-(int)offsetForCString:(const char*)cstr length:(int)len
{
    if ( len <= maxLen && tableLength>0) {
        int offset = offsetOfCStringWithLengthInTableOfLength( table , tableOffsetsPerLength, cstr, len , chainStarts, tableIndex);
        return offset;
    } else {
        return -1;
    }
}

-(int)offsetForCString:(const char*)cstr
{
	return [self offsetForCString:cstr length:strlen(cstr)];
}

-(void)setObject:anObject forKey:aKey
{
	const char *str=[aKey UTF8String];
	int offset=[self offsetForCString:str];
	if ( offset >= 0 ) {
		[self replaceObjectAtIndex:offset  withObject:anObject];
	} else {
		[NSException raise:@"setObjectForKey-nokey" format:@"key %@ not already present in dict",aKey];
	}
}


-objectForCString:(const char*)cstr length:(int)len
{
    int offset=-1;
    if ( len <= maxLen && tableLength ) {
        offset = offsetOfCStringWithLengthInTableOfLength( table , tableOffsetsPerLength, cstr, len, chainStarts, tableIndex );
    }
	if ( offset >= 0 ) {
		return tableValues[offset];
	} else {
		return defaultValue;
	}
}
-objectForCString:(const char*)cstr
{
	return [self objectForCString:cstr length:strlen(cstr)];
}

-description
{
	int i;

	id result=[NSMutableString stringWithString:@"{ "];
	for (i=0;i<tableLength;i++) {
		[result appendFormat:@"%@=%@;\n",[self keyAtIndex:i],[self objectAtIndex:i]];
	}
	[result appendFormat:@" }\n"];
	return result;
}

- retain
{
    return retainMPWObject( (MPWObject*)self );
}

- (NSUInteger)retainCount
{
    return __retainCount+1;
}

- (oneway void)release
{
    releaseMPWObject((MPWObject*)self);
}

-(NSArray*)allKeys
{
    NSMutableArray *result=[NSMutableArray arrayWithCapacity:[self count]];
    for (int i=0;i<[self count];i++) {
        NSString *key=[self keyAtIndex:i];
//        NSLog(@"key[%d]='%@'",i,key);
        [result addObject:key];
    }
    return result;
}

-(NSEnumerator *)keyEnumerator
{
    return [[self allKeys] objectEnumerator];
}
int _small_string_table_releaseIndex=0;

-(void)dealloc
{
//    NSLog(@"dealloc %p",self);
	if ( tableValues ) {
		int i;
		for (i=0;i<tableLength;i++) {
//            fprintf(stderr,"release value %d of %d\n",i,tableLength);
            _small_string_table_releaseIndex=i;
//            NSLog(@"release ptr %p",tableValues[i]);
//            NSLog(@"release value %@",tableValues[i]);
			[tableValues[i] release];
//            NSLog(@"did release %d",i);
		}
		free(tableValues);
        tableValues=NULL;
	}
	if ( table ) {
		free(table);
        table=NULL;
	}
	[defaultValue release];
	[super dealloc];
}

@end


@implementation MPWSmallStringTable(testing)

+_testKeys
{
	return [NSArray arrayWithObjects:@"Help", @"Marcel", @"me", @"Manuel",  nil];
}

+_testValues
{
	return [NSArray arrayWithObjects:@"Value for Help", @"Value 2", @"myself and I", @"Imposter", nil];
}

+_testCreateTestTable
{
	NSArray *keys=[self _testKeys];
	NSArray *values=[self _testValues];
	MPWSmallStringTable *table=[[[self alloc] initWithKeys:keys values:values ] autorelease];
	return table;
}

+(void)testSimpleCStringLookup
{
	MPWSmallStringTable *table=[self _testCreateTestTable];
	NSArray *values=[self _testValues];
	IDEXPECT( [table objectForCString:"Help"] , [values objectAtIndex:0], @"first lookup" );
	IDEXPECT( [table objectForCString:"Marcel"] , [values objectAtIndex:1], @"second lookup" );
	IDEXPECT( [table objectForCString:"me"] , [values objectAtIndex:2], @"third lookup" );
}

+(void)testSimpleNSStringLookup
{
	MPWSmallStringTable *table=[self _testCreateTestTable];
	NSArray *values=[self _testValues];
	IDEXPECT( [table objectForKey:@"Help"] , [values objectAtIndex:0], @"first lookup" );
	IDEXPECT( [table objectForKey:@"Marcel"] , [values objectAtIndex:1], @"second lookup" );
	IDEXPECT( [table objectForKey:@"me"] , [values objectAtIndex:2], @"third lookup" );
}

+(void)testSimpleCStringLengthLookup
{
	MPWSmallStringTable *table=[self _testCreateTestTable];
	NSArray *values=[self _testValues];
	IDEXPECT( [table objectForCString:"Help" length:4] , [values objectAtIndex:0], @"first lookup" );
	IDEXPECT( [table objectForCString:"Marcel" length:6] , [values objectAtIndex:1], @"second lookup" );
	IDEXPECT( [table objectForCString:"me"  length:2] , [values objectAtIndex:2], @"third lookup" );
}

+(void)testLookupOfNonExistingKey
{
	MPWSmallStringTable *table=[self _testCreateTestTable];
	IDEXPECT( [table objectForKey:@"bozo"], nil, @"non-existing key");
}

+(void)testLookupViaMacro
{
	MPWSmallStringTable *table=[self _testCreateTestTable];
	NSArray *values=[self _testValues];
	IDEXPECT( OBJECTFORCONSTANTSTRING(table,"Marcel"), [values objectAtIndex:1], @"lookup via macro");
}

+(void)testKeyAtIndex
{
	MPWSmallStringTable *table=[self _testCreateTestTable];
	
	IDEXPECT( [table keyAtIndex:0] , @"Help", @"key access");
	IDEXPECT( [table keyAtIndex:1] , @"Marcel", @"key access");
	IDEXPECT( [table keyAtIndex:2] , @"me", @"key access");
}

#define LOOKUP_COUNT 10000
#if FULL_MPWFOUNDATION && !WINDOWS && !LINUX

+(void)testLookupFasterThanNSDictionary
{
	MPWSmallStringTable *table=[self _testCreateTestTable];
	NSDictionary *dict=[NSDictionary dictionaryWithObjects:[self _testValues] forKeys:[self _testKeys]];
	int i;
#define CKEY  "me"
    NSString *nskey=[NSString stringWithUTF8String:CKEY];
    NSLog(@"nskey class: %@",[nskey class]);
    
    MPWRusage* slowerStart=[MPWRusage current];
	for (i=0;i<LOOKUP_COUNT;i++) {
		[dict objectForKey:nskey];
	}
	MPWRusage* slowerTime=[MPWRusage timeRelativeTo:slowerStart];
    
    nskey=@CKEY;
    MPWRusage* slowStart=[MPWRusage current];
	for (i=0;i<LOOKUP_COUNT;i++) {
		[dict objectForKey:nskey];
	}
	MPWRusage* slowTime=[MPWRusage timeRelativeTo:slowStart];
 
    
    MPWRusage* fastStart=[MPWRusage current];
	for (i=0;i<LOOKUP_COUNT;i++) {
		OBJECTFORCONSTANTSTRING(table,CKEY);
	}
	MPWRusage* fastTime=[MPWRusage timeRelativeTo:fastStart];
    

   
	
    double ratio = (double)[slowTime absoluteMicroseconds] / (double)[fastTime absoluteMicroseconds];
    double ratio1 = (double)[slowerTime absoluteMicroseconds] / (double)[fastTime absoluteMicroseconds];
	NSLog(@"dict with string time:  %d (%g ns/iter) dict with constant string time: %d (%g ns/iter) stringtable time: %d (%g ns/iter)",[slowerTime absoluteMicroseconds],(1000.0*[slowerTime absoluteMicroseconds])/LOOKUP_COUNT,[slowTime absoluteMicroseconds],(1000.0*[slowTime absoluteMicroseconds])/LOOKUP_COUNT,[fastTime absoluteMicroseconds],(1000.0*[fastTime absoluteMicroseconds])/LOOKUP_COUNT);
	NSLog(@"string table vs dict lookup time ratio: %g  vs. dict with computed key: %g",ratio,ratio1);
#define CONSTANT_STRING_RATIO 2.8
	NSAssert2( ratio > CONSTANT_STRING_RATIO ,@"ratio of small string table to NSDictionary with constant string  %g < %g",
              ratio, CONSTANT_STRING_RATIO );
#define COMPUTED_STRING_RATIO 3.8

	NSAssert2( ratio1 > COMPUTED_STRING_RATIO ,@"ratio of small string table to NSDictionary with computed key %g < %g",
              ratio1, COMPUTED_STRING_RATIO );
}

+(void)testLookupFasterThanMPWUniqueString
{
	MPWSmallStringTable *table=[self _testCreateTestTable];
	MPWRusage* slowStart=[MPWRusage current];
	int i;
	for (i=0;i<LOOKUP_COUNT;i++) {
		MPWUniqueStringWithCString("Marcel", 6);
	}
	MPWRusage* slowTime=[MPWRusage timeRelativeTo:slowStart];
	MPWRusage* fastStart=[MPWRusage current];
	for (i=0;i<LOOKUP_COUNT;i++) {
		OBJECTFORCONSTANTSTRING(table,"Marcel");
	}
	MPWRusage* fastTime=[MPWRusage timeRelativeTo:fastStart];
	double ratio = (double)[slowTime userMicroseconds] / (double)[fastTime userMicroseconds];
	NSLog(@"MPWUniqueString time: %d (%g ns/iter) stringtable time: %d (%g ns/iter)",[slowTime userMicroseconds],(1000.0*[slowTime userMicroseconds])/LOOKUP_COUNT,[fastTime userMicroseconds],(1000.0*[fastTime userMicroseconds])/LOOKUP_COUNT);
	NSLog(@"MPWUniqueString vs. string table lookup time ratio: %g",ratio);
#define RATIO 2.5 
	NSAssert2( ratio > RATIO ,@"ratio of small string table to MPWUniqueString (NSMapTable) %g < %g",
				ratio,RATIO);
}
#endif

+(void)testFailedLookupGetsDefaultValue
{
	MPWSmallStringTable *table=[self _testCreateTestTable];
	char *key="something not in table";
	id defaultResult=@"my default result";
	INTEXPECT(0, [table objectForCString:key] , @"should not have found anything" );
	[table setDefaultValue:defaultResult];
	IDEXPECT(defaultResult, [table objectForCString:key] , @"should have found the default result" );
}

+(void)testOffsetLookup
{
	MPWSmallStringTable *table=[self _testCreateTestTable];

	INTEXPECT( 1, [table offsetForCString:"Marcel"],@"offset of second element" );
	INTEXPECT( 2, [table offsetForCString:"me"],@"offset of third element" );
	INTEXPECT( -1, [table offsetForCString:"myself"],@"offset of element not in table" );
}

+(void)testReplaceObject
{
	MPWSmallStringTable *table=[self _testCreateTestTable];
	INTEXPECT( [table offsetForCString:"Help"], 0,@"offset of first element" );
	IDEXPECT([table objectForKey:@"Help"], @"Value for Help", @"after replacing");
	[table setObject:@"other object" forKey:@"Help"];
	IDEXPECT([table objectForKey:@"Help"], @"other object", @"after replacing");
	[table setObject:@"second object" forKey:@"me"];
	IDEXPECT([table objectForKey:@"me"], @"second object", @"after replacing");
}

+(void)testLongerKeys
{
	NSArray *keys=[NSArray arrayWithObject:@"AudioList"];
	NSArray *values=[NSArray arrayWithObject:@"Value"];
	MPWSmallStringTable *table=[[[self alloc] initWithKeys:keys values:values ] autorelease];
	IDEXPECT([table objectForKey:@"AudioList"], @"Value", @"before replacing");
	[table setObject:@"new" forKey:@"AudioList"];
	IDEXPECT([table objectForKey:@"AudioList"], @"new", @"after replacing");
}

+(void)testActuallyCheckingFullString
{
    MPWSmallStringTable *table=[self _testCreateTestTable];
    IDEXPECT([table objectForKey:@"Manuel"], @"Imposter", @"has same 1st and last char");
}

+(void)testMaxStringLengthEnforced
{
    NSString *s=@"10";
    while ( [s length] < 256 ) {
        s=[s stringByAppendingString:s];
    }
    NSArray *keys=[NSArray arrayWithObject:s];
    @try {
        [[[[self class] alloc] initWithKeys:keys values:keys] autorelease];
        EXPECTFALSE(YES, @"should have raised");
    }
    @catch (NSException *exception) {
    }
}

+(void)testMaxTableSizeEnforced
{
    NSMutableArray *keys=[NSMutableArray array];
    NSString *s=@"10";
    while ( [keys count] < 256 ) {
        [keys addObject:s];
    }
    @try {
        [[[[self class] alloc] initWithKeys:keys values:keys] autorelease];
        EXPECTFALSE(YES, @"should have raised");
    }
    @catch (NSException *exception) {
    }
}

+testSelectors
{
	return [NSArray arrayWithObjects:
			@"testSimpleCStringLookup",
			@"testSimpleNSStringLookup",
			@"testSimpleCStringLengthLookup",
			@"testLookupViaMacro",
#if FULL_MPWFOUNDATION			
			@"testLookupFasterThanNSDictionary",
//			@"testLookupFasterThanMPWUniqueString",
#endif			
			@"testFailedLookupGetsDefaultValue",
			@"testKeyAtIndex",
			@"testOffsetLookup",
			@"testReplaceObject",
			@"testLongerKeys",
			@"testActuallyCheckingFullString",
            @"testMaxStringLengthEnforced",
            @"testMaxTableSizeEnforced",
			nil];
}

@end

