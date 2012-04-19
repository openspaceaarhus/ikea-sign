//
//  util.m
//  Stickgame
//
//  Created by Morten Bek Ditlevsen on 26/10/11.
//  Copyright (c) 2011 Great Mojo Games. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "util.h"

void getPath(const char* filename, char * buffer) {
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *filenameStr = [[[NSString alloc] initWithCString: filename encoding: NSASCIIStringEncoding] autorelease];
    NSString *fullPath = [NSString stringWithFormat: @"%@/%@", path, filenameStr];
    const char * cString = [fullPath cStringUsingEncoding: NSASCIIStringEncoding];
    memcpy (buffer, cString, strlen(cString) + 1);
}


void *SDL_applicationDidFinishLaunchingHack()
{
    
    UIImage *splashImage;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)        
        splashImage = [UIImage imageNamed: @"Default-Portrait~ipad"];
    else
        splashImage = [UIImage imageNamed: @"Default.png"];
        
    UIImageView *splashView = [[UIImageView alloc] initWithImage: splashImage];
    UIWindow *window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    [window addSubview: splashView];
    [window makeKeyAndVisible];
    return window;
}
