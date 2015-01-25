//
//  ProcessorSocks5.h
//  AsyncProxy
//
//  Created by Nikita Mordasov on 1/4/15.
//  Copyright (c) 2015 Nikita Mordasov. All rights reserved.
//
// Class to process Socks5 without additional instanciation
// Only manipulation of existing objects

#import <Foundation/Foundation.h>
// TCP SOCKET is in use
#import "GCDAsyncSocket.h"
// UDP SOCKET is in use
#import "GCDAsyncUdpSocket.h"

@interface ProcessorSocks5 : NSObject

// Class method to process all data
+(void)socketClientTCP: (GCDAsyncSocket *) socket withData: (NSData *) data withTag: (long) tag socketHostTCP: (GCDAsyncSocket *) socketHost socketClientUDP: (GCDAsyncUdpSocket *) udpSocket socketHostUDP: (GCDAsyncUdpSocket *) udpSocketHost ipString: (NSString *) ipString;
@end
