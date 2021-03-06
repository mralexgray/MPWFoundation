/*
/
    MPWFuture.m
  
    Created by Marcel Weiher on 28/03/2005.
    Copyright (c) 2005-2012 by Marcel Weiher. All rights reserved.

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

//

#import "MPWFuture.h"
#import "MPWWorkQueue.h"
#import "AccessorMacros.h"
#import "MPWTrampoline.h"
#import "DebugMacros.h"
#import "NSInvocationAdditions.h"

@implementation NSInvocation(copying)

#define LOCK_IN_PROGESS  0
#define LOCK_DONE		  1

-copyWithZone:(NSZone*)aZone
{
	id copy =[[NSInvocation invocationWithMethodSignature:[self methodSignature]] retain];
	char buffer[256];
	int i,numArgs;
	
	for (i=0,numArgs=[[self methodSignature] numberOfArguments];i<numArgs;i++) {
		[self getArgument:buffer atIndex:i];
		[copy setArgument:buffer atIndex:i];
	}
	[copy setTarget:[self target]];
	return copy;
}

@end

@implementation MPWFuture

objectAccessor( NSInvocation, invocation, setInvocation )
objectAccessor( NSConditionLock, lock, setLock )
idAccessor( target, setTarget )
idAccessor( _result, setResult )

+futureWithTarget:newTarget
{
	return [[[self alloc] initWithTarget:newTarget] autorelease];
}

-initWithTarget:newTarget
{
//	self=[super init];
	[self setLock:[[[NSConditionLock alloc] initWithCondition:LOCK_IN_PROGESS] autorelease]];
	[self setTarget:newTarget];
	return self;
}

//#if 0
- (BOOL)respondsToSelector:(SEL)aSelector
{
//	NSLog(@"respondsToSelector: %@",NSStringFromSelector(aSelector));
	return YES; // [target respondsToSelector:aSelector];
}
//#endif

-(NSMethodSignature*)methodSignatureForHOMSelector:(SEL)aSelector
{
	if ( running) {
		return [[self result] methodSignatureForSelector:aSelector];
	} else {
		return [target methodSignatureForSelector:aSelector];
	}
}



-(NSMethodSignature*)methodSignatureForSelector:(SEL)aSelector
{
	return [self methodSignatureForHOMSelector:aSelector];
}

+ (BOOL)instancesRespondToSelector:(SEL)aSelector
{
//	NSLog(@"instancesRespondToSelector: %@",NSStringFromSelector(aSelector));
	return YES; // [target respondsToSelector:aSelector];
}


-(void)invokeInvocationOnceInNewThread
{
	[self performJob];
}

-(void)performJob
{
	id pool=[NSAutoreleasePool new];
//    NSLog(@"performJob(%p)",self);
    id tempResult = [invocation returnValueAfterInvokingWithTarget:target];
	[self setResult:tempResult];
//    NSLog(@"performJob(%p), result: %p/%@",self,tempResult,tempResult);
	[lock tryLock];
	[lock unlockWithCondition:LOCK_DONE];
//    NSLog(@"performJob(%p) did unblock reader",self);
	[pool release];
}

-(void)startRunning
{
	running=YES;
//    [[self async] performJob];
#if NS_BLOCKS_AVAILABLE
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ [self performJob];});
#else
	[[MPWWorkQueue defaultQueue] addJob:self];
    
#endif
//	[[self asyncJob] invokeInvocationOnceInNewThread];
//	[NSThread detachNewThreadSelector:@selector(invokeInvocationOnceInNewThread) toTarget:self withObject:nil];
}

-(void)lazyEval:(NSInvocation*)newInvocation
{
	NSInvocation *threadedInvocation=[newInvocation copy];
	[self setInvocation:threadedInvocation];
	[threadedInvocation release];
	[newInvocation setReturnValue:&self];
}

-futureEval:(NSInvocation*)newInvocation
{
	[self lazyEval:newInvocation];
	[self startRunning];
    return self;
}

-(void)waitForResult
{
	if (!running) {
		[self startRunning];
	}
	[lock lockWhenCondition:LOCK_DONE];
	[lock unlock];
}

-result
{
//    NSLog(@"result(%p)",self);
	if ( ![self _result] ) {
//        NSLog(@"will wait for result(%p)",self);
		[self waitForResult];
//        NSLog(@"did wait for result(%p)",self);
	}
//    NSLog(@"result(%p): %@",self,[self _result]);
	return [self _result];
}

-(void)forwardInvocation:(NSInvocation*)messageForResult
{
	[messageForResult invokeWithTarget:[self result]];
}

-description
{
	return [[self result] description];
}

-xxxDescription
{
	return [super description];
}


@end

@implementation NSObject(future)

-future
{
	return [MPWTrampoline trampolineWithTarget:[MPWFuture futureWithTarget:self] selector:@selector(futureEval:)];
}

-lazy
{
	return [MPWTrampoline trampolineWithTarget:[MPWFuture futureWithTarget:self] selector:@selector(lazyEval:)];
}

-result
{
	return self;
}

@end

@interface _MPWFutureTestDummyClass : NSObject {
	
}
-waitSomeMS:(int)ms withString:(NSString*)str;
@end

@implementation _MPWFutureTestDummyClass 

-waitSomeMS:(int)ms withString:(NSString*)str;
{
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:ms/1000.0]];
	return [NSString stringWithFormat:@"%@ %d",str,ms];
}

@end

@interface MPWFutureTesting : NSObject {}
@end


@implementation MPWFutureTesting

+testSelectors {
	return [NSArray arrayWithObjects:
		@"simpleTest",
		@"simpleTestWithoutExplicitResultGetting",
		@"futuresAreFasterThanSerial",
		nil];
}

+(void)simpleTest
{
	id expected=@"ab";
	id result = [(id)[[@"a" future] stringByAppendingString:@"b"] result];
	IDEXPECT( result, expected, @"simple string concat" );
}

+(void)simpleTestWithoutExplicitResultGetting
{
	id expected=@"ab";
	id result = [[@"a" future] stringByAppendingString:@"b"];
//	NSLog(@"result: '%@' expected '%@'",[result description],[expected description]);
	IDEXPECT( [result stringValue], [expected stringValue], @"simple string concat" );
}



+(void)futuresAreFasterThanSerial
{
	int i;
	const int WAIT_TIME_MS = 120;
	id tester=[[[_MPWFutureTestDummyClass alloc] init] autorelease];
	NSArray *sourceArray = [NSArray arrayWithObjects:@"a",@"b",@"c",@"d",@"e",nil];
	NSMutableArray *futureArrayResult,*serialArrayResult;
	NSTimeInterval startSerial,stopSerial,startFuture,stopFuture;
	startSerial=[NSDate timeIntervalSinceReferenceDate];
	serialArrayResult=[NSMutableArray array];
	NSTimeInterval serialTime,futureTime;
	for (i=0;i<[sourceArray count];i++) {
		id res=[tester waitSomeMS:WAIT_TIME_MS withString:[sourceArray objectAtIndex:i]];
		[serialArrayResult addObject:res];
	}
	stopSerial=[NSDate timeIntervalSinceReferenceDate];
	
	startFuture=[NSDate timeIntervalSinceReferenceDate];
	futureArrayResult=[NSMutableArray array];
	for (i=0;i<[sourceArray count];i++) {
		id res=[[tester future] waitSomeMS:WAIT_TIME_MS withString:[sourceArray objectAtIndex:i]];
		[futureArrayResult addObject:res];
	}

	for (i=0;i<[futureArrayResult count];i++) {
		[futureArrayResult replaceObjectAtIndex:i withObject:[[futureArrayResult objectAtIndex:i] result]];
	}

	stopFuture=[NSDate timeIntervalSinceReferenceDate];
	serialTime =(stopSerial-startSerial)*1000;
	futureTime =(stopFuture-startFuture)*1000;
	NSLog(@"serial took: %g future took: %g",serialTime,futureTime);
	IDEXPECT( [futureArrayResult description], [serialArrayResult description], @"results should be identical");
	NSLog(@"after checking results are identical");
	NSLog(@"ratio: %g", serialTime / futureTime  );
	NSAssert2( (serialTime / futureTime) > 2  , @"future time (%g ms) should be more than 2 times as fast as serial time (%g ms)",
			   futureTime,serialTime);
	NSLog(@"after checking timing");
}


@end
