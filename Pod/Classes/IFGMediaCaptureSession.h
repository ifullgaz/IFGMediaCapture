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

@class IFGMediaCaptureSession;

@protocol IFGMediaCaptureSessionDelegate <NSObject>

@optional
- (void)captureSessionManagerDidStart:(IFGMediaCaptureSession *)captureSessionManager;
- (void)captureSessionManagerDidStop:(IFGMediaCaptureSession *)captureSessionManager;
- (void)captureSessionManagerInterrupted:(IFGMediaCaptureSession *)captureSessionManager;

@end

@protocol IFGMediaCaptureSessionOutputObserver <NSObject>

@optional
- (void)captureSessionManager:(IFGMediaCaptureSession *)captureSessionManager didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(NSString *)mediaType;
- (void)captureSessionManager:(IFGMediaCaptureSession *)captureSessionManager didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(NSString *)mediaType;

@end

#define IFGMediaCaptureSessionErrorDomain                                       @"IFGMediaCaptureSessionErrorDomain"

typedef enum {
    IFGMediaCaptureSessionErrorPreset            = -1,
    IFGMediaCaptureSessionErrorNoVideoDevice     = -2,
    IFGMediaCaptureSessionErrorPresetVideoDevice = -3,
    IFGMediaCaptureSessionErrorNoAudioDevice     = -4
} IFGMediaCaptureSessionError;

typedef enum {
    IFGMediaCaptureSessionStateCreated,
    IFGMediaCaptureSessionStateConfiguring,
    IFGMediaCaptureSessionStateStarting,
    IFGMediaCaptureSessionStateRunning,
    IFGMediaCaptureSessionStateStopping,
    IFGMediaCaptureSessionStateStopped
} IFGMediaCaptureSessionState;

typedef void(^IFGMediaCaptureSessionSetupCompletionBlock)(NSError *error);

@interface IFGMediaCaptureSession : NSObject

@property (weak, nonatomic)  id <IFGMediaCaptureSessionDelegate>                delegate;
@property (strong, nonatomic, readonly) IFGMediaCaptureSessionConfiguration     *configuration;
@property (assign, atomic, readonly) IFGMediaCaptureSessionState                state;
@property (assign, atomic, readonly) CGSize                                     videoSize;

- (void)setupCaptureSessionWithConfiguration:(IFGMediaCaptureSessionConfiguration *)configuration onCompletion:(IFGMediaCaptureSessionSetupCompletionBlock)completionBlock;
- (void)registerInterestInOutput:(id<IFGMediaCaptureSessionOutputObserver>)observer onCompletion:(IFGMediaCaptureSessionSetupCompletionBlock)completionBlock;
- (void)unregisterInterestInOutput:(id<IFGMediaCaptureSessionOutputObserver>)observer onCompletion:(IFGMediaCaptureSessionSetupCompletionBlock)completionBlock;

//Writer
@property(nonatomic, readonly,strong) AVCaptureMovieFileOutput *movieFileOutput;
@property(nonatomic, assign) BOOL notifyOnResume;
@property(nonatomic, assign) BOOL freezeFrame;
@property(nonatomic, assign) BOOL pauseCapture;

- (void)start;
- (void)stop;

@end
