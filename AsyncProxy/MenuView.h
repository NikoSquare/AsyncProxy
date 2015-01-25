//
//  MenuView.h
//  AsyncProxy
//
//  Created by Nikita Mordasov on 1/18/15.
//  Copyright (c) 2015 Nikita Mordasov. All rights reserved.
//
// THIS IS ACTUAL UI

#import <UIKit/UIKit.h>

@interface MenuView : UIView <UITextFieldDelegate>

@property (nonatomic, strong) UISwitch *switchStarter;
@property (nonatomic, strong) UITextField *textPort;
@property (nonatomic, strong) UILabel *textIp;
@property (nonatomic, strong) UILabel *labelStatus;
@property (nonatomic, strong) UILabel *labelSettings;


-(void)loadURL;
-(void)enableInput;
-(void)disableInput;
-(void)dismissKeyboard;
@end
