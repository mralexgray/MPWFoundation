/* MPWScanner.m Copyright (c) 1998-2012 by Marcel Weiher, All Rights Reserved.


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


#import "MPWScanner.h"
#import "AccessorMacros.h"
#import "MPWSubData.h"
#import "MPWObjectCache.h"
#import "NSObjectFiltering.h"
#import "NSStringAdditions.h"
#import "MPWStream.h"

@implementation MPWScanner
/*"
   An abstract superclass for scanners with an enumerator-like protocol, that is, clients
   get scanned objects by calling 'nextObject'.  Subclass implement specific scanners.

   The current implementation only scans 8-bit data from NSData objects, that is with all the data
   completely available.  Scanning from input streams (providing NSData objects) is
   planned.  16-bit scanning is being considered.

"*/

+(NSArray*)scan:(NSData*)aData
/*"
   Convenience method that completely scans the data provided in aData provided.
"*/
{
    id scanner=[[self alloc] initWithData:aData];
    id result = [[scanner allObjects] retain];
    [scanner release];
    return [result autorelease];
}

+scannerWithData:(NSData*)aData
/*
   Returns an autoreleased, initialized scanner scanning aData.
*/
{
    return [[[self alloc] initWithData:aData] autorelease];
}

+scannerWithDataSource:aDataSource
/*
   Returns an autoreleased, initialized scanner scanning NSData compatible object returned by aDataSource.
*/
{
    return [[[self alloc] initWithDataSource:aDataSource] autorelease];
}

-(void)_initCharSwitch
/*
    Private method to be implemented by subclass to initialize the character-switch-table.
    The character switch table #charSwitch provides an IMP to call for each of the 256
    possible characters encountered at the top level of a scan.
*/
{
    unsigned int i;
    IMP scanText=[self methodForSelector:@selector(scanText)];
    for (i=0;i<256;i++) {
        charSwitch[i]=scanText;
    }
}

-(unsigned)textCacheSize
{
    return 20;
}

idAccessor( data, _setData )
idAccessor( dataSource, setDataSource )

-(void)addData:(NSData*)newData
{
    unsigned probeOffset;
    NSMutableData *bufferData=nil;
    id subdata=nil;
//    NSLog(@"addData: entered");
    newData=[newData asData];
    if ( data && pos<end ) {
        bufferData=[bufferCache getObject];
        [bufferData setLength:0];
        [bufferData appendBytes:pos length:end-pos];
        [bufferData appendData:newData];
//        NSLog(@"new buffer has length: %d (%d old %d new)",[bufferData length],end-pos,[newData length]);
        probeOffset=probe-pos;
        newData=bufferData;
    } else {
//        NSLog(@"first buffer or %x=%x",pos,end);
        probeOffset=0;
    }
    start=[newData bytes];
    pos=start;
    probe=start+probeOffset;
    end=start+[newData length];
//	NSLog(@"newData: '%@'",newData);
//	NSLog(@"newData length: '%x'",[newData bytes]);
//	NSLog(@"newData: '%d'",[newData length]);
    subdata=[[MPWSubData alloc] initWithData:newData bytes:[newData bytes] length:[newData length]];
    [self _setData:subdata];
    [subdata release];
//    NSLog(@"addData: exit");
}

-sourceNextObject
{
    id next = [dataSource nextObject];
//    NSLog(@"next = %@",[next class]);
    return next;
}

-(void)validate
{
	if ( [[self data] length] == 0 ) {
		NSLog(@"invalid scanner for 0-length data");
	}
	[[self data] validate];
}

-reInitWithSource:aDataSource
{
    [self _setData:nil];
    [self setDataSource:aDataSource];
    [self addData:[self sourceNextObject]];
	[self validate];
    return self;
}

-initWithDataSource:aDataSource
/*
    Returns an initialized scanner scanning aDataSource.  Calls #{_initCharSwitch}.

    Designated initializer for this class.
*/
{
    self = [super init];
    handlers = [[NSMutableDictionary alloc] init];
    textCache= [[MPWObjectCache alloc] initWithCapacity:[self textCacheSize] class:[MPWSubData class]];
//    [textCache setUnsafeFastAlloc:YES];
    bufferCache= [[MPWObjectCache alloc] initWithCapacity:8 class:[NSMutableData class] ];
    [bufferCache setUnsafeFastAlloc:YES];
    getObject = [textCache methodForSelector:@selector(getObject)];
    initData=[[MPWSubData class] instanceMethodForSelector:@selector(reInitWithData:bytes:length:)];
    makeText=[self methodForSelector:@selector(makeText:)];
    setScanPosition=[self methodForSelector:@selector(setScanPosition:)];
    [self _initCharSwitch];
    [self reInitWithSource:aDataSource];

    return self;
}

