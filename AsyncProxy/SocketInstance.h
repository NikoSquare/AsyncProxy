//
//  SocketInstance.h
//  AsyncProxy
//
//  Created by Nikita Mordasov on 1/4/15.
//  Copyright (c) 2015 Nikita Mordasov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"
#import "GCDAsyncUdpSocket.h"

@interface SocketInstance : NSObject <GCDAsyncSocketDelegate, GCDAsyncUdpSocketDelegate>
@property BOOL boolAbort;
@property int intTrafficIn;
@property int intTrafficOut;

- (BOOL)isDisconnected;
- (void)updateClientSocket: (GCDAsyncSocket *) socket andHostname: (NSString *) hostString andPort: (int) portNumber;
- (void)disconnectNow;
- (instancetype)initWithQueue: (dispatch_queue_t) queue;
@end
