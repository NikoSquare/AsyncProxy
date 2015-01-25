//
//  ProcessorHTTP.m
//  AsyncProxy
//
//  Created by Nikita Mordasov on 1/10/15.
//  Copyright (c) 2015 Nikita Mordasov. All rights reserved.
//

#import "ProcessorHTTP.h"

@implementation ProcessorHTTP

+(void)processData: (NSData *) data withTag: (long) tag socketClientTCP: (GCDAsyncSocket *) socketClient socketHostTCP: (GCDAsyncSocket *) socketHost mutableDataClient: (NSMutableData *) dataClient mutableDataHost: (NSMutableData *) dataHost
{
    // access fresh data bytes
    const uint8_t *dataRaw = data.bytes;
    
    
    if (tag == 1100) {
        
        // const uint8_t *bdata = data.bytes;
        NSString *checkString = [NSString stringWithFormat:@"%c%c%c", dataRaw[0],dataRaw[1],dataRaw[2]];
        
        // CLEAR BUFFER IF ITR'S A NEW PACKET
        if (([checkString hasPrefix:@"CON"])
            || ([checkString hasPrefix:@"GET"])
            || ([checkString hasPrefix:@"POS"])
            ) {
            // trim data to 0
            dataClient.length = 0;
            
            // nullify user data Array
            socketClient.userData = nil;
        } else {
            // remove last 0 byte, that we add for seamless string conversion
            dataClient.length = dataClient.length - 1;
        }
        
        // APPEND RECEIVED DATA FROM PACKET
        [dataClient appendData:data];
        
        // create 1 byte 0 data
        uint8_t space[1];
        space[0] = 0;
        // append this data at the end of packet to make c-string conversion work propertly
        [dataClient appendBytes:space length:1];
        
        // access raw accumulated message data
        const uint8_t *bufferData = dataClient.bytes;
        
        // SET MARKET OF BODY FIRST BYTE NUMBER (MAY BE OUT OF PACKET LIMIT, IF BODY NOT PRESENT)
        int bodyMarker = -1;
        
        // get current length
        NSUInteger bufferLength = dataClient.length;
        
        // if userData absent
        if (socketClient.userData == nil) {
            // check downloaded data for header completion
            for (int i = 0; i<(bufferLength - 2);i++)
            {
                // FIND LF-CR-LF (10-13-10), TO FIGURE OUT HEADER LAST BYTE NUMBER
                if ((bufferData[i] == 10)&&(bufferData[i+1] == 13)&&(bufferData[i+2] == 10)) {
                    // update body marker setting it to first byte number of body data
                    bodyMarker = i+4; // INCREASED BY 3 TO SET DATA BEGINNING AND 1 TO COVER EXTRA BYTE
                    // read header data to UserData NSArray
                    socketClient.userData = [ProcessorHTTP httpHeaderHostPortBodyFromData:dataClient];
                    // break iteration through message bytes
                    break;
                }
            }
        }
        // in case UserData NSArray is present, means we have information about message
        // IF IT'S CHUNKED DATA FLAG IS TRUE (#3 in NSArray)
        else if ([socketClient.userData[3] boolValue]) {
            // iterate through raw message bytes
            for (int i = 0; i<(bufferLength - 2);i++)
            {
                // to find 2xLF-CR-LF (10-13-10) pieces
                if ((bufferData[i] == 10)&&(bufferData[i+1] == 13)&&(bufferData[i+2] == 10)) {
                    // on first LF-CR-LF appearance, set marker to 1, for further processing
                    if (bodyMarker == -1) { bodyMarker = 1; } // NOW IT'S JUST MARKER, NO BYTE MEANING
                    else if (bodyMarker == 1) {
                        // on second LF-CR-LF appearance, set marker to -2, to avoid further processing
                        bodyMarker = -2;
                        // is host is not connected yet
                        if (!socketHost.isConnected) {
                            // connect to host
                            if (![socketHost connectToHost:socketClient.userData[0] onPort:[socketClient.userData[1] intValue] error:nil])
                            {
                                // in case of failure, disconnect client
                                [socketClient disconnect];
                            }
                        }
                        // trim last "0" byte that we add for c-string conversion
                        dataClient.length = dataClient.length - 1;
                        // send Client message to Target host with wait "request" tag (1200)
                        [socketHost writeData:dataClient withTimeout:15 tag:1200];
                        // set client socket to read state for 30 minutes
                        [socketClient readDataWithTimeout:1800 tag:1100];
                        // nullify message array
                        socketClient.userData = nil;
                        // break iteration
                        break;
                    }
                }
            }
        } else {
            // marker to 1, saying that header is complete, so next code will check Body Data
            bodyMarker = 1;
        }
        
        // if header is present and further processing required (bodyMarker > 0)
        if (bodyMarker > 0) {
            // IF EXTRA DATA IS STILL EXPECTED (HEADER SIZE + BODY SIZE) < ACTUAL (DATA IN BUFFER LESS THAN EXPECTED)
            if (([socketClient.userData[2] intValue] > (dataClient.length - bodyMarker))
                // OR IT'S INCOMPLETE IN CHUNKED MODE
                ||([socketClient.userData[3] boolValue])
                )
            {
                // CONTINUE READING WITH CLIENT "REQUEST" TAG (1100)
                [socketClient readDataWithTimeout:5 tag:1100];
                
            }
            // if body marker <= 0, message is complete
            else {
                // IF IT IS "CONNECT", MEANS HTTP TUNNELING
                if ([socketClient.userData[4] isEqualToString:@"CONNECT"])
                {
                    // CONNECT TO REQUESTED HOST SOCKET
                    if (![socketHost connectToHost:socketClient.userData[0] onPort:[socketClient.userData[1] intValue] error:nil])
                    {
                        // disconnect in case of failure
                        [socketClient disconnect];
                    }
                    
                    // COMPOSE "CONNECT" CONFIRMATION MESSAGE
                    NSString *message = [NSString stringWithFormat:@"%@ 200 OK\r\n\r\n", socketClient.userData[5]];
                    // wrap message into NSData
                    NSData *response = [message dataUsingEncoding:[NSString defaultCStringEncoding]];
                
                    
                    // self.httpPacketData.length = self.httpPacketData.length - 1;
                    
                    // SEND CONFIRMATION TO CLIENT WITH TAG 1101, TO DIRECT TRANFER OF DATA PACKETS (HTTP TUNNELING)
                    [socketClient writeData:response withTimeout:15 tag:1101];
                }
                // ELSE IF IT'S "REQUEST" GET OR POST, AND NOT INTERNAL THING
                else if (
                        (![socketClient.userData[6] isEqualToString:@"/socks.pac"])
                        &&(![socketClient.userData[6] isEqualToString:@"/http.pac"])
                        &&(![socketClient.userData[6] isEqualToString:@"/proxyoff"])
                ) {
                        
                    
                    // IF TARGET HOST NOT CONNECTED
                    if (!socketHost.isConnected) {
                        // connect to host
                        if (![socketHost connectToHost:socketClient.userData[0] onPort:[socketClient.userData[1] intValue] error:nil])
                        {
                            // disconnect client on failure
                            [socketClient disconnect];
                        }
                        
                    }
                    
                    // CUT LAST ZERO SPACE
                    dataClient.length = dataClient.length - 1;
                    // WRITE TO HOST
                    [socketHost writeData:dataClient withTimeout:10 tag:1200];
                    // CONTINUE READ CLIENT
                    [socketClient readDataWithTimeout:1800 tag:1100];
                    socketClient.userData = nil;
                }
            }
            
        } else if (bodyMarker == -1) {
            // JUST CONTINUE READING TO COMPLETE HEADER
            [socketClient readDataWithTimeout:15 tag:1100];
        }
        
    
    }
    // IF IT'S REQUEST RESPONSE FROM TARGET HOST
    else if (tag == 1200) {
  
        // if current packet starts with "HTTp..." reset to new message
        if ([[NSString stringWithFormat:@"%c%c%c", dataRaw[0],dataRaw[1],dataRaw[2]] hasPrefix:@"HTT"]) {
            dataHost.length = 0;
            socketHost.userData = nil;
        }
        // else, continue to build existing message
        else {
            // REMOVE SPACE (last byte with 0)
            dataHost.length = dataHost.length - 1;
        }
        // append to message
        [dataHost appendData:data];
        
        // ADD SPACE at the end of message to ease c-string conversion
        uint8_t space[1];
        space[0] = 0;
        [dataHost appendBytes:space length:1];
        // access raw bytes of message
        const uint8_t *bufferData = dataHost.bytes;
        // init bodyMarker helper int
        int bodyMarker = -1;
        // calculate current message length
        NSUInteger bufferLength = dataHost.length;
        
        // IF HEADER IS NOT FOUND, CHECK AVAILABILITY
        if (socketHost.userData == nil) {
            for (int i = 0; i<(bufferLength - 2);i++)
            {
                // FIND LF-CR-LF (10-13-10)
                if ((bufferData[i] == 10)&&(bufferData[i+1] == 13)&&(bufferData[i+2] == 10)) {
                    // set body marker to first byte of body data (possible body data)
                    bodyMarker = i+4; // INCREASED BY 3 TO SET DATA BEGINNING AND 1 TO COVER EXTRA BYTE
                    // read header from message to userData NSArray
                    socketHost.userData = [ProcessorHTTP httpHeaderHostPortBodyFromData:dataHost];
                    // break iteration
                    break;
                }
            }
            
        }
        // ELSE IF IN CHUNKED DATA MODE
        else if ([socketHost.userData[3] boolValue]) {
            // PACKET MUST CONTAIN 2(two) LF-CR-LF (10-13-10)
            for (int i = 0; i<(bufferLength - 2);i++)
            {
                // looking for LF-CR-LF (10-13-10)
                if ((bufferData[i] == 10)&&(bufferData[i+1] == 13)&&(bufferData[i+2] == 10)) {
                    // on first appearance, set positive value as incomplete state
                    if (bodyMarker == -1) bodyMarker = 1; // NOW IT'S JUST MARKER, NO BYTE MEANING
                    else if (bodyMarker == 1) {
                        // on second appearance set negative value as complete message state
                        bodyMarker = -2;
                        // DATA IS COMPLETE, PROCESS
                        // SHRINK LAST ZERO
                        dataHost.length = dataHost.length - 1;
                        // pass complete message to client with client "request" tag (1100)
                        [socketClient writeData:dataHost withTimeout:10 tag:1100];
                        // continue read from host for 30 minutes
                        [socketHost readDataWithTimeout:1800 tag:1200];
                        // RESET DICTIONARY
                        socketHost.userData = nil;
                        // break processing raw message
                        break;
                    }
                }
            }
        }
        // ELSE IF IN REGULAR DATA MODE
        else {
            // JUST SET MARKET TO ENABLE PROCESSING
            bodyMarker = 1;
        }
        
        // once body marker positive, message is incomplete, continue processing
        if (bodyMarker > 0) {
         
            // IF EXTRA DATA IS STILL EXPECTED
            if (([socketHost.userData[2] intValue] > (dataHost.length - bodyMarker))
                // CHUNK BOOL(3) IS TRUE
                ||(([socketHost.userData[3] boolValue]))
                )
            {
                // just continue reading
                [socketHost readDataWithTimeout:10 tag:1200];
            }
            // if body data length is complete
            else {
                // SHRINK LAST ZERO
                dataHost.length = dataHost.length - 1;
                // PASS PACKET TO CLIENT WITH REQUEST TAG (1100)
                [socketClient writeData:dataHost withTimeout:10 tag:1100];
                // READ HOST AT THE SAME TIME WITH REQUEST TAG (1200) FOR 30 MINUTES
                [socketHost readDataWithTimeout:1800 tag:1200];
                // RESET DICTIONARY
                socketHost.userData = nil;
            }
            
            
        }
        // negative marker means just more read required (or no header info available yet)
        else if (bodyMarker == -1) {
            // just read from host with target "request" tag (1200)
            [socketHost readDataWithTimeout:10 tag:1200];
        }
    
    }
    // 1101 is a "CONNECTION" tag for HTTP tunneling
    else if (tag == 1101) {
        // REDIRECT PACKET AND READ FOR MORE
        [socketHost writeData:data withTimeout:15 tag:1201];
        [socketClient readDataWithTimeout:1800 tag:1101];
    } else if (tag == 1201) {
        // REDIRECT PACKET AND READ FOR MORE
        [socketClient writeData:data withTimeout:15 tag:1101];
        [socketHost readDataWithTimeout:1800 tag:1201];
    }
}

