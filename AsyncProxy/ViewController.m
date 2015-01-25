//
//  ViewController.m
//  AsyncProxy
//
//  Created by Nikita Mordasov on 1/1/15.
//  Copyright (c) 2015 Nikita Mordasov. All rights reserved.
//
// THIS IS CUSTOMIZED VIEW CONTROLLER CLASS
// TO RUN APP ON MAC, YOU MIGHT CONSIDER TO FIX VIEWS AND VIEW CONTROLLER

#import <AVFoundation/AVFoundation.h>
#import "ViewController.h"
#import "ProxyInstance.h"
#import "MenuView.h"


@interface ViewController ()
// PLAYER TO PLAY SILENCE IN BACKGROUND
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
// INSTANCE OF PROXY-SERVER NSOBJECT CLASS
@property (nonatomic, strong) ProxyInstance *proxyInstance;
// VISUAL MENU UIVIEW CLASS
@property (nonatomic, strong) MenuView *viewMenu;
// TIMER TO EXECUTE ROUTINE METHOD EVERY SECOND
@property (nonatomic, strong) NSTimer *timerObject;
// Queue for ProxyInstance, all connections will be processed on that queue
@property (nonatomic, strong) dispatch_queue_t queueProxyInstance;
@end

@implementation ViewController
@synthesize audioPlayer = _audioPlayer;
@synthesize proxyInstance = _proxyInstance;
@synthesize timerObject = _timerObject;
@synthesize viewMenu = _viewMenu;
@synthesize queueProxyInstance = _queueProxyInstance;



// ON/OFF UISWITCH TRIGGERED METHOD
-(void)enablerSwitchAction
{
    
    // MAKE IT MAIN QUEUE FOR SAFETY
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        // IF SWITCH IS ON
    if (self.viewMenu.switchStarter.on)
    {
        // DISABLE USER EDITS
        [self.viewMenu disableInput];
        // SHOW RENSPONSE IN STATUS UILABEL
        self.viewMenu.labelStatus.text = @"STARTING PROXY...";
        // START PLAYBACK TO MAINTAIN BACKGROUND RUN INFINITLY
        [self.audioPlayer play];
        // FIRE TIMER TO RUN SELECTOR METHOD EVERY SECOND
        self.timerObject = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timerAction) userInfo:nil repeats:true];
            // SHOW NETWORK ACTIVITY
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:true];
            // Disable device sleep mode
            [UIApplication sharedApplication].idleTimerDisabled = true;
            // Enable proximity sensor
            [UIDevice currentDevice].proximityMonitoringEnabled = true;
        
            // START PROXY ITSELF ON PROXY QUEUE
        dispatch_apply(1, self.queueProxyInstance, ^(size_t i) {
            //NSLog(@"DISPATCH: %zu", i);
            self.proxyInstance = [[ProxyInstance alloc] initWithPort:self.viewMenu.textPort.text.intValue andHost:self.viewMenu.textIp.text onQueue:self.queueProxyInstance];
        });
        /*
            [[NSOperationQueue new] addOperationWithBlock:^{
                self.proxyInstance = [[ProxyInstance alloc] initWithPort:self.viewMenu.textPort.text.intValue andHost:self.viewMenu.textIp.text];
            }];*/
        //~NSLog(@"SWITCH ON");
    }
    else {
        // SET STATUS ONLY IF WAS TRIGGERED BY HAND (INSTANCE INSTANCE POINTER IS NOT NULL IF ITS UISWITCH CALL)
        if (self.proxyInstance) { self.viewMenu.labelStatus.text = @"PROXY OFFLINE"; }
        // DESTROY TIMER LOOP
            [self.timerObject invalidate];
        // NULLIFY TIMER TO BOOST MEMORY REFRESH
            self.timerObject = nil;
        // STOP PLAYBACK
            [self.audioPlayer stop];
        // NULLIFY PROXY INSTANCE, SO IT WILL BE DEALLOCATED BY SYSTEM
            self.proxyInstance = nil;
        // ENABLE EDITING IN MENU
            [self.viewMenu enableInput];
            // HIDE NETWORK ACTIVITY
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:false];
            // Enable device sleep mode
            [UIApplication sharedApplication].idleTimerDisabled = false;
            // Disable proximity sensor (public as of 3.0)
            [UIDevice currentDevice].proximityMonitoringEnabled = false;
        
        //~NSLog(@"SWITCH OFF");
    
    }
    }];
}



