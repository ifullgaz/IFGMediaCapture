//
//  IFGMediaCaptureSession.h
//  IFGMediaCapture
//
//  Created by Emmanuel Merali on 16/03/2016.
//  Copyright 2016 rooftoptek.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "IFGMediaCaptureSessionConfiguration.h"
#import "IFGMediaCaptureTypes.h"

@class IFGMediaCaptureSession;

@protocol IFGMediaCaptureSessionDelegate <NSObject>

@optional
- (void)captureSessionManagerDidStart:(IFGMediaCaptureSession *)captureSessionManager;
- (void)captureSessionManagerDidStop:(IFGMediaCaptureSession *)captureSessionManager;
- (void)captureSessionManagerInterrupted:(IFGMediaCaptureSession *)captureSessionManager;

@end

@protocol IFGMediaCaptureSessionOutputObserver <NSObject>

@optional
- (void)captureSessionManager:(IFGMediaCaptureSession *)captureSessionManager didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(IFGMediaCaptureMediaType)mediaType;
- (void)captureSessionManager:(IFGMediaCaptureSession *)captureSessionManager didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(IFGMediaCaptureMediaType)mediaType;

@end

@interface IFGMediaCaptureSession : NSObject

@property (weak, nonatomic)  id <IFGMediaCaptureSessionDelegate>                delegate;
@property (strong, nonatomic, readonly) IFGMediaCaptureSessionConfiguration     *configuration;
@property (assign, atomic, readonly) IFGMediaCaptureSessionState                state;
@property (assign, atomic, readonly) CGSize                                     videoSize;

- (void)setupCaptureSessionWithConfiguration:(IFGMediaCaptureSessionConfiguration *)configuration onCompletion:(IFGMediaCaptureSessionSetupCompletionBlock)completionBlock;
- (void)registerInterestInOutput:(id<IFGMediaCaptureSessionOutputObserver>)observer onCompletion:(IFGMediaCaptureSessionSetupCompletionBlock)completionBlock;
- (void)unregisterInterestInOutput:(id<IFGMediaCaptureSessionOutputObserver>)observer onCompletion:(IFGMediaCaptureSessionSetupCompletionBlock)completionBlock;

- (void)start;
- (void)stop;

@end
