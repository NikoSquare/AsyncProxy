//
//  MenuView.m
//  AsyncProxy
//
//  Created by Nikita Mordasov on 1/18/15.
//  Copyright (c) 2015 Nikita Mordasov. All rights reserved.
//
// THIS IS ACTUAL UI

#import "MenuView.h"
#import <ifaddrs.h>
#import <arpa/inet.h>

@implementation MenuView

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

-(void)enableInput
{
    self.textPort.userInteractionEnabled = true;
    self.textPort.textColor = [UIColor grayColor];
    self.textPort.borderStyle = UITextBorderStyleRoundedRect;
    self.textPort.backgroundColor = [UIColor whiteColor];
    self.switchStarter.on = false;
    self.labelSettings.hidden = true;
    [self loadURL];
}

-(void)disableInput
{
    [self dismissKeyboard];
    self.textPort.userInteractionEnabled = false;
    self.textPort.textColor = [UIColor grayColor];
    self.textPort.borderStyle = UITextBorderStyleNone;
    self.textPort.backgroundColor = [UIColor clearColor];
    //self.textIp.userInteractionEnabled = false;
    //self.textIp.textColor = [UIColor grayColor];
    self.switchStarter.on = true;
}

-(void)saveURL
{
    [[NSUserDefaults standardUserDefaults] setInteger:self.textPort.text.integerValue forKey:@"PORT"];
    // [[NSUserDefaults standardUserDefaults] setURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%d", self.textIp.text, self.textPort.text.intValue]] forKey:@"URL"];
}

-(void)loadURL
{
    int port = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"PORT"];
    if (port == 0) {
         self.textPort.text = @"";
    } else {
        self.textPort.text = [NSString stringWithFormat:@"%d", port];
    }
    NSString *ipAddress = [self myIPAddress];
    if (ipAddress) { self.textIp.text = ipAddress; }
    else { self.textIp.text = @"0.0.0.0"; }
}

