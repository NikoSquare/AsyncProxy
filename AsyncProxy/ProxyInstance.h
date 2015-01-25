//
//  ProxyInstance.h
//  AsyncProxy
//
//  Created by Nikita Mordasov on 1/3/15.
//  Copyright (c) 2015 Nikita Mordasov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

@interface ProxyInstance : NSObject <GCDAsyncSocketDelegate>
- (instancetype)initWithPort: (int) port andHost: (NSString *)host onQueue: (dispatch_queue_t) queue;
@property (readonly) int port;
@property (strong, nonatomic, readonly) NSString *statusString;
@property BOOL boolAbort;
@property int intTrafficIn;
@property int intTrafficOut;
- (void)updateTraffic;
@end