// TIMER RUNS THIS METHOD EVERY SECOND TO PROCESS CHANGES
-(void)timerAction {
    // //~NSLog(@"TIMER ACTION");
    // MAKE SURE TO RUN ON MAIN QUEUE FOR SAFETY (NOTHING HEAVY)
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    // UPDATE PROXY STATE TO STATUS LABEL
    self.viewMenu.labelStatus.text = self.proxyInstance.statusString;
    
    // IF SWITCH IS ON (JUST DOUBLE CHECK THAT USER WANT IT TO WORK)
    if (self.viewMenu.switchStarter.on) {
        
        // IF PORT IS ZERO, MEANS FAILURE, STOP ALL (PORT MUST BE VALID IF OPERATIONS ARE REGULAR)
        if (self.proxyInstance.port <= 0) {
                //~NSLog(@"FAILURE");
            // SET SWITCH TO OFF STATE BY CODE
                self.viewMenu.switchStarter.on = false;
            // NULLIFY PROXY INSTANCE POINTER, SO SYSTEM DEALLOCATE IT
                self.proxyInstance = nil;
            // RUN UISWITCH METHOD BY CODE
                [self enablerSwitchAction];
        
        // IF PORT IS VALID, PROCESS WITH ROUTINE
        } else {
            // CHECK THAT MUSIC IS PLAYING
            if (!self.audioPlayer.isPlaying) {
                // if not, start playing
                [self.audioPlayer play];
            }
            
            
                // UPDATE PROXY INSTANCE STATISTIC VARIABLES BY SPECIAL METHOD
                [self.proxyInstance updateTraffic];
                // IF "ABORT" BOOLEAN IS POSITIVE, TRIGGET OFF
                if (self.proxyInstance.boolAbort == true) {
                    //~NSLog(@"ABORT");
                    // SET SWITCH TO OFF STATE BY CODE
                    self.viewMenu.switchStarter.on = false;
                    // NULLIFY PROXY INSTANCE POINTER, SO SYSTEM DEALLOCATE IT
                    self.proxyInstance = nil;
                    // PRESENT STATUS INDICATING BOOL TRIGGER INVOLVEMENT (DISABLED BY LINK)
                    self.viewMenu.labelStatus.text = @"PROXY OFFLINE\n(REMOTELY DISABLED)";
                    // RUN UISWITCH METHOD BY CODE
                    [self enablerSwitchAction];
                    
                // IF "ABORT" BOOLEAN IS NEGATIVE, UPDATE USER MENU WITH INFORMATION
                } else {
                // SHOW TRAFFIC BY PROCESSING NUMBERS AS NSSTRINGS
                    NSString *stringIn = [NSString stringWithFormat:@"%d", self.proxyInstance.intTrafficIn];
                    // SET SEPARATORS FOR INBOUND PROXY EXTERNAL TRAFFIC
                    if (self.proxyInstance.intTrafficIn >= 1000) { stringIn = [stringIn stringByReplacingCharactersInRange:NSMakeRange(stringIn.length - 3, 0) withString:@" "]; }
                    if (self.proxyInstance.intTrafficIn >= 1000000) { stringIn = [stringIn stringByReplacingCharactersInRange:NSMakeRange(stringIn.length - 7, 0) withString:@" "]; }
                    // SET SEPARATORS FOR OUTBOUND PROXY EXTERNAL TRAFFIC
                    NSString *stringOut = [NSString stringWithFormat:@"%d", self.proxyInstance.intTrafficOut];
                    if (self.proxyInstance.intTrafficOut >= 1000) { stringOut = [stringOut stringByReplacingCharactersInRange:NSMakeRange(stringOut.length - 3, 0) withString:@" "]; }
                    if (self.proxyInstance.intTrafficOut >= 1000000) { stringOut = [stringOut stringByReplacingCharactersInRange:NSMakeRange(stringOut.length - 7, 0) withString:@" "]; }
                    
                // UPDATE CURRENT PORT TEXT FIELD, IN CASE OF "AUTO", ACTUAL NUMBER WILL BE PRESENTED
                self.viewMenu.textPort.text = [NSString stringWithFormat:@"%d", self.proxyInstance.port];
                
                // SET SETTINGS LABEL: STRINGS TO AUTO CONFIGS, TRAFFIC STATISTICS, OFF LINK
                self.viewMenu.labelSettings.text = [NSString stringWithFormat:@"PROXY AUTO CONFIG PATH (PAC):\nSOCKS5: http://%@:%@/socks.pac\nHTTP(S): http://%@:%@/http.pac\n\nOFF: http://%@:%@/proxyoff\nTRAFFIC IN: %@ byte/second\nTRAFFIC OUT: %@ byte/second", self.viewMenu.textIp.text, self.viewMenu.textPort.text, self.viewMenu.textIp.text, self.viewMenu.textPort.text,self.viewMenu.textIp.text, self.viewMenu.textPort.text, stringIn, stringOut];
                    // NULLIFY STRINGS TO HELP WITH MEM RELEASE
                    stringOut = nil;
                    stringIn = nil;
                    // SHOW SETTINGS LABEL
                    self.viewMenu.labelSettings.hidden = false;
                }
            
        }
        

    }
        }];
}