-(instancetype)init
{
    self = [super init];
    if (self) {
        // SET VIEW FRAME
        self.frame = [[UIScreen mainScreen ] bounds];
        
        NSString *ipAddress = [self myIPAddress];
        // IF IP ADDRESS CORRECT
        if (ipAddress.length >= 7) {
        
        // ADD ELEMENTS
        UIButton *ipButton = [UIButton buttonWithType:UIButtonTypeSystem];
        // ipButton.titleLabel.text = @"OK";
        ipButton.backgroundColor = [UIColor clearColor];
        [ipButton addTarget:self
                     action:@selector(dismissKeyboard)
           forControlEvents:UIControlEventTouchDown];
        
        ipButton.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
        [self addSubview:ipButton];
            
            
           
        
        
        
        
        // [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"PORT"];
        
        // CREATE PORT TEXT
        self.textPort = [UITextField new];
        self.textPort.tag = 2;
        self.textPort.userInteractionEnabled = true;
        self.textPort.keyboardType = UIKeyboardTypeNumberPad;
        self.textPort.delegate = self;
        self.textPort.borderStyle = UITextBorderStyleRoundedRect;
        self.textPort.backgroundColor = [UIColor whiteColor];
        self.textPort.placeholder = @"AUTO";
        self.textPort.textAlignment = NSTextAlignmentCenter;
        self.textPort.font = [UIFont fontWithName:@"Arial" size:70];
        self.textPort.frame = CGRectMake((self.frame.size.width/2) - 110, self.frame.size.height/3, 220, 65);
            self.textPort.textColor = [UIColor grayColor];
        [self addSubview:self.textPort];
        
        // CREATE IP TEXT
        self.textIp = [UILabel new];
        self.textIp.tag = 1;
        //self.textIp.userInteractionEnabled = true;
        //self.textIp.keyboardType = UIKeyboardTypeNumberPad;
            // self.textPort.keyboardType = UIKeyboardTypeDecimalPad;
        //self.textIp.delegate = self;
        //self.textIp.placeholder = @"172.20.10.1";
        self.textIp.textAlignment = NSTextAlignmentCenter;
        self.textIp.font = [UIFont fontWithName:@"Arial" size:30];
        self.textIp.textColor = [UIColor grayColor];
        self.textIp.frame = CGRectMake((self.frame.size.width/2) - 110, self.textPort.frame.origin.y - 45, 220, 30);
        [self addSubview:self.textIp];
            
            
            // CREATE STATUS STRING
            self.labelStatus = [UILabel new];
            self.labelStatus.numberOfLines = 3;
            self.labelStatus.textColor = [UIColor lightGrayColor];
            self.labelStatus.text = @"PROXY OFFLINE";
            self.labelStatus.textAlignment = NSTextAlignmentCenter;
            self.labelStatus.font = [UIFont fontWithName:@"Arial" size:18];
            self.labelStatus.frame = CGRectMake(15, self.textPort.frame.origin.y + self.textPort.frame.size.height + 9, self.frame.size.width - 30, 50);
            [self addSubview:self.labelStatus];
        
        // CREATE SWITCH
        self.switchStarter = [UISwitch new];
        self.switchStarter.frame = CGRectMake(self.frame.size.width/2 - (self.switchStarter.bounds.size.width/2), self.textPort.frame.origin.y + self.textPort.frame.size.height + self.labelStatus.frame.size.height + self.switchStarter.bounds.size.height, 0, 0);
        [self addSubview:self.switchStarter];
            
            
            
            
            // ADD LABELS
            
            // CREATE LABEL DESCRIPTION
            UILabel *labelWarning = [UILabel new];
            labelWarning.text = @"THIS PROGRAM MIGHT BE THE FIRST HYBRID PROXY SERVER. AT ONE PORT IT ACCEPTS\nHTTPS CONNECTIONS, HTTPS REQUESTS, SOCKS5 TCP AND UDP.\nAUTHENTIFICATION IS NOT SUPPORTED.\nAT THE SAME PORT SOCKS5 AND HTTP AUTOMATIC CONFIG FILES (PAC) ARE AVAILABLE.\nPROTOCOL WILL BE DETECTED AUTOMATICALLY FOR EACH CONNECTION.\nPROTOCOLS WERE SIMPLIFIED BY THE DEVELOPER AND MAY FAIL IN SOME CASES.\nCAN WORK MINIMIZED IN A BACKGROUND (PLAYS SILENCE)";
            labelWarning.textColor = [UIColor grayColor];
            labelWarning.numberOfLines = 8;
            labelWarning.textAlignment = NSTextAlignmentCenter;
            labelWarning.font = [UIFont fontWithName:@"Arial" size:6.5];
            labelWarning.frame = CGRectMake(5, 15, self.frame.size.width - 10, 60);
            [self addSubview:labelWarning];
            
            
            // CREATE LABEL COPYRIGHT
            UILabel *labelFooter = [UILabel new];
            labelFooter.text = @"Developed by Nikita Mordasov\nBased on CocoaAsyncSocket by Robbie Hanson";
            labelFooter.textColor = [UIColor grayColor];
            labelFooter.numberOfLines = 2;
            labelFooter.textAlignment = NSTextAlignmentCenter;
            labelFooter.font = [UIFont fontWithName:@"Arial" size:7];
            labelFooter.frame = CGRectMake(10, self.frame.size.height - 40, self.frame.size.width - 20, 20);
            [self addSubview:labelFooter];
            
            
            
            // CREATE LABEL IP
            UILabel *labelIp = [UILabel new];
            labelIp.text = @"IP ADDRESS:";
            labelIp.textColor = [UIColor grayColor];
            labelIp.textAlignment = NSTextAlignmentCenter;
            labelIp.font = [UIFont fontWithName:@"Arial" size:14];
            labelIp.frame = CGRectMake(self.textIp.frame.origin.x, self.textIp.frame.origin.y - 15, self.textIp.frame.size.width, 15);
            [self addSubview:labelIp];
            
            // CREATE LABEL IP
            UILabel *labelPrt = [UILabel new];
            labelPrt.text = @"PORT (EDITABLE):";
            labelPrt.textColor = [UIColor grayColor];
            labelPrt.textAlignment = NSTextAlignmentCenter;
            labelPrt.font = [UIFont fontWithName:@"Arial" size:14];
            labelPrt.frame = CGRectMake(self.textPort.frame.origin.x, self.textPort.frame.origin.y - 14.5, self.textPort.frame.size.width, 15);
            [self addSubview:labelPrt];
            
            
            // CREATE LABEL ON
            UILabel *labelON = [UILabel new];
            labelON.text = @"ON";
            labelON.textColor = [UIColor grayColor];
            labelON.textAlignment = NSTextAlignmentRight;
            labelON.font = [UIFont fontWithName:@"Arial" size:30];
            labelON.frame = CGRectMake(self.switchStarter.frame.origin.x + self.switchStarter.frame.size.width, self.switchStarter.frame.origin.y, 60, 35);
            [self addSubview:labelON];
            
            // CREATE LABEL OFF
            UILabel *labelOFF = [UILabel new];
            labelOFF.text = @"OFF";
            labelOFF.textColor = [UIColor grayColor];
            labelOFF.textAlignment = NSTextAlignmentLeft;
            labelOFF.font = [UIFont fontWithName:@"Arial" size:30];
            labelOFF.frame = CGRectMake(self.switchStarter.frame.origin.x - self.switchStarter.frame.size.width - 20, self.switchStarter.frame.origin.y, 60, 35);
            [self addSubview:labelOFF];
            
            
            // CREATE SETTINGS LABEL
            self.labelSettings = [UILabel new];
            self.labelSettings.hidden = true;
            self.labelSettings.numberOfLines = 7;
            self.labelSettings.textColor = [UIColor lightGrayColor];
            self.labelSettings.textAlignment = NSTextAlignmentCenter;
            self.labelSettings.font = [UIFont fontWithName:@"Arial" size:14];
            self.labelSettings.frame = CGRectMake(15, self.switchStarter.frame.origin.y + self.switchStarter.frame.size.height, self.frame.size.width - 30, 110);
            [self addSubview:self.labelSettings];
            
        
        
        // ROUTINES
        [self loadURL];
            
            // ON IP ADDRESS ERROR
        } else {
            // CREATE STATUS LABEL
            self.labelStatus = [UILabel new];
            
            self.labelStatus.text = @"LOCAL NETWORK NOT FOUND\nMake sure that device either:\nA) CONNECTED TO WIFI\nB) HAS HOTSPOT CLIENT\n\nRestart the App\n(A or B must be met)";
            self.labelStatus.textAlignment = NSTextAlignmentCenter;
            self.labelStatus.textColor = [UIColor whiteColor];
            self.labelStatus.numberOfLines = 7;
            self.labelStatus.font = [UIFont fontWithName:@"Arial" size:18];
            self.labelStatus.frame = CGRectMake(20, self.frame.size.height/3, self.frame.size.width - 40, 200);
            [self addSubview:self.labelStatus];
        }
    }
    return self;
}


