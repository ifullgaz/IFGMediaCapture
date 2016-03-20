//
//  IFGMediaCaptureSessionAuthorisationHelper.h
//  IFGMediaCapture
//
//  Created by Emmanuel Merali on 17/03/2016.
//  Copyright 2016 rooftoptek.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IFGMediaCaptureSessionConfiguration.h"

@interface IFGMediaCaptureSessionAuthorisationHelper : NSObject

+ (IFGMediaCaptureSessionAuthorisationHelperType)checkAuthorizationsForConfiguration:(IFGMediaCaptureSessionConfiguration *)configuration;

- (void)authorizeVideoInputCompletionBlock:(IFGMediaCaptureSessionAuthorisationHelperCompletionBlock)completiongBlock;
- (void)authorizeAudioInputCompletionBlock:(IFGMediaCaptureSessionAuthorisationHelperCompletionBlock)completiongBlock;
- (void)authorizeLocationCompletionBlock:(IFGMediaCaptureSessionAuthorisationHelperCompletionBlock)completiongBlock;

@end
