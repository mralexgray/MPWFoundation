/* NSStringAdditions.m Copyright (c) 1998-2012 by Marcel Weiher, All Rights Reserved.


Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

	Redistributions of source code must retain the above copyright
	notice, this list of conditions and the following disclaimer.

	Redistributions in binary form must reproduce the above copyright
	notice, this list of conditions and the following disclaimer in
	the documentation and/or other materials provided with the distribution.

	Neither the name Marcel Weiher nor the names of contributors may
	be used to endorse or promote products derived from this software
	without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
THE POSSIBILITY OF SUCH DAMAGE.

*/


#import "NSStringAdditions.h"
#import <MPWFoundation/DebugMacros.h>
#import "PhoneGeometry.h"

@implementation NSString(Additions)

-(const void*)bytes
{
/*"
    Make #NSString compatible with #NSData.  Returns #{[self cString]}.
"*/
    return [self UTF8String];
}

-(NSString*)stringValue
/*"
    Return #self.
"*/
{
    return self;
}

-(NSData*)asData
/*"
     Returns my cString-data as a #NSData.
"*/
{
    return [self dataUsingEncoding:NSUTF8StringEncoding];
}


-(NSString*)uniquedByNumberingInPool:(NSSet*)otherStrings
{
    id result=self;
    int number;
    for (number=1; [otherStrings containsObject:result];number++) {
        result=[NSString stringWithFormat:@"%@-%d",self,number];
    }
    return result;
}

-(NSString*)uniquedByNumberingInUpdatingPool:(NSMutableSet*)otherStrings
{
    id result = [self uniquedByNumberingInPool:otherStrings];
    if ( result != self ) {
        [otherStrings addObject:result];
    }
    return result;
}

+(id)stringWithCharacter:(int)theChar
{
    unichar ch=theChar;
    return [self stringWithCharacters:&ch length:1];
}

-(int)numericCompare:other
{
	return [self compare:other options:64];
}

-(int)countOccurencesOfCharacter:(int)c
{
    int count=0,i,len=[self length];
    unichar buf[ len ];
    [self getCharacters:buf];
    for (i=0;i<len;i++) {
        if ( buf[i]==c ) {
            count++;
        }
    }
    return count;
}

-asNumber
{
	if ( [self rangeOfString:@"."].length == 0 ) { 
		return [NSNumber numberWithInt:[self intValue]];
	} else {
		return [NSNumber numberWithFloat:[self floatValue]];
	}
}

#if WINDOWS

-(char*)_fastCStringContents:(BOOL)blah
{
	return NULL;
}

#endif


#define COMPARETYPE(type, encoding)  !strcmp( @encode(typeof(type)),encoding)
#define CONVERT(type,encoding,func,ptr)  if ( COMPARETYPE(type,encoding)) { return func( *(type*)ptr ); }
#define CONVERTSIMPLE( encoded, type, format )  case encoded: return [NSString stringWithFormat:@"##type##",*(type*)any];


NSString *MPWConvertToString( void* any, char *typeencoding ) {
	switch (*typeencoding ) {
		case 'i':
			return [NSString stringWithFormat:@"%d",*(int*)any];
		case 'd':
			return [NSString stringWithFormat:@"%g",*(double*)any];
		case ':':
			return NSStringFromSelector( *(SEL*)any);
		case '@':
			return *(id*)any;
		default:
			CONVERT( NSPoint, typeencoding, NSStringFromPoint, any );
			CONVERT( NSRect, typeencoding, NSStringFromRect, any );
			CONVERT( NSSize, typeencoding, NSStringFromSize, any );
			CONVERT( NSRange, typeencoding, NSStringFromRange, any );
	}
	return [NSString stringWithFormat:@"unknown format %s",typeencoding];
}






@end

@implementation NSNumber(asNumber)

-asNumber	{ return self; }


@end

@interface NSStringAdditionsTesting : NSObject
@end
@implementation NSStringAdditionsTesting

+(void)testOccurencesOf
{
    INTEXPECT( [@"This is a test string" countOccurencesOfCharacter:'i'],3,@"occurences of");
}

+(void)testAnyToString
{
	IDEXPECT( MPWConvertVarToString( 2 ),@"2", @"two");
	IDEXPECT( MPWConvertVarToString( NSMakePoint(2, 3) ),@"{2, 3}", @"2,3");
	IDEXPECT( MPWConvertVarToString( NSMakeRange(1, 2) ),@"{1, 2}", @"1,2");
	IDEXPECT( MPWConvertVarToString( @"asd" ),@"asd", @"2,3");
	IDEXPECT( MPWConvertVarToString( 3.2 ),@"3.2", @"3.2");
	IDEXPECT( MPWConvertVarToString( @selector(testAnyToString) ),@"testAnyToString", @"@selector");
}

+(NSArray*)testSelectors
{
    return [NSArray arrayWithObjects:
                @"testOccurencesOf",
				@"testAnyToString",
                nil];
}

@end

@implementation NSObject(StringAdditions)

-(NSString*)stringValue
/*"
    Fall-back implementation returns #{-description}.
"*/
{
    return [self description];
}
-(NSData*)asData
/*"
        Fall-back implementation returns #{-description} as a data.
"*/
{
    return [[self stringValue] asData];
}

@end

@implementation NSData(asData)

-(NSData*)asData
/*"
        Return #self.
"*/
{
    return self;
}

-stringValue
/*"
    Returns my bytes wrapped in a #NSString.
"*/
{
    return [[[NSString alloc] initWithData:self encoding:NSISOLatin1StringEncoding] autorelease];
}

@end
@interface MPWStringExtensionTesting:NSObject
@end
@implementation MPWStringExtensionTesting:NSObject
{
    
}

+(void)testUniquedByNumbering
{
    id pool,res1,res2,res3;

    pool=[NSSet setWithObjects:@"test",@"hi",@"blah",@"test-1",nil];
    res1 = [@"there" uniquedByNumberingInPool:pool];
    res2 = [@"hi" uniquedByNumberingInPool:pool];
    res3 = [@"test" uniquedByNumberingInPool:pool];
    NSAssert2( [res1 isEqual:@"there"], @"expected 'there' got %@ when uniqing 'there' against %@",res1,pool);
    NSAssert2( [res2 isEqual:@"hi-1"], @"expected 'hi-1' got %@ when uniqing 'hi' against %@",res1,pool);
    NSAssert2( [res3 isEqual:@"test-2"], @"expected 'test-2' got %@ when uniqing 'test' against %@",res1,pool);
}

+(void)testUniquedUpdating
{
    id pool,res1,res2,res3;
    id pool1,pool2,pool3;
    pool=[NSMutableSet setWithObjects:@"test",nil];
    pool1=[[pool copy] autorelease];
    res1 = [@"test" uniquedByNumberingInUpdatingPool:pool];
    pool2=[[pool copy] autorelease];
    res2 = [@"test" uniquedByNumberingInUpdatingPool:pool];
    pool3=[[pool copy] autorelease];
    res3 = [@"test" uniquedByNumberingInUpdatingPool:pool];
    NSAssert2( [res1 isEqual:@"test-1"], @"expected 'test-1' got %@ when uniqing 'test' against %@",res1,pool1);
    NSAssert2( [res2 isEqual:@"test-2"], @"expected 'test-2' got %@ when uniqing 'test' against %@",res1,pool2);
    NSAssert2( [res3 isEqual:@"test-3"], @"expected 'test-3' got %@ when uniqing 'test' against %@",res1,pool3);
}

+testSelectors
{
    return [NSArray arrayWithObjects:@"testUniquedByNumbering",@"testUniquedUpdating",nil];
}

@end

