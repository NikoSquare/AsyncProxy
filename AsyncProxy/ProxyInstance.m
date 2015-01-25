//
//  ProxyInstance.m
//  AsyncProxy
//
//  Created by Nikita Mordasov on 1/3/15.
//  Copyright (c) 2015 Nikita Mordasov. All rights reserved.
//

#import "ProxyInstance.h"

// IMPORT SOCKET INSTANCE CLASS, ALL INCOMING CONNECTIONS ARE PROCESSED BY
#import "SocketInstance.h"

@interface ProxyInstance ()
// NSString to keep last status message
@property (strong, nonatomic, readwrite) NSString *statusString;

// NSArray of SocketInstance instances (actual connections)
@property (nonatomic, strong) NSMutableArray *socketsArray;

// GCDAsyncSocket connection used only to check itself upon new port startup
@property (nonatomic, strong) GCDAsyncSocket *asyncCheck;

// GCDAsyncSocket connection that receives connection calls on selected port
@property (nonatomic, strong) GCDAsyncSocket *asyncTCP;

// Queue for main connection for clients on selected port
@property (nonatomic, strong) dispatch_queue_t queueTCPClient;

// int to store actual port for clients
@property (readwrite) int port;

// int to store actual proxy IP address as NSString
@property (strong, nonatomic) NSString *hostName;

// @property NSNetService *netService;
@end

@implementation ProxyInstance
@synthesize port = _port;
@synthesize queueTCPClient = _queueTCPClient;
@synthesize socketsArray = _socketsArray;
@synthesize hostName = _hostName;
@synthesize asyncCheck = _asyncCheck;
@synthesize statusString = _statusString;
@synthesize intTrafficIn = _intTrafficIn;
@synthesize intTrafficOut = _intTrafficOut;
@synthesize boolAbort = _boolAbort;


// Routine method fired from ViewController to update stats
- (void)updateTraffic
{
    // Main queue for safety
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        // reset counters
        self.intTrafficIn = 0;
        self.intTrafficOut = 0;
        // go through all available SocketInstances
    for (SocketInstance *socketInst in self.socketsArray) {
        // if instance is active
        if (!socketInst.isDisconnected) {
            // increase self counters by instance counters
        self.intTrafficIn = self.intTrafficIn + socketInst.intTrafficIn;
        self.intTrafficOut = self.intTrafficOut + socketInst.intTrafficOut;
        }
        // check for abort flag, transfer if present
        if (socketInst.boolAbort == true) { self.boolAbort = true; }
        // reset instance counters after read
        socketInst.intTrafficIn = 0;
        socketInst.intTrafficOut = 0;
    }
    }];
}

// Method to get available to use (disconnected) SocketInstance or create new one
- (SocketInstance *) socketGetter
{
    // check array first in case of disconnected one is present
    for (SocketInstance *socket in self.socketsArray)
    {
        // if present, just return it
        if ([socket isDisconnected]) { return socket; }
    }
    // if nothing available in array, just create new instance
    SocketInstance *socket = [[SocketInstance alloc] initWithQueue:self.queueTCPClient];
    // add it to array
    [self.socketsArray addObject:socket];
    // and return it
    return socket;
}

// Method exeuted during nullifying of self instance from ViewConroller
- (void)dealloc {
    // go through array and disconnect all sockets
    for (SocketInstance *socket in self.socketsArray) {
        if (!socket.isDisconnected) [socket disconnectNow];
    }
    // release all objects from array
    [self.socketsArray removeAllObjects];
    // nullify array
    self.socketsArray = nil;
    // disconnect and nullify sockets
    [self.asyncTCP disconnect];
    [self.asyncCheck disconnect];
    self.asyncTCP = nil;
    self.asyncCheck = nil;
    // nullify queue pointer
    self.queueTCPClient = nil;
    // nullify host string
    self.hostName = nil;
}