// ADJUST VIEWS IN VIEW CONTROLLER
- (void)viewDidLoad {
    [super viewDidLoad];
    // INIT QUEUE
    self.queueProxyInstance = dispatch_queue_create("AsyncProxy.queueTCPClient", DISPATCH_QUEUE_SERIAL);
    
    // INIT MENU VIEW CLASS (CUSTOMIZED UIVIEW)
    self.viewMenu = [MenuView new];
    // SET BG COLOR FROM STORYBOARD VIEW
    self.viewMenu.backgroundColor = self.view.backgroundColor;
    // MAKE SURE THAT USER CAN INPUT FOR BOTH VIEWS
    self.viewMenu.userInteractionEnabled = true;
    self.view.userInteractionEnabled = true;
    // PUT CUSTOM VIEW INTO DEFAULT VIEW
    [self.view addSubview:self.viewMenu];
    
    // SET METHOD FOR UISWITCH CHANGES
    [self.viewMenu.switchStarter addTarget:self
                           action:@selector(enablerSwitchAction)
                 forControlEvents:UIControlEventValueChanged];
    
    // SET OPTIMAL AUDIO MODE
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
    // INIT AUDIO PLAYER, LOAD SOUND AS DATA (USE RAM FOR SPEED, FILE IS SUPER TINY)
    self.audioPlayer = [[AVAudioPlayer alloc] initWithData:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"silence" ofType:@"wav"]]
                                              fileTypeHint:AVFileTypeWAVE
                                                     error:nil];
    // SET INFINITE LOOP
    self.audioPlayer.numberOfLoops = -1;
    // SET TO MUTE
    self.audioPlayer.volume = 0.00;
    // MAKE PLAYER READY
    [self.audioPlayer prepareToPlay];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    // DISPOSE PROXY:
    // MAKE IT MAIN QUEUE FOR SAFETY
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        // IF PROXY IS RUNNING OR SWITCH ON
        if ((self.viewMenu.switchStarter.on)||(self.proxyInstance != nil)) {
            // SET SWITCH TO OFF STATE BY CODE
            self.viewMenu.switchStarter.on = false;
            // NULLIFY PROXY INSTANCE POINTER, SO SYSTEM DEALLOCATE IT
            self.proxyInstance = nil;
            // PRESENT STATUS INDICATING BOOL TRIGGER INVOLVEMENT (DISABLED BY LINK)
            self.viewMenu.labelStatus.text = @"PROXY OFFLINE\n(DISABLED BY MEMORY WARNING)";
            // RUN UISWITCH METHOD BY CODE
            [self enablerSwitchAction];
        }
    }];
}



@end