-initWithData:(NSData*)aData
{
    return [self initWithDataSource:[[NSArray arrayWithObject:aData] objectEnumerator]];
}

-(void)dealloc
{
    [data release];
    [dataSource release];
    [handlers release];
    [defaultHandler release];
    [textCache release];
    [bufferCache release];
    start=NULL;
    probe=NULL;
    pos=NULL;
    end=NULL;
    [super dealloc];
}

-(void)setScanPosition:(const char*)newPos
{
    if ( newPos >= start && pos < end ) {
        pos=newPos;
    }
    if ( probe < pos ) {
        probe=pos;
    }
}

-(const char*)position
{
    return pos;
}

-(unsigned)bufLen
{
    return end-pos;
}

-(unsigned)offset
{
    return pos-start;
}

-(void)addHandler:aHandler forKey:(NSString*)aKey
{
    [handlers setObject:aHandler forKey:aKey];
}

-handlerForKey:(NSString*)aKey
{
    id handler;
    if (nil==(handler= [handlers objectForKey:aKey])) {
        handler=defaultHandler;
    }
    return handler;
}

-makeText:(unsigned int)length
/*"
    Scans length bytes from the data source, returning an MPWSubData referencing
    the original data, no copying of data is performed.
"*/
{
    id text = GETOBJECT( (MPWObjectCache*)textCache );
    RESERVE(length);
    if ( pos+length > end ) {
        length=end-pos;
    }
    initData(text , @selector(reInitWithData:bytes:length:), data, pos, length );
    pos=pos+length;
    return text;
}

-(NSStringEncoding)stringEncoding
{
	return NSISOLatin1StringEncoding;
}

-makeString:(unsigned int)length
/*"
        Scans length bytes from the data source, returning an NSString copying
        the original data.
"*/
{
    id str = [[[NSString alloc] initWithBytes:pos length:length encoding:[self stringEncoding]] autorelease];
    pos=pos+length;
    return str;
}

-scanText
/*"
   Scans as much 'plain' data as possible.  This implementation will scan to the end
   of data.  Subclasses will probably want to re-implement this method to scan up to
   the next bit of 'interesting' data, such as XML markup or DSC comments.

   Sends #makeText to create the object.
"*/
{
    id result;
    probe=end;
    result = makeText( self, @selector(makeText:),probe-pos );
    MAKE_PROBE_CURRENT;
   return result; 
}

-(void)skipEOL
{
    const  char *cur=pos;
    if (SCANINBOUNDS(cur) && *cur=='\15' ) {
        cur++;
    }
    if ( SCANINBOUNDS(cur) && *cur=='\n' ) {
        cur++;
    }
	UPDATEPOSITION(cur);
}

-(void)updateBufferFromSource
{
    
}

-nextLine
{
	id result=nil;
    const  char *cur=pos;
	if ( cur < end ) {
		while  (SCANINBOUNDS(cur) && *cur!='\15'  && *cur!='\12' ) {
			cur++;
		}
		probe=cur;
		result = makeText( self, @selector(makeText:),probe-pos );
		MAKE_PROBE_CURRENT;
		[self skipEOL];
	}
	return result;

}

-nextObject
{
    id nextScanned=nil;
    if ( pos<end ) {
        nextScanned = charSwitch[*(unsigned char*)pos]( self, NULL );
    }
    return nextScanned;
}

-(unsigned)count
{
    unsigned count=0;
    IMP nextObject=[self methodForSelector:@selector(nextObject)];
    while (nil!=nextObject( self, @selector(nextObject))) {
        count++;
    }
    return count;
}

-(void)writeOnMPWStream:aStream
{
    [aStream writeEnumerator:self];
}

-allObjects
{
    id result=[NSMutableArray array];
    id nextObject;
    while ( nextObject=[self nextObject] ) {
        [result addObject:nextObject];
    }
    return result;
}

-(int)previousContext
{
    return 20;
}

-(int)followContext
{
    return 20;
}

-(void)computeHeadRoom
{
    headRoom=0;
}

