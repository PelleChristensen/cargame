//
//  Client.m
//  Car Game
//
//  Created by Daniel Andersen on 17/01/14.
//  Copyright (c) 2014 Alexandra Instituttet. All rights reserved.
//

#import "Client.h"

#define PORT_NUMBER 20021

@interface Client () {
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
}

@property (nonatomic, retain) NSInputStream *inputStream;
@property (nonatomic, retain) NSOutputStream *outputStream;
@property (nonatomic, retain) NSString *ipAddress;
@property (nonatomic, assign) bool ready;

@end

@implementation Client

- (void)initConnectionWithIpAddress:(NSString *)ipAddress {
    NSLog(@"Opening connection...");
    self.ready = NO;
    self.ipAddress = ipAddress;
    
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)self.ipAddress, PORT_NUMBER, &readStream, &writeStream);

    self.inputStream = (__bridge NSInputStream *)readStream;
    self.outputStream = (__bridge NSOutputStream *)writeStream;
    
    [self.inputStream setDelegate:self];
    [self.outputStream setDelegate:self];
    
    [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [self.inputStream open];
    [self.outputStream open];
}

- (void)closeConnection {
    if (self.inputStream == nil) {
        return;
    }
    NSLog(@"Closing connection...");
    
    [self.inputStream close];
    [self.outputStream close];

    [self.inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    self.inputStream = nil;
    self.outputStream = nil;
    
    self.ready = NO;

    [self.delegate connectionClosed];
}

- (void)sendMessage:(NSString *)message {
    message = [NSString stringWithFormat:@"%@\r\n", message];
	NSData *data = [[NSData alloc] initWithData:[message dataUsingEncoding:NSASCIIStringEncoding]];
	[self.outputStream write:[data bytes] maxLength:[data length]];
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    NSError *error;
    
    switch (eventCode) {
        case NSStreamEventHasSpaceAvailable: {
			if(aStream == self.outputStream && !self.ready) {
				NSLog(@"Outputstream is ready.");
                self.ready = YES;
                [self.delegate connectionOpened];
			}
			break;
		}
		
        case NSStreamEventOpenCompleted:
			break;
            
		case NSStreamEventHasBytesAvailable:
            if (aStream == self.inputStream) {
                [self handleInput];
            }
			break;
            
		case NSStreamEventErrorOccurred:
            error = [aStream streamError];
            [self.delegate connectionError:error.localizedDescription];
			break;
            
		case NSStreamEventEndEncountered:
            [self closeConnection];
 			break;
            
		default:
            NSLog(@"Unknown event code: %i", (int)eventCode);
            break;
	}
}

- (void)handleInput {
    uint8_t buffer[1024];
    long len;
    
    while ([self.inputStream hasBytesAvailable]) {
        len = [self.inputStream read:buffer maxLength:sizeof(buffer)];
        if (len > 0) {
            NSString *output = [[NSString alloc] initWithBytes:buffer length:len encoding:NSASCIIStringEncoding];
            if (output != nil) {
                [self.delegate receivedMessage:output];
            }
        }
    }
}

@end
