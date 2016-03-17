//
//  IFGMediaCaptureSessionAuthorisationHelper.m
//  IFGMediaCapture
//
//  Created by Emmanuel Merali on 17/03/2016.
//  Copyright 2016 rooftoptek.com. All rights reserved.
//

#import "IFGMediaCaptureSessionAuthorisationHelper.h"
#import <AVFOundation/AVFoundation.h>
//#import <CLLocationManager.h>

@implementation IFGMediaCaptureSessionAuthorisationHelper

+ (IFGMediaCaptureSessionAuthorisationHelperType)checkAuthorizationsForConfiguration:(IFGMediaCaptureSessionConfiguration *)configuration {
    return 0;
}

- (void)authorizeVideoInputCompletionBlock:(IFGMediaCaptureSessionAuthorisationHelperCompletionBlock)completiongBlock {
    
}

- (void)authorizeAudioInputCompletionBlock:(IFGMediaCaptureSessionAuthorisationHelperCompletionBlock)completiongBlock {
    
}

- (void)authorizeLocationCompletionBlock:(IFGMediaCaptureSessionAuthorisationHelperCompletionBlock)completiongBlock {
    
}

@end
