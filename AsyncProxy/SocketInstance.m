//
//  SocketInstance.m
//  AsyncProxy
//
//  Created by Nikita Mordasov on 1/4/15.
//  Copyright (c) 2015 Nikita Mordasov. All rights reserved.
//

#import "SocketInstance.h"

// processor methods are class method without instanciating
#import "ProcessorSocks5.h"
#import "ProcessorHTTP.h"


@interface SocketInstance()
// store proxy listening port
@property int proxyPort;
// store proxy hostname
@property (strong, nonatomic) NSString *proxyHost;
// socket to client TCP
@property (nonatomic, strong) GCDAsyncSocket *socketClientTCP;
// socket to client UDP
@property (nonatomic, strong) GCDAsyncUdpSocket *socketClientUDP;
// socket to target TCP
@property (nonatomic, strong) GCDAsyncSocket *socketHostTCP;
// socket to target UDP
@property (nonatomic, strong) GCDAsyncUdpSocket *socketHostUDP;


// QUEUE FOR CLIENT TCP SOCKET
@property (nonatomic, strong) dispatch_queue_t queueTCPClient;
// QUEUE FOR INTERNET TCP SOCKET
@property (nonatomic, strong) dispatch_queue_t queueTCPHost;

// QUEUE FOR CLIENT UDP SOCKET
@property (nonatomic, strong) dispatch_queue_t queueUDPClient;
// QUEUE FOR INTERNET UDP SOCKET
@property (nonatomic, strong) dispatch_queue_t queueUDPHost;

// NSMuatbleData to compose complete HTTP message from multiple packets
// messages from client
@property (strong, nonatomic) NSMutableData *httpPacketData;
// messages from target
@property (strong, nonatomic) NSMutableData *httpPacketDataFromHost;

@end





@implementation SocketInstance

@synthesize proxyHost = _proxyHost;
@synthesize proxyPort = _proxyPort;

@synthesize socketClientTCP = _socketClientTCP;
@synthesize socketClientUDP = _socketClientUDP;
@synthesize socketHostTCP = _socketHostTCP;
@synthesize socketHostUDP = _socketHostUDP;

@synthesize queueUDPClient = _queueUDPClient;
@synthesize queueTCPClient = _queueTCPClient;
@synthesize queueTCPHost = _queueTCPHost;
@synthesize queueUDPHost = _queueUDPHost;
@synthesize httpPacketData = _httpPacketData;
@synthesize httpPacketDataFromHost = _httpPacketDataFromHost;
@synthesize intTrafficIn = _intTrafficIn;
@synthesize intTrafficOut = _intTrafficOut;
@synthesize boolAbort = _boolAbort;


// protocol method
-(void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error
{
    [self.socketHostUDP close];
    [self.socketClientUDP close];
}

// method to trigger disconnection
-(void)disconnectNow
{
    [self.socketClientTCP disconnect];
}


// protocol method on any TCP disconnection
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    //disconnect everything
    if (!self.socketHostTCP.isDisconnected) [self.socketHostTCP disconnect];
    if (!self.socketClientTCP.isDisconnected) [self.socketClientTCP disconnect];
    if (!self.socketClientUDP.isClosed) [self.socketClientUDP close];
    if (!self.socketHostUDP.isClosed) [self.socketHostUDP close];
}

// protocol method on UDP diconnection
-(void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error
{
    // disconnect TCP
    [self.socketClientTCP disconnect];
}

// protocol method on successful send
-(void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
    // read for answer
    [sock beginReceiving:nil];
}

// protocol method on successful reading
-(void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext
{
    
    // check whose socket is it
    if (sock.userData != nil) {
        // if userdata present, it is client
        // SAVE RETURN CLIENT'S ADDRESS
            // IF TARGET IS NOT CONNECTED YET, MEANS ITS FIRST CONNECTION FROM CLIENT
        if (self.socketHostUDP.isClosed) { [self.socketClientUDP.userData setObject:address atIndexedSubscript:0]; }
        
        // calculate packet size
        int dataSize = (int)data.length;
        // update counter on main queue
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            self.intTrafficOut = self.intTrafficOut + dataSize;
        }];
        
        // pass everything to processor (UDP is SOCKS option)
        [ProcessorSocks5 socketClientTCP:self.socketClientTCP withData:data withTag:5500 socketHostTCP:self.socketHostTCP socketClientUDP:self.socketClientUDP socketHostUDP:self.socketHostUDP ipString:self.proxyHost];
        
    } else {
        
        // if it's from target
        
        // calculate packet size
        int dataSize = (int)data.length;
        // update counter on main queue
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            self.intTrafficIn = self.intTrafficIn + dataSize;
        }];
        // pass everything to processor (UDP is SOCKS option)
        [ProcessorSocks5 socketClientTCP:self.socketClientTCP withData:data withTag:5550 socketHostTCP:self.socketHostTCP socketClientUDP:self.socketClientUDP socketHostUDP:self.socketHostUDP ipString:self.proxyHost];
    }
    
}

