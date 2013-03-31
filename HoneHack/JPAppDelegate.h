//
//  JPAppDelegate.h
//  HoneHack
//
//  Created by Jamie Pinkham on 3/30/13.
//  Copyright (c) 2013 Jamie Pinkham. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface JPAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (nonatomic, strong) NSMutableArray *foundPeripherals;
@end