-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    //~NSLog(@"STRING VALUE: %@ (%@ = %lu->%lu)\n(%@)", textField.text, string, (unsigned long)range.location, (unsigned long)range.length, [textField.text stringByReplacingCharactersInRange:range withString:string]);
    
    NSString *result = [textField.text stringByReplacingCharactersInRange:range withString:string];
    
    // FOR PORT
    if (textField.tag == 2) {
        NSRange checkRange = [result rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]];
        if (checkRange.location == NSNotFound) {
            return true;
        } else {
            self.labelStatus.text = @"INVALID TEXT FIELD ENTER";
            return false;
        }
    } else if (textField.tag == 1) {
        NSRange checkRange = [result rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"1234567890."] invertedSet]];
        if (checkRange.location == NSNotFound) {
            return true;
        } else {
            self.labelStatus.text = @"INVALID TEXT FIELD ENTER";
            return false;
        }
    }
    
    return false;
}

-(void)textFieldDidBeginEditing:(UITextField *)textField
{
    self.labelStatus.text = @"PORT RANGE: 1024-65535";
}

-(void)textFieldDidEndEditing:(UITextField *)textField
{
    //~NSLog(@"END EDIT");
    
    // CHECK STRING
    
    // FOR PORT
    if (textField.tag == 2) {
        NSRange checkRange = [textField.text rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]];
        int number = textField.text.intValue;
        if ((checkRange.location == NSNotFound)&&(number <= 65535)&&(number >= 1024)) {
            self.labelStatus.text = @"PORT UPDATED";
            [self saveURL];
        } else if ((checkRange.location == NSNotFound)&&(textField.text.length == 0)) {
            self.labelStatus.text = @"PORT UPDATED";
            [self saveURL];
        } else {
            self.labelStatus.text = @"RESTORED: PORT (1024-65535)";
            [self loadURL];
        }
    } else if (textField.tag == 1) {
        NSRange checkRange = [textField.text rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"1234567890."] invertedSet]];
        
        BOOL passTest = true;
        NSArray *checkElements = [textField.text componentsSeparatedByString:@"."];
        if (checkElements.count != 4) { passTest = false; }
        for (NSString *element in checkElements)
        {
            if (element.intValue > 255) { passTest = false; }
            if (element.length < 1) { passTest = false; }
        }
        
        if ((checkRange.location == NSNotFound)&&(passTest)) {
            self.labelStatus.text = @"IP UPDATED";
            [self saveURL];
        } else {
            self.labelStatus.text = @"RESTORE: BAD IP FORMAT";
            [self loadURL];
        }
    }
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return true;
}

-(void)dismissKeyboard
{
    //~NSLog(@"BUTTON PRESS");
    [self.textPort resignFirstResponder];
    [self.textIp resignFirstResponder];
}

- (NSString *)myIPAddress {
    
    NSString *address = @"ERROR";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                //~NSLog(@"INTERFACES: %@", [NSString stringWithUTF8String:temp_addr->ifa_name]);
                // Check if interface is en0 which is the wifi connection on the iPhone
                if (
                    ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"])
                    || ([[NSString stringWithUTF8String:temp_addr->ifa_name] hasPrefix:@"bridge"])
                    )
                {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                    
                }
                
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;
    
}

@end