// protocol method on successful TCP read
-(void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    // count data
    // get data size
    int dataSize = (int)data.length;
    // increase counters on main queue
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        // if tag from target host
        if ((tag == 5300)||(tag == 1201)||(tag == 1200)) { self.intTrafficIn = self.intTrafficIn + dataSize; }
        // if tag from client
        else if ((tag == 5200)||(tag == 1101)||(tag == 1100)) { self.intTrafficOut = self.intTrafficOut + dataSize; }
    }];

    
    
    
    // access bytes data
    const uint8_t *dataRaw = data.bytes;
    
    // if tag unassigned (==0), determine what is it for
    if (tag == 0) {
        // first byte = 5, means it's SOCKS5
        if (dataRaw[0] == 5)
        {
            // set tag to process SOCKS5 on initial stage (5000)
            tag = 5000;
        }
        // if it's not SOCKS, make sure that target connection does not exist
        else if (!self.socketHostTCP.isConnected)
        {
            // make boolean to track recognition
            BOOL startHTTPbool = false;
            
            // read first 3 bytes from packet as characters
            NSString *checkString = [NSString stringWithFormat:@"%c%c%c", dataRaw[0],dataRaw[1],dataRaw[2]];
            
            // if it's beginning if HTTP request header (ie CONnection, GET or POSt)
            if (([checkString hasPrefix:@"CON"])
                || ([checkString hasPrefix:@"GET"])
                || ([checkString hasPrefix:@"POS"])
                // or socket userdata array exists and has positive 7th bool index
                || ((self.socketClientTCP.userData != nil)&&([self.socketClientTCP.userData[7] boolValue]))
                )
            {
                // set it as recognized HTTP
                startHTTPbool = true;
                
            
            }
            // if data first byte is 77, it's proxy "self check" request from ProxyInstance Check socket
            else if (dataRaw[0] == 77)
            {
                // Compose confirmation packet
                uint8_t dataInt[1];
                // 88 - it's confirmation of success
                dataInt[0] = 88;
                // send packet back to confirm
                [sock writeData: [NSData dataWithBytes:dataInt length:1] withTimeout:1 tag:999];
                // startHTTPbool stays false in this case
                startHTTPbool = false;
                // set tag to 999, do nothing tag
                tag = 999;
            }
            
            // if it's recognized HTTP protocol, set Client Socket HTTP processing tag (1100)
                if (startHTTPbool == true) {
                    tag = 1100;
                }
            
        }
        
    }
    
    
    // TAG BASED PROCESSING....
    
    // tag 5xxx is a SOCKET5 routine
    if ((tag >= 5000)&&(tag < 6000)) {
        // send everything to SOCKS5 processor
        [ProcessorSocks5 socketClientTCP:self.socketClientTCP withData:data withTag:tag socketHostTCP:self.socketHostTCP socketClientUDP:self.socketClientUDP socketHostUDP:self.socketHostUDP ipString:self.proxyHost];

        // HTTP processing on tag 1xxx
    } else if ((tag >= 1100)&&(tag < 1300)) {
        // SEND TO HTTP PROCESSOR
        [ProcessorHTTP processData:data withTag:tag socketClientTCP:self.socketClientTCP socketHostTCP:self.socketHostTCP mutableDataClient:self.httpPacketData mutableDataHost:self.httpPacketDataFromHost];
        
    } else if (tag == 999) {
        // just do nothing
    } else {
        // disconnect everything if case undeclared
        [sock disconnect];
        [self.socketClientTCP disconnect];
    }
    
    
    // FULFILL INTERNAL HTTP REQUESTS...
    
    // check only if its recognized request from client with parsed header in userData
    if ((tag == 1100)&&(self.socketClientTCP.userData != nil)) {
        // process internal things first
        // IF IT IS REQUEST FOR SOCKS5 PROXY SETTINGS (socks.pac)
        if ([self.socketClientTCP.userData[6] isEqualToString:@"/socks.pac"]) {
            
            // body text wrapped in data
            NSData *text = [[NSString stringWithFormat:
                             @"function FindProxyForURL(url, host) { return \"SOCKS %@:%d\"; }",
                             self.proxyHost, self.proxyPort] dataUsingEncoding:NSUTF8StringEncoding];
            // header for body
            NSData *header = [[NSString stringWithFormat:
                               @"%@ 200 OK\r\nContent-Type: application/x-ns-proxy-autoconfig\r\nConnection: close\r\nContent-Length: %lu\r\n\r\n",
                               self.socketClientTCP.userData[5], (unsigned long)text.length] dataUsingEncoding:[NSString defaultCStringEncoding]];
            // compose response in data
            NSMutableData *response = [NSMutableData data];
            // combine all into data response
            [response appendData:header];
            [response appendData:text];
            
            // send response with internal things tag
            [self.socketClientTCP writeData:response withTimeout:10 tag:999];
            
            // release
            text = nil;
            header = nil;
            response = nil;
            
            
            // if it's http.pac settings request
        } else if ([self.socketClientTCP.userData[6] isEqualToString:@"/http.pac"]) {
            
            // body text wrapped in data
            NSData *text = [[NSString stringWithFormat:
                             @"function FindProxyForURL(url, host) { return \"PROXY %@:%d\"; }",
                             self.proxyHost, self.proxyPort] dataUsingEncoding:NSUTF8StringEncoding];
            // compose header for the body
            NSData *header = [[NSString stringWithFormat:
                               @"%@ 200 OK\r\nContent-Type: application/x-ns-proxy-autoconfig\r\nConnection: close\r\nContent-Length: %lu\r\n\r\n",
                               self.socketClientTCP.userData[5], (unsigned long)text.length] dataUsingEncoding:[NSString defaultCStringEncoding]];
            // compose response in data
            NSMutableData *response = [NSMutableData data];
            // combine all into data response
            [response appendData:header];
            [response appendData:text];
            
            // send response with internal things tag
            [self.socketClientTCP writeData:response withTimeout:10 tag:999];
            
            // release
            text = nil;
            header = nil;
            response = nil;
            
            // if it's proxy stop "OFF" request
        } else if ([self.socketClientTCP.userData[6] isEqualToString:@"/proxyoff"]) {
            // on main queue for safety
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                // SET ABORT MARKER
                self.boolAbort = true;
            }];
            // disconnect client
            [self.socketClientTCP disconnect];
        }
    }
    
    // release bytes data pointer
    dataRaw = nil;
}


