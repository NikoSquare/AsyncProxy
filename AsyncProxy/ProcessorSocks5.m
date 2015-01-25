//
//  ProcessorSocks5.m
//  AsyncProxy
//
//  Created by Nikita Mordasov on 1/4/15.
//  Copyright (c) 2015 Nikita Mordasov. All rights reserved.
//

#import "ProcessorSocks5.h"

@implementation ProcessorSocks5


// class method to prosess recognized SOCKS5
+(void)socketClientTCP: (GCDAsyncSocket *) socket withData: (NSData *) data withTag: (long) tag socketHostTCP: (GCDAsyncSocket *) socketHost socketClientUDP: (GCDAsyncUdpSocket *) udpSocket socketHostUDP: (GCDAsyncUdpSocket *) udpSocketHost ipString: (NSString *) ipString
{
    /*
     PROTOCOL STAGES:
     
     STAGE TAG 5000. Greeting processing:
     
     READ FROM CLIENT 3 fields packet from client
     [00] = PROTOCOL VERSION, MUST BE 5
     [01] = NUMBER OF AUTH METHODS AVAILABLE
     [02] = ALL METGHODS, METHOD PER BYTE:
     The values currently defined for METHOD are:
     o  X'00' NO AUTHENTICATION REQUIRED
     o  X'01' GSSAPI
     o  X'02' USERNAME/PASSWORD
     o  X'03' to X'7F' IANA ASSIGNED
     o  X'80' to X'FE' RESERVED FOR PRIVATE METHODS
     o  X'FF' NO ACCEPTABLE METHODS
     
     WRITE TO CLIENT 2 bytes
     [00] = PROTOCOL VERSION, MUST BE 5
     [01] = METHOD OF AUTH MARKER, ALWAYS 0 (NO AUTH)
     SET STAGE TO 10
     
     STAGES TAG 5001 TO 5099 - RESERVED FOR AUTHRIZATION NEGOTIATIONS
     
     STAGE TAG 5100. CONNECTION REQUEST:
     
     READ FROM CLIENT 6 fields packet:
     [00]  VER    protocol version: X'05'
     [01]  CMD:
     CONNECT X'01'
     BIND X'02'
     UDP ASSOCIATE X'03'
     [02]  RSV    RESERVED [0x00]
     [03] ATYP   address type of following address
     IP V4 address: X'01'
     DOMAINNAME: X'03'
     IP V6 address: X'04'
     [04] DST.ADDR       desired destination address (01 = 4bytes, 03 = 1byte with length in next bytes, 04 = 16bytes)
     [..] DST.PORT desired destination port in network octet order 2bytes
     
     FOR CONNECT REQUEST:
     ESTABLISH NEW TCP SOCKET WITH DESTINATION SERVER WITH SUCCESS
     WRITE TO CLIENT:
     [00] - VERSION 5
     [01] - SUCCESS 0
     [02] - RESERVED 0
     [03] - ADDRESS TYPE ALWAYS SET ipv4 01
     [04] - 4bytes of ipv4
     [08] - 2bytes of port
     
     SET STAGE TO 5200+ = NORMAL OPERATION, JUST PASS DATA BACK AND FORTH
     
     
     */
    
    
    
    // EXTRACT CURRENT STAGE PHASE
    
    // prepare error pointer
    NSError *error = nil;
    
    // get raw packet data pointer
    const uint8_t *clientBuffer = data.bytes;
    
    // depending what tag we got
    switch (tag) {
            // 5000 = initial negotiation, first message from Client
        case 5000:
        {
            // IF IT'S CONNECTION REQUEST (2nd byte must be "1")
            if (clientBuffer[1] == 1) {
                // SET TAG TO CONNECTION REQUEST STAGE (5100)
                tag = 5100;
                // compose response packet
                uint8_t buf[2];
                buf[0] = 0x05; // VERSION
                buf[1] = 0x00; // NO AUTHORIZATION SUPPORTED
                // send response packet to client
                [socket writeData:[NSData dataWithBytes:buf length:2] withTimeout:15 tag:tag];
                
            }
            // if it's not fit into protocol
            else {
                // disconnect
                [socket disconnect];
                break;
            }
        }
            break;
        
            // 5100 = second message from client with connection data request
        case 5100:
        {
            // 2nd byte is "1" for TCP connection request
            if (clientBuffer[1] == 1) {
                
                // prepare store pointers for host and port to connect
                NSString *domainAddress = nil;
                uint16_t port = 0;
                
                // 4th byte is an address format
                // "1" is an IP
                if (clientBuffer[3] == 1) {
                    // extract ip, it goes next after address type byte (5th byte)
                    in_addr_t ipaddr = ntohl(*(uint32_t*)&clientBuffer[4]);
                    // place in into host string
                    domainAddress = [NSString stringWithFormat:@"%d.%d.%d.%d",
                                     0xff&(ipaddr>>24),
                                     0xff&(ipaddr>>16),
                                     0xff&(ipaddr>>8),
                                     0xff&(ipaddr>>0)
                                     ];
                    // extract port, goes after 4 bytes of ip (10th byte)
                    port = ntohs(*(ushort *)&clientBuffer[9]);
                    
                    // "3" is a domain name
                } else if (clientBuffer[3] == 3) {
                    // byte next after format (5th) contain length of hostname cstring
                    size_t nameSize = clientBuffer[4];
                    // read range right after length byte into host string (6th + length bytes range)
                    domainAddress = [NSString stringWithCString:[data subdataWithRange:NSMakeRange(5, nameSize)].bytes encoding:[NSString defaultCStringEncoding]];
                    // after host cstring goes 2 bytes of port
                    port = ntohs(*(ushort *)&clientBuffer[(5 + nameSize)]);
                    
                    // "2" is ipV6 but we do not support it
                } else {
                    // just disconnect
                    [socket disconnect];
                    break;
                }
                
            // CONNECT INTERNET SOCKET TO REQUESTED HOST ADDRESS
            if (![socketHost connectToHost:domainAddress onPort:port error:&error])
            {
                // in case of failure, disconnect
                [socket disconnect];
                break;
            }
            
            // SET TAG TO CLIENT-PROXY PROCESING MODE (5200), with that flag data will be passed without processing
            tag = 5200;
            
            // COMPOSE CONFIRMATION RESPONSE TO CLIENT
            // EXTRACT ACTUAL ADDRESS AND PORT FROM SUCCESSFULL CONNECTION
            struct sockaddr *addressConnected = (struct sockaddr*)[socketHost connectedAddress].bytes;
                // here's port
            uint16_t portConnected = [socketHost connectedPort];
            // make it into right format
            uint32_t addressConnectedNetwork = htonl((uint32_t)addressConnected->sa_data);
            uint16_t portConnectedNetwork = htons(portConnected);
            
            // WRITE DATA TO RESPONSE PACKET
            uint8_t buf[10];
            buf[0] = 5; // VERSION
            buf[1] = 0; // SUCCESS
            buf[2] = 0; // RESERVED
            buf[3] = 0x01; // ADDRESS TYPE 1=ipV4, always use ip address for clarity
            buf[4] = (uint8_t)(addressConnectedNetwork>>0); // ipv4-1
            buf[5] = (uint8_t)(addressConnectedNetwork>>8); // ipv4-2
            buf[6] = (uint8_t)(addressConnectedNetwork>>16); // ipv4-3
            buf[7] = (uint8_t)(addressConnectedNetwork>>24); // ipv4-4
            buf[8] = (uint8_t)(portConnectedNetwork>>0); // port-1
            buf[9] = (uint8_t)(portConnectedNetwork>>8); // port-2
            
            // SEND CONFIRMATION PACKET TO CLIENT
            [socket writeData:[NSData dataWithBytes:buf length:10] withTimeout:10 tag:tag];
            
            
            // in request byte (2nd) is "3", it's UDP bind request
            } else if (clientBuffer[1] == 3) {
                
                // BIND UDP SOCKET, TO SAME PORT WHICH CLIENT IS USING FOR CURRENT TCP
                if (![udpSocket bindToPort:socket.localPort error:&error])
                {
                    // disconnect on failure
                    [socket disconnect];
                    break;
                }
                // start receiving mode for UDP
               if (![udpSocket beginReceiving:nil]) {
                    //dosconnect on failure
                   [udpSocket close];
                   [socket disconnect];
                   break;
               }
                // get connected UDP port, just for double check
                uint16_t portConnected = udpSocket.localPort_IPv4;
                
                // SET TAG TO CLIENT-PROXY TCP-UDP BIND PROCESING MODE (5150)
                tag = 5150; // this tag will do nothing, but still recognized as SOCKS5
                // make ip data array
                uint8_t ipTemp[4];
                // get ip numbers from proxy ip address string
                NSArray *ipArray = [ipString componentsSeparatedByString:@"."];
                // set numbers into ip data array
                for (int i = 0; i<ipArray.count; i++)
                {
                    // convert numbers into int values
                    ipTemp[i] = ((NSString *)ipArray[i]).intValue;
                }
                // prepare complete ip
                uint32_t ipTempLong = *(uint32_t*)ipTemp;
                // prepare port
                uint16_t portConnectedNetwork = htons(portConnected);
                
                // WRITE DATA TO RESPONSE PACKET
                uint8_t buf[10];
                buf[0] = 5; // VERSION
                buf[1] = 0; // SUCCESS
                buf[2] = 0; // RESERVED
                buf[3] = 0x01; // ADDRESS TYPE 1=ipV4
                buf[4] = (uint8_t)(ipTempLong>>0); // ipv4-1
                buf[5] = (uint8_t)(ipTempLong>>8); // ipv4-2
                buf[6] = (uint8_t)(ipTempLong>>16); // ipv4-3
                buf[7] = (uint8_t)(ipTempLong>>24); // ipv4-4
                buf[8] = (uint8_t)(portConnectedNetwork>>0); // port-1
                buf[9] = (uint8_t)(portConnectedNetwork>>8); // port-2
                
                // SEND UDP CONFIRMATION PACKET BACK TO CLIENT
                [socket writeData:[NSData dataWithBytes:buf length:10] withTimeout:10 tag:tag];
                
            }
        }
            break;
            
           // 5150 - it's open TCP connection for udp bind
        case 5150:
        {
            //nothing really required
        }
            break;
            
            // 5500 - this is UDP message from client
        case 5500:
        {
                // IF CONNECTION WITH UDP IS NOT ESTABLISHED
                if (udpSocketHost.isClosed) {
                    
                    // CHECK UDP HEADER FIELDS
                    if (
                        // first two bytes must be "0" as reserved
                        ((clientBuffer[0] != 0)||(clientBuffer[1] != 0))
                        // 3rd byte must be 0, its fragmentation, 0 == no fragmentation (we do not support fragmentation)
                        || (clientBuffer[2] != 0)
                        )
                    {
                        // if requirement not met, just let it go, do nothing
                        break;
                    }
                    
                    // READ ADDRESS AND PORT TO CONNECT
                    NSString *domainAddress = nil;
                    uint16_t port = 0;
                    // address length in bytes
                    int addressLength = 0;
                    
                    // IF ADDRESS IS ipv4, 4th byte is "1"
                    if (clientBuffer[3] == 1) {
                        // in this case lenth always 4 bytes
                        addressLength = 4;
                        // read ip4 address
                        in_addr_t ipaddr = ntohl(*(uint32_t*)&clientBuffer[4]);
                        // process into nsstring
                        domainAddress = [NSString stringWithFormat:@"%d.%d.%d.%d",
                                         0xff&(ipaddr>>24),
                                         0xff&(ipaddr>>16),
                                         0xff&(ipaddr>>8),
                                         0xff&(ipaddr>>0)
                                         ];
                        // read port at byte 8th
                        port = ntohs(*(ushort *)&clientBuffer[8]);
                        
                        // IF ADDRESS IS DOMAIN NAME, 4th byte is "3"
                    } else if (clientBuffer[3] == 3) {
                        // read name length
                        size_t nameSize = clientBuffer[4];
                        // set address lenth after name data
                        addressLength = (int)nameSize + 1;
                        // read address into string
                        domainAddress = [NSString stringWithCString:[data subdataWithRange:NSMakeRange(5, nameSize)].bytes encoding:[NSString defaultCStringEncoding]];
                        // read port 2bytes after address
                        port = ntohs(*(ushort *)&clientBuffer[(5 + nameSize)]);
                        
                        // IF ADDRESS IS ipV6, do not support that
                    } else {
                        //just disconnect
                        [socket disconnect];
                        break;
                    }
                    
                    
                    // SET FIRST BYTE OF DATA by adding address length to header size (6bytes: 4 bytes of header + 2 bytes of port)
                    addressLength = 6 + addressLength;
                    
                    // we use UDP Client's socket to store connection information in UserData
                    // save header block into NSMutableData in UserData mutable array 2nd cell
                    // first trim all data from mutable data
                    ((NSMutableData *)udpSocket.userData[1]).length = 0; // REMOVE ALL DATA
                    // then append header by copying range from original nsdata packet
                    [udpSocket.userData[1] appendData:[data subdataWithRange:NSMakeRange(0, addressLength)]]; // APPEND HEADER
                    // save header length nsnumber into UserData mutable array 3rd cell
                    [udpSocket.userData setObject:[NSNumber numberWithInt:addressLength] atIndex:2]; // SAVE HEADER LENGTH
                    
                    
                // CONNECT UDP TO HOST
                if (![udpSocketHost connectToHost:domainAddress onPort:port error:&error])
                {
                    //disconnect on failure
                    [socket disconnect];
                    break;
                }
                    
                    
                    // SET HOST ADDRESS DATA into UserData mutable array
                    [udpSocket.userData setObject:domainAddress atIndexedSubscript:3];
                    [udpSocket.userData setObject:[NSNumber numberWithInt:port] atIndexedSubscript:4];
                    
                    
                    }
            
        
        // send message to target host through udp target socket
        [udpSocketHost sendData:[data subdataWithRange:NSMakeRange(((NSNumber *)udpSocket.userData[2]).intValue, (data.length - ((NSNumber *)udpSocket.userData[2]).intValue))] withTimeout:10 tag:0];
          
        }
            break;
            
        // 5550 - UDP message from target host, udp taget host socket
        case 5550:
        {
            // trim NSMutableData in client's UserData array to length on header (we must keep original header)
            ((NSMutableData *)udpSocket.userData[1]).length = ((NSNumber *)udpSocket.userData[2]).intValue;
            // append full message from host
            [((NSMutableData *)udpSocket.userData[1]) appendData:data];
            // send combined into NSMutableData message to Client
            [udpSocket sendData:((NSMutableData *)udpSocket.userData[1]) toAddress:((NSData *)udpSocket.userData[0]) withTimeout:10 tag:0];
        }
            break;
            
        // 5200 - simple TCP pass from client to host
        case 5200:
        {
            
            // SET TAG TO PROXY-INTERNET CHANNEL MODE (5300)
            [socketHost writeData:data withTimeout:10 tag:5300];
            // CONTINUE READING DATA FROM CLIENT WITH 30 MINUTES TIMEOUT
            [socket readDataWithTimeout:1800 tag:5200];
            
            
        }
            break;
            
        // 5300 -simple pass TCP data from host to client
        case 5300:
        {
            // SET TAG TO CLIENT-PROXY PROCESING MODE (5200)
            [socket writeData:data withTimeout:10 tag:5200];
            // CONTINUE READING DATA FROM INTERNET WITH 30 MINUTES TIMEOUT
            [socketHost readDataWithTimeout:1800 tag:5300];
        }
            break;
            
        // default is a violation of protocol
        default:
        {
            // IF SOMETHING UNUSUAL, JUST DISCONNECT
            [socket disconnect];
        }
            break;
    }
    
    
    
    
}

@end
