/* MPWPropertyListStream.m Copyright (c) 1998-2012 by Marcel Weiher, All Rights Reserved.


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


#import "MPWPropertyListStream.h"


@interface NSString(_accessToInternalQuotedRep)
-quotedStringRepresentation;
@end


@implementation NSObject(PropertyListStreaming)

-(void)writeOnPropertyListStream:(MPWByteStream*)aStream
{
    [self writeOnByteStream:aStream];
}

@end

@implementation MPWPropertyListStream


-(void)beginArray
{
    [self appendBytes:"( " length:2];
}

-(void)endArray
{
    [self appendBytes:") " length:2];
}

-(void)beginDict
{
    [self appendBytes:"{ " length:2];
}

-(void)endDict
{
    [self appendBytes:"} " length:2];
}



-(void)writeString:(NSString*)anObject
{
	[self outputString:[anObject quotedStringRepresentation]];
}

-(void)writeEnumerator:(NSEnumerator*)e spacer:spacer
{
    BOOL first=YES;
    id nextObject;
    while (nil!=(nextObject=[e nextObject])) {
        [self writeIndent];
        if ( !first ) {
			[self appendBytes:"," length:2];
        }
        [self writeObject:nextObject];
		first=NO;
//        [self basicWriteString:@"\n"];
    }
}

-(void)writeArrayContent:(NSArray*)array
{
    [super writeArray:array];
}

-(void)writeArray:(NSArray*)anArray
{
//	NSLog(@" =========== plist stream write array: %@",anArray);
	[self beginArray];
    [self writeArrayContent:anArray];
	[self endArray];
}

-(void)writeEnumerator:e
{
    [self writeEnumerator:e spacer:@","];
}

-(SEL)streamWriterMessage
{
    return @selector(writeOnPropertyListStream:);
}


@end
@implementation NSString(PropertyListStreaming)

-(void)writeOnPropertyListStream:(MPWByteStream*)aStream
{
    [aStream writeString:self ];
}

@end


#import "DebugMacros.h"

@implementation MPWPropertyListStream(testing)


+_testStream {
	return [self streamWithTarget:[NSMutableString string]];
}

+_encode:anObject
{
	MPWPropertyListStream *writer=[self _testStream];
	//	NSLog(@"stream: %@",writer);
	[writer writeObject:anObject];
	[writer close];
	return [writer target];
}


+(void)testWriteString
{
	IDEXPECT( [self _encode:@"hello world"], @"\"hello world\"", @"string encode");
}

+(void)testWriteArray
{
	IDEXPECT( ([self _encode:[NSArray arrayWithObjects:@"hello",@"world",nil]]), 
			 @"( \"hello\",\"world\") ", @"array encode");
}

+(void)testWriteDict
{
	NSString *expectedEncoding= @"{\n    key = \"value\";\n    key1 = \"value1\";\n}";
	NSString *actualEncoding=[self _encode:[NSDictionary dictionaryWithObjectsAndKeys:@"value",@"key",
											@"value1",@"key1",nil ]];
	//	INTEXPECT( [actualEncoding length], [expectedEncoding length], @"lengths");
	
	IDEXPECT( actualEncoding, expectedEncoding, @"dict encode");
}

+(void)testWriteIntegers
{
	IDEXPECT( [self _encode:[NSNumber numberWithInt:42]], @"42", @"42");
	IDEXPECT( [self _encode:[NSNumber numberWithInt:1]], @"1", @"1");
	IDEXPECT( [self _encode:[NSNumber numberWithInt:0]], @"0", @"0");
	IDEXPECT( [self _encode:[NSNumber numberWithInt:-1]], @"-1", @"1");
}


+testSelectors
{
	return [NSArray arrayWithObjects:
			@"testWriteString",
			@"testWriteArray",
//			@"testWriteLiterals",
			@"testWriteIntegers",
			@"testWriteDict",
//			@"testEscapeStrings",
//			@"testUnicodeEscapes",
			nil];
}

@end