- (instancetype)initWithPort: (int) port andHost: (NSString *)host onQueue: (dispatch_queue_t) queue
{
    self = [super init];
    if (self) {
        // APPLY HOSTNAME, MUST BE VALID FROM VIEW CONTROLLER
        self.hostName = host;
        // update status message
        self.statusString = @"STARTING UP...";
        // init mutable array for SocketInstances
        self.socketsArray = [NSMutableArray array];
        // store received queue for connections
        self.queueTCPClient = queue; // dispatch_queue_create("AsyncProxy.queueTCPClient", DISPATCH_QUEUE_SERIAL);
        // init socket to listen port and receive connections
        self.asyncTCP = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.queueTCPClient];
        // set simple object to distinguish queue from others
        self.asyncTCP.userData = [NSNumber numberWithBool:true];
        // error variable, just in case of need
        NSError *error = nil;
        // START PROXY LISTENING AT PORT
        if (![self.asyncTCP acceptOnPort:port error:&error])
        {
            // IN CASE OF FAILURE
            self.statusString = @"FAILURE: PORT IS UNAVAILABLE";
            self.port = -1;
            [self.asyncTCP disconnect];
        } else {
            // IN CASE OF SUCCESS
            // update actual port number, due to if passed 0(AUTO), port assigned by system
        self.port = [self.asyncTCP localPort];
            
            // CHECK PROXY AVAILABILITY
            // init connection socket to send request to self listening socket
            self.asyncCheck = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.queueTCPClient];
            // connect to self listening socket
            if ([self.asyncCheck connectToHost:self.hostName onPort:self.port withTimeout:1 error:nil]) {
                // in case of success
                // set possible failure on this stage
                self.statusString = @"FAILURE: SELF CHECK";
                // set port to negative as possible failure (if check take more than a second, viewcontroller will release it)
                self.port = -2;
                // compose check data packet
                uint8_t dataInt[1];
                dataInt[0] = 77;
                // send packet to self
                [self.asyncCheck writeData: [NSData dataWithBytes:dataInt length:1] withTimeout:1 tag:0];
            } else {
                // in case of failure
                // set status
                self.statusString = @"FAILURE: SELF IP CONNECTION";
                // set negative port value
                self.port = -2;
                // disconnect all
                [self.asyncTCP disconnect];
                [self.asyncCheck disconnect];
                self.asyncCheck = nil;
            }
            
            
    }
    }
    return self;
}

// protocol method after successful sending of packet
-(void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    // This is really can be call only from CHECK socket
    // but in case of something, make it sure (usedata must be null)
    if (sock.userData == nil) {
        // switch to read mode and wait 1 second for response
    [sock readDataWithTimeout:1 tag:999];
    }
}

// protocol method after successful receiving of packet
-(void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    //NSLog(@"DID READ FROM: %@:%d", sock.connectedHost, sock.connectedPort);
    // this is really must be only packet to self check, generated in socketInstance
    // access bytes
    const uint8_t *dataInt = data.bytes;
    // check answer
    if (dataInt[0] == 88) {
        // if get what expected
        self.statusString = @"PROXY IS RUNNING";
        // reassign port once again
        self.port = [self.asyncTCP localPort];
        // disconnect check socket
        [sock disconnect];
        // release check socket
        [self.asyncCheck disconnect];
        self.asyncCheck = nil;
    } else {
        // if kind of wrong packet
        self.statusString = @"FAILURE: IP ADDRESS CHECK";
        self.port = -2;
        [sock disconnect];
        // release all sockets
        [self.asyncCheck disconnect];
        self.asyncCheck = nil;
        [self.asyncTCP disconnect];
        self.asyncTCP = nil;
    }
}

// protocol method, main method actually, here all client new requests received on port will be processed into socketInstance
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    // update status
    self.statusString = [NSString stringWithFormat:@"PROXY IS RUNNING..\nLAST CLIENT: %@", [newSocket connectedHost]];
    
    // assign personal client's socket to designated socketInstance
    // first get ready to use instance
    SocketInstance *socketInstance = [self socketGetter];
    // The newSocket automatically inherits its delegate & delegateQueue from its parent
    // but we need to make it managebale by instance, so just update delegate to instance
    newSocket.delegate = socketInstance;
    // pass socket to instance method, it will take care about further operations
    [socketInstance updateClientSocket:newSocket andHostname:self.hostName andPort:self.port];
}

// protol method on socket disconnection
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    // if its listening socket
    if (sock.userData != nil) {
        // release most of the stuff
    for (SocketInstance *socket in self.socketsArray) {
        if (!socket.isDisconnected) [socket disconnectNow];
    }
        // set port to error state
    self.port = -2;
        // disconnect client socket
    [self.asyncTCP disconnect];
        self.asyncTCP = nil;
        self.asyncCheck = nil;
        self.statusString = @"PROXY OFFLINE";
    } else {
        // if it's "check" socket, just nullify
        self.asyncCheck = nil;
    }
}


@end