-(void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    // WE MUST WAIT FOR RESPONSE AFTER EACH WRITE
    if (tag == 999) { [self.socketClientTCP disconnect]; }
    else { [sock readDataWithTimeout:1800 tag:tag]; }
}


// returns status of client connection
-(BOOL)isDisconnected
{
    return self.socketClientTCP.isDisconnected;
}


// creation of new instance
- (instancetype)initWithQueue: (dispatch_queue_t) queue
{
    self = [super init];
    if (self) {
        // Mutable Data for HTTP protocol message
        // Client Message
        self.httpPacketData = [NSMutableData data];
        // Target Host Message
        self.httpPacketDataFromHost = [NSMutableData data];
        
        // Just use the same queue to process all sockets, for better pipelining
        // if separate queues, additional sychronizations will be required and may harm overall stability
        self.queueTCPClient = queue; // dispatch_queue_create("AsyncProxy.queueConnection", DISPATCH_QUEUE_SERIAL);
        self.queueTCPHost = queue;
        self.queueUDPClient = queue;
        self.queueUDPHost = queue;
        
        // INIT SOCKET OBJECTS
        // target host tcp connection
        self.socketHostTCP = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.queueTCPHost];
        // target host udp connection
        self.socketHostUDP = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:self.queueUDPHost];
        // client bind udp socket
        self.socketClientUDP = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:self.queueUDPClient];
        
        // synchronize for additional safety
        @synchronized(queue)
        {
            // Create UDP UserDataArray with compact information about udp connection
            NSMutableArray *userData = [NSMutableArray array];
            [userData addObject:[NSData data]]; // 0 - Address Data
            [userData addObject:[NSMutableData data]]; // 1 - ReturnData Header, packets will be appended, and after write, shrinked
            [userData addObject:[NSNumber numberWithInt:0]]; // 2 - Header Length, ReturnData Will be shrinked till that length
            [userData addObject:@"X"]; // 3 - Host address String
            [userData addObject:[NSNumber numberWithInt:0]]; // 4 - Port address number
            // set dictionary to client's udp socket instance
            self.socketClientUDP.userData = userData;
        }
        
    }
    return self;
}



- (void)updateClientSocket: (GCDAsyncSocket *) socket andHostname: (NSString *) hostString andPort: (int) portNumber
{
    // release old client
    [self.socketClientTCP disconnect];
    self.socketClientTCP = nil;
    // assign new client
    self.socketClientTCP = socket;
    // self.socketClientTCP.delegateQueue = self.queueTCPClient;
    // self.socketClientTCP.delegate = self;
    
    // store host string
    self.proxyHost = hostString;
    // store port number
    self.proxyPort = portNumber;
    // read packet data to start operations
    [self.socketClientTCP readDataWithTimeout:10 tag:0];
}

// system method to release self
-(void)dealloc
{
    [self.socketClientTCP disconnect];
    [self.socketHostTCP disconnect];
    [self.socketClientUDP close];
    [self.socketHostUDP close];
    
    self.socketClientTCP = nil;
    self.socketClientUDP = nil;
    self.socketHostTCP = nil;
    self.socketHostUDP = nil;
    self.queueTCPClient = nil;
    self.queueTCPHost = nil;
    self.queueUDPClient = nil;
    self.queueUDPHost = nil;
    self.httpPacketData.length = 0;
    self.httpPacketData = nil;
    self.httpPacketDataFromHost.length = 0;
    self.httpPacketDataFromHost = nil;
    self.proxyHost = nil;
}


@end