-(BOOL)reserve:(int)roomNeeded
{
    BOOL gotOne=NO;
//    NSLog(@"reserve: %d",roomNeeded);
    if ( dataSource && roomNeeded >= end-pos ) {
        NSData* nextData=nil;
        NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
        do {
//            NSLog(@"reserve getting new data");
            if ( nil!=(nextData =[self sourceNextObject]) && [nextData length]>0  )  {
//                NSLog(@"reserve got %d bytes of data",[nextData length]);
                 [self addData:nextData];
                gotOne=YES;
			} else {
				break;
			}
            [self computeHeadRoom];
        } while ( end-pos < roomNeeded  );
        [pool drain];
    } else {
//        NSLog(@"requested %d, have %d",roomNeeded,end-pos);
    }
    return gotOne;
}

-(void)skipTo:(NSString*)aString
{
	int checkLen=[aString length];
	char checkString[ checkLen  + 4];
	BOOL found=NO;
    const char *cur=pos;

	[aString getCString:checkString maxLength:checkLen+1 encoding:NSUTF8StringEncoding];
	while ( SCANINBOUNDS(cur)  && !found ) {
		while ( SCANINBOUNDS(cur)  && *cur != checkString[0] )	{
			cur++;
		}
		found=SCANINBOUNDS(cur+checkLen) && !strncmp(cur,checkString, checkLen);
		if (!found) {
			cur++;
		}
	}
	pos=cur;
}

static inline void copybuf( char *target,const char *source, int len ) {
    int i;
    for (i=0;i<len;i++) {
        if ( source[i]==13 ) {
            target[i]=10;
        } else {
            target[i]=source[i];
        }
    }
    target[len]=0;
}

-(NSString*)description
{
    int offs=pos-start;
    int len=end-start;
    int contextLen,contextStart;
    int prev=[self previousContext];
    int follow=[self followContext];
    char prevbuf[prev+10];
    char followbuf[follow+10];
    contextStart=offs-prev;
    if ( contextStart < 0 ) {
        contextStart=0;
    }
    contextLen=8;
    if ( contextLen > len-offs ) {
        contextLen=len-offs;
    }
    copybuf( prevbuf, start+contextStart,offs-contextStart );
    copybuf( followbuf, pos, contextLen );
    return [NSString stringWithFormat:@"%@ with pos=%d probe=%ld len=%d, context='%s''%s'",
        [self class],offs,(long)(probe-start),len,prevbuf,followbuf];
}

@end

#if ! TARGET_OS_IPHONE

#import "DebugMacros.h"

@implementation MPWScanner(TestSupport)

+(void)testFile:(NSString*)filename
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    id result,result1check;
    BOOL silent=[[NSUserDefaults standardUserDefaults] boolForKey:@"silent"];
    result=[self scan:[NSData dataWithContentsOfMappedFile:filename]];

    if (!silent) {
        id resultfilename = [NSString stringWithFormat:@"%@.%@-result",filename,self];

        result = [[result collect] descr];
        result1check=[[NSString stringWithContentsOfFile:resultfilename encoding:NSISOLatin1StringEncoding error:nil] propertyList];
        if ( ![result isEqual:result1check] ) {
            [NSException raise:@"testFile failed" format:@"test %@ = result1:  '%@' expected:'%@' from: %@",filename,result,result1check,resultfilename];
        }
    }
    [pool release];
}

+(void)testScannerWithDefaultFile
{
    if ( [self class] != [MPWScanner class] ) {
        [NSException raise:@"testScannerWithDefaultFile is abstract" format:@"testScannerWithDefaultFile is abstract"];
    }
}

+(void)testLineOfTextScanning
{
	id source=@"several lines of\ntext with different\reol conventions\r\njust to be sure";
	id expected=[NSArray arrayWithObjects:@"several lines of",@"text with different",
			@"eol conventions",@"just to be sure",nil];
	id scanner = [[[self alloc] initWithData:[source asData]] autorelease];
	id result=[NSMutableArray array];
	id nextLine=nil;
	while ( nil!=(nextLine=[scanner nextLine])) {
		[result addObject:nextLine];
	}
	IDEXPECT( result, expected, @"scanning lines");
}

+(void)test:(NSString*)file
{
    if ( file ) {
        [self testFile:file];
    } else {
        [self testScannerWithDefaultFile];
    }
}

+testSelectors
{
    return [NSArray arrayWithObjects:
        @"testScannerWithDefaultFile",
        @"testLineOfTextScanning",
		nil];
}

@end

@implementation NSObject(descr)
-(NSString*)descr { return [self description]; }
@end

#endif