+(NSArray *)httpHeaderHostPortBodyFromData: (NSMutableData *) data
{
    NSString *headerText = [NSString stringWithCString:data.bytes encoding:[NSString defaultCStringEncoding]];
    
    NSArray *headerStrings = [headerText componentsSeparatedByString:@"\n"];
    
    
    bool chunked = false;
    //int dataCorrection = 0; // HOW MUCH DATA TRUNCATED DURING CUT
    int port = 80; // ACTUAL PORT
    int dataBodyLength = 0; // LENGTH OF DATA BLOCK AFTER CLRF
    NSString *host = @""; // ACTUAL HOST
    NSString *command = @""; // REQUEST COMMAND (GET/POST/CONNECT)
    NSString *protocol = @""; // PROTOCOL VERSION (HTTP/1.0, HTTP/1.1)
    NSString *path = @""; // PATH FROM HOST ROOT
    
    
    
    int count = 0;
    
    for (NSString *headerLine in headerStrings) {
        
        // SEPARATE FIRST STRING: "0[COMMAND] 1[SCHEME//HOST:PORT/PATH] 2[HTTP.VER]"
        if (count == 0) {
            NSArray *connectCommand = [headerLine componentsSeparatedByString:@" "];
            // REQUEST COMMAND
            command = [connectCommand[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            // IF IT'S NOT A RESPONSE (RESPONSE STARTS WITH [HTTP.VER]), PROCESS REQUEST TO ESTABLISH PROPER PROXY CONNECTION
            if (![command hasPrefix:@"HTTP"]) {
            
            // PROTOCOL VERSION STRING
            protocol = [connectCommand[2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            // PROCESS HOST AND REPLACE IT WITH NEW ONE
            
            // FIND COMPONENETS 1[SCHEME://HOST:PORT/PATH] SEPARATED BY "//"
            
            NSString *pathComponent = [connectCommand[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            // IF :// is present, assume that it's fully qualified
            if ([pathComponent containsString:@"://"]) {
            NSURL *uri = [NSURL URLWithString:connectCommand[1]];
                if (uri.port.intValue > 0) port = uri.port.intValue;
                host = uri.host;
                path = uri.path;
                
            // IF it's just domain and port [domain:port] without path
            } else if (![pathComponent containsString:@"/"]) {
                NSArray *uriParts = [pathComponent componentsSeparatedByString:@":"];
                if ([uriParts[1] intValue] > 0) port = [uriParts[1] intValue];
                host = uriParts[0];
                path = @"/";
            // IF it's just path, non-proxy request
            } else if ([pathComponent hasPrefix:@"/"]) {
                path = pathComponent;
                host = @"localhost";
            }
            
            //~NSLog(@"RESOLVED HOST:%@ PORT:%d PATH:%@", host, port, path);
            }
            
            /*
            NSArray *hostParts = [connectCommand[1] componentsSeparatedByString:@"//"];
            
            // IF SEPARATION ON 2, SET INDEX TO HOST PART
            int indexProtocol = -1;
            if (hostParts.count == 2)
            {
                indexProtocol = 1;
            } else {
                indexProtocol = 0;
            }
            
            // SEPARATE HOST PART FROM PATH
            NSArray *hostPartsMore = [hostParts[indexProtocol] componentsSeparatedByString:@"/"];
            
            // SET INITIAL PATH STRING
            path = @"";
            
            // BOOL OF SUBPATH EXISTENCE
            BOOL hasSubAddress = false;
            // IF PATH EXIST (MORE THAN 1)
            if (hostPartsMore.count > 1)
            {
                for (int i = 1; i<hostPartsMore.count;i++)
                {
                    // ADD ALL PARTS WITH "/"
                    path = [path stringByAppendingString:@"/"];
                    path = [path stringByAppendingString:hostPartsMore[i]];
                }
                
                hasSubAddress = true;
                // IF ONLY ONE PIECE, LEAVE ONLY "/" FOR ROOT
            } else { path = [path stringByAppendingString:@"/"]; }
            
            // CHECK FOR PORT AND HOST NAME
            port = 80; // DEFAULT HTTP PORT

            // SEPARATE HOST PART ":" TO FIND PORT
            NSArray *hostPartsMain = [hostPartsMore[0] componentsSeparatedByString:@":"];
            // HOST NAME ALWAYS AT 0 INDEX
            host = [hostPartsMain[0] stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
            // IF MORE THAN ONE PIECE, PORT AT INDEX 1
            if (hostPartsMain.count > 1)
            {
                port = [hostPartsMain[1] intValue];
            }
            
            
            */
            
           // //~NSLog(@"%@ HOSTNAME: %@ PORT:%d (%@) PROTOCOL:%@", connectCommand[0], host, port, path, connectCommand[2]);
        } else if ([headerLine containsString:@": "]) {
            // HERE JUST TRY TO FIND OTHER IMPORTANT KEYS LIKE DATA SIZE
            NSArray *headerValue = [headerLine componentsSeparatedByString:@": "];
            if (headerValue.count == 2) {
            if ([headerValue[0] isEqualToString:@"Content-Length"])
            {
                dataBodyLength = [headerValue[1] intValue];
                //~NSLog(@"EXPECT CONTENT:%d bytes", dataBodyLength);
            }
            else if ([headerValue[0] isEqualToString:@"Transfer-Encoding"])
            {
                if ([headerValue[1] containsString:@"chunked"]) {
                    chunked = true;
                    //~NSLog(@"CHUNKED!");
                }
            }
            }
        }
        
        
        count++;
    }
    
    
    // FIND RANGE TO REPLACE FULL PATH WITH REALTIVE, ONLY IF ITS REQUEST
    if (![command hasPrefix:@"HTTP"]) {
    NSRange uriRange;
    int start = -1;
    const uint8_t *dataRaw = data.bytes;
    for (int byteNo = 0; byteNo < data.length; byteNo++)
    {
        // FIND SPACES (32)
        if (dataRaw[byteNo] == 32) {
            if (start == -1) start = byteNo;
            else {
                uriRange = NSMakeRange((start + 1), ((byteNo - start) - 1));
                start = -2;
                break;
            }
            // IF NEW LINE (10) IS REACHED, NO REASON TO LOOK FURTHER
        } else if (dataRaw[byteNo] == 10) break;
    }
    
    // REPLACE PATH DATA ONLY IF RANGE WAS SUCCESSFULLY FOUND
    if (start == -2) {
    NSData *pathData = [path dataUsingEncoding:[NSString defaultCStringEncoding]];
    [data replaceBytesInRange:uriRange withBytes:pathData.bytes length:pathData.length];
    }
    }
    
    return [NSArray arrayWithObjects:
            host, // 0-HOSTNAME
            [NSNumber numberWithInt:port], // 1-PORT NUMBER
            [NSNumber numberWithInt:dataBodyLength], // 2-DATA LENGHTH
            [NSNumber numberWithBool:chunked], // 3-CHUNKED TRANSCODING BOOL
            command, // 4-COMMAND
            protocol, // 5-PROTOCOL
            path, // 6-PATH AFTER HOST
            nil];
}


@end
