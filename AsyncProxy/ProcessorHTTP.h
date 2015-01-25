//
//  ProcessorHTTP.h
//  AsyncProxy
//
//  Created by Nikita Mordasov on 1/10/15.
//  Copyright (c) 2015 Nikita Mordasov. All rights reserved.
//
// Class to process HTTP without additional instanciation
// Only manipulation of existing objects

#import <Foundation/Foundation.h>
// TCP SOCKET is in use
#import "GCDAsyncSocket.h"

@interface ProcessorHTTP : NSObject
// RETURNS ARRAY OF PARSED DATA FROM HTTP HEADER
+(NSArray *)httpHeaderHostPortBodyFromData: (NSData *) data;
// PROCESSING OF HTTP PROTOCOL
+(void)processData: (NSData *) data withTag: (long) tag socketClientTCP: (GCDAsyncSocket *) socketClient socketHostTCP: (GCDAsyncSocket *) socketHost mutableDataClient: (NSMutableData *) dataClient mutableDataHost: (NSMutableData *) dataHost;
@end
