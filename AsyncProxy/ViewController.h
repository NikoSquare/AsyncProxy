//
//  ViewController.h
//  AsyncProxy
//
//  Created by Nikita Mordasov on 1/1/15.
//  Copyright (c) 2015 Nikita Mordasov. All rights reserved.
//
/*
 Hybrid proxy server for iOS (iPhone, iPad, iPod) with support HTTP and SOCKS5 TCP and UDP based on CocoaAsyncSocket. Easy fit for MacOS. It also provides proxy auto configuration files (PAC) by http link. Disable by http link function. Automatic protocol recognition. Background mode (with silent sound loop).
 
 Possible use: AsyncProxy reroutes bridged interface data through device APN (Tethering) or back through WiFi (Securing). If device use VPN connection, AsyncProxy reroute client's traffic through that connection, where after proxy traffic will be secure. Another words you can connect device to WiFi (can be public WiFi), establish VPN, and connect clients in the same WiFi through device's AsyncProxy to secure all traffic.
 */

#import <UIKit/UIKit.h>


@interface ViewController : UIViewController

@end

