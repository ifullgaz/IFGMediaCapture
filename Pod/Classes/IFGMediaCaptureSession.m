//
//  IFGMediaCaptureSession.m
//  IFGMediaCapture
//
//  Created by Emmanuel Merali on 16/03/2016.
//  Copyright 2016 rooftoptek.com. All rights reserved.
//

#import "IFGMediaCaptureSession.h"
#import "AVCaptureDevice+IFGMediaCapture.h"
#import "IFGCaptureFileOutput.h"

// Capture queues - Global to all instances
static dispatch_queue_t                                                         videoCaptureQueue;
static dispatch_queue_t                                                         audioCaptureQueue;
// Capture session queue
static dispatch_queue_t                                                         sessionQueue;
// Dispatch queue
static dispatch_queue_t                                                         dispatchQueue;

@interface IFGMediaCaptureSession ()

// The configuration
@property (strong, nonatomic) IFGMediaCaptureSessionConfiguration               *configuration;
// The state
@property (assign, atomic) IFGMediaCaptureSessionState                          state;
@property (assign, atomic) BOOL                                                 shouldStart;
@property (assign, atomic) BOOL                                                 shouldStop;
// Capture session
@property (strong, nonatomic) AVCaptureSession                                  *session;
// Devices
@property (weak, nonatomic) AVCaptureDevice                                     *videoDevice;
@property (weak, nonatomic) AVCaptureDevice                                     *audioDevice;
// Inputs
@property (strong, nonatomic) AVCaptureDeviceInput                              *videoInput;
@property (strong, nonatomic) AVCaptureDeviceInput                              *audioInput;
// Outputs
@property (strong, nonatomic) AVCaptureVideoDataOutput                          *videoOutput;
@property (strong, nonatomic) AVCaptureAudioDataOutput                          *audioOutput;
@property (strong, nonatomic) NSHashTable                                       *outputClients;
// Preview support
@property (weak, nonatomic) AVCaptureVideoPreviewLayer                          *previewLayer;
@end

@interface IFGMediaCaptureSession (Private)

+ (AVCaptureVideoOrientation)translateDeviceOrientationToAVOrientation:(UIDeviceOrientation)orientation;
- (void)videoDeviceForConfiguration:(IFGMediaCaptureSessionConfiguration *)configuration onCompletion:(IFGMediaCaptureSessionValidationCompletionBlock)completionBlock;
- (void)audioDeviceForConfiguration:(IFGMediaCaptureSessionConfiguration *)configuration onCompletion:(IFGMediaCaptureSessionValidationCompletionBlock)completionBlock;
- (void)configureSessionInputWithSessionPreset:(NSString *)sessionPreset;
- (void)configureSessionInputWithVideoDevice:(AVCaptureDevice *)videoDevice;
- (void)configureSessionOutputForVideoDevice:(AVCaptureDevice *)videoDevice;
- (void)configureSessionInputWithAudioDevice:(AVCaptureDevice *)audioDevice;
- (void)configureSessionOutputForAudioDevice:(AVCaptureDevice *)audioDevice;
- (void)configurePreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer;

- (void)updateVideoOutputOrientation;
// Notifications handling
- (void)handleSessionDeviceRotation:(NSNotification *)notification;
- (CMSampleBufferRef)sampleBufferWithFrameDurationFromVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

@interface IFGMediaCaptureSession (AVCaptureDataOutputSampleBufferDelegate) <AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;
- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;

@end


@implementation IFGMediaCaptureSession (Private)

+ (AVCaptureVideoOrientation)translateDeviceOrientationToAVOrientation:(UIDeviceOrientation)orientation {
    switch (orientation) {
        case UIDeviceOrientationFaceDown:
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationUnknown:
            return AVCaptureVideoOrientationPortrait;
        case UIDeviceOrientationPortraitUpsideDown:
            return AVCaptureVideoOrientationPortraitUpsideDown;
        case UIDeviceOrientationLandscapeRight:
            return AVCaptureVideoOrientationLandscapeLeft;
        case UIDeviceOrientationLandscapeLeft:
            return AVCaptureVideoOrientationLandscapeRight;
        default:
            return AVCaptureVideoOrientationPortrait;
    }
}

- (void)videoDeviceForConfiguration:(IFGMediaCaptureSessionConfiguration *)configuration onCompletion:(IFGMediaCaptureSessionValidationCompletionBlock)completionBlock {
    NSError *error = nil;
    AVCaptureDevice *videoDevice = nil;
    // Sanity checking for configuration
    NSString *sessionPreset = configuration.sessionPreset;
    // Check if video input device needs changing
    if (![self.configuration.sessionPreset isEqualToString:sessionPreset] &&
        ![self.session canSetSessionPreset:sessionPreset]) {
        error = [NSError errorWithDomain:IFGMediaCaptureSessionErrorDomain code:IFGMediaCaptureSessionErrorPreset userInfo:nil];
    }
    else {
        if ([self.configuration.sessionPreset isEqualToString:sessionPreset] &&
            self.configuration.shouldCaptureVideo == configuration.shouldCaptureVideo &&
            self.configuration.cameraPosition == configuration.cameraPosition &&
            self.videoDevice != nil) {
            videoDevice = self.videoDevice;
        }
        else {
            IFGMediaCaptureSessionConfigurationChoice shouldCaptureVideo = configuration.shouldCaptureVideo;
            if (shouldCaptureVideo != IFGMediaCaptureSessionConfigurationChoiceNo) {
                videoDevice = (configuration.cameraPosition == AVCaptureDevicePositionFront) ? [AVCaptureDevice frontFacingCamera] : [AVCaptureDevice backFacingCamera];
                if (!videoDevice && shouldCaptureVideo == IFGMediaCaptureSessionConfigurationChoiceYes) {
                    error = [NSError errorWithDomain:IFGMediaCaptureSessionErrorDomain code:IFGMediaCaptureSessionErrorNoVideoDevice userInfo:nil];
                }
                if (videoDevice && ![videoDevice supportsAVCaptureSessionPreset:sessionPreset]) {
                    error = [NSError errorWithDomain:IFGMediaCaptureSessionErrorDomain code:IFGMediaCaptureSessionErrorPresetVideoDevice userInfo:nil];
                }
            }
        }
    }
    if (error) {
        videoDevice = nil;
    }
    completionBlock(videoDevice, error);
}

- (void)audioDeviceForConfiguration:(IFGMediaCaptureSessionConfiguration *)configuration onCompletion:(IFGMediaCaptureSessionValidationCompletionBlock)completionBlock {
    NSError *error = nil;
    AVCaptureDevice *audioDevice = nil;
    // Check if audio input device needs changing
    if (self.configuration.shouldCaptureAudio == configuration.shouldCaptureAudio &&
        self.audioDevice != nil) {
        audioDevice = self.audioDevice;
    }
    else {
        IFGMediaCaptureSessionConfigurationChoice shouldCaptureAudio = configuration.shouldCaptureAudio;
        if (shouldCaptureAudio != IFGMediaCaptureSessionConfigurationChoiceNo) {
            audioDevice = [AVCaptureDevice defaultAudioDevice];
            if (!audioDevice && shouldCaptureAudio == IFGMediaCaptureSessionConfigurationChoiceYes) {
                error = [NSError errorWithDomain:IFGMediaCaptureSessionErrorDomain code:IFGMediaCaptureSessionErrorNoAudioDevice userInfo:nil];
            }
        }
    }
    if (error) {
        audioDevice = nil;
    }
    completionBlock(audioDevice, error);
}

- (void)configureSessionInputWithSessionPreset:(NSString *)sessionPreset {
    if (![sessionPreset isEqualToString:self.session.sessionPreset]) {
        self.session.sessionPreset = sessionPreset;
    }
}

- (void)configureSessionInputWithVideoDevice:(AVCaptureDevice *)videoDevice {
    NSError *error;
    if (videoDevice != self.videoDevice) {
        [self.session removeInput:self.videoInput];
        if (videoDevice) {
            AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
            if ([self.session canAddInput:videoInput]) {
                [self.session addInput:videoInput];
                self.videoDevice = videoDevice;
                self.videoInput = videoInput;
            }
            else {
                // Error?
                [self.session addInput:self.videoInput];
            }
        }
        else {
            self.videoDevice = videoDevice;
            self.videoInput = nil;
        }
    }
}

- (void)configureSessionOutputForVideoDevice:(AVCaptureDevice *)videoDevice {
    if (videoDevice) {
        if (!self.videoOutput) {
            self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
            [self.videoOutput setAlwaysDiscardsLateVideoFrames:YES];
            [self.videoOutput setVideoSettings:@{
                                                 (id)kCVPixelBufferPixelFormatTypeKey:
                                                 [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                                 }];
            if ([self.session canAddOutput:self.videoOutput]) {
                [self.session addOutput:self.videoOutput];
            }
            else {
                // Error?
                self.videoOutput = nil;
            }
        }
    }
    else {
        [self.session removeOutput:self.videoOutput];
        self.videoOutput = nil;
    }
}

- (void)configureSessionInputWithAudioDevice:(AVCaptureDevice *)audioDevice {
    NSError *error;
    if (audioDevice != self.audioDevice) {
        [self.session removeInput:self.audioInput];
        if (audioDevice) {
            AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
            if ([self.session canAddInput:audioInput]) {
                [self.session addInput:audioInput];
                self.audioDevice = audioDevice;
                self.audioInput = audioInput;
            }
            else {
                // Error?
                self.audioInput = nil;
            }
        }
        else {
            self.audioDevice = nil;
            self.videoInput = nil;
        }
    }
}

- (void)configureSessionOutputForAudioDevice:(AVCaptureDevice *)audioDevice {
    if (audioDevice) {
        if (!self.audioOutput) {
            self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
            if ([self.session canAddOutput:self.audioOutput]) {
                [self.session addOutput:self.audioOutput];
            }
            else {
                // Error?
                self.audioOutput = nil;
            }
        }
    }
    else {
        [self.session removeOutput:self.audioOutput];
        self.audioOutput = nil;
    }
}

- (void)configurePreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer {
    if (previewLayer != self.previewLayer) {
        self.previewLayer.session = nil;
        self.previewLayer = previewLayer;
        self.previewLayer.session = self.session;
    }
}

- (void)updateVideoOutputOrientation {
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    AVCaptureVideoOrientation previewOrientation = [IFGMediaCaptureSession translateDeviceOrientationToAVOrientation:deviceOrientation];
    dispatch_async(dispatch_get_main_queue(), ^{
        AVCaptureConnection *connection;
        connection = self.previewLayer.connection;
        if (connection.supportsVideoOrientation) {
            connection.videoOrientation = previewOrientation;
        }
        connection = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];
        if (connection.supportsVideoOrientation) {
            dispatch_async(sessionQueue, ^{
                connection.videoOrientation = previewOrientation;
            });
        }
    });
}

// Notifications handling
- (void)handleSessionDeviceRotation:(NSNotification *)notification {
    [self updateVideoOutputOrientation];
}

- (void)handleSessionStartRunning:(NSNotification*)notification {
    if (notification.object != self.session) {
        return;
    }
}

- (void)handleSessionStopRunning:(NSNotification *)notification {
    if (notification.object != self.session) {
        return;
    }
}

- (void)handleSessionInteruprted:(NSNotification*)notification {
    if (notification.object != self.session) {
        return;
    }
}

- (void)handleSessionError:(NSNotification*)notification {
    if (notification.object != self.session) {
        return;
    }
}

- (CMSampleBufferRef)sampleBufferWithFrameDurationFromVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CMTime duration = self.videoDevice.activeVideoMinFrameDuration;
    CMItemCount count;
    CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, 0, nil, &count);
    CMSampleTimingInfo *timingInfoArray = malloc(sizeof(CMSampleTimingInfo) * count);
    CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, count, timingInfoArray, &count);
    
    for (CMItemCount i = 0; i < count; i++) {
        timingInfoArray[i].duration = duration;
    }
    
    CMSampleBufferRef adjustedSampleBuffer;
    CMSampleBufferCreateCopyWithNewTiming(nil, sampleBuffer, count, timingInfoArray, &adjustedSampleBuffer);
    free(timingInfoArray);
    return adjustedSampleBuffer;
}

@end

@implementation IFGMediaCaptureSession (AVCaptureDataOutputSampleBufferDelegate)

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    IFGMediaCaptureMediaType mediaType = (captureOutput == self.videoOutput) ? IFGMediaCaptureMediaTypeVideo : IFGMediaCaptureMediaTypeAudio;
    CFRetain(sampleBuffer);
    if (mediaType == IFGMediaCaptureMediaTypeVideo) {
        CFRelease(sampleBuffer);
        sampleBuffer = [self sampleBufferWithFrameDurationFromVideoSampleBuffer:sampleBuffer];
    }
    dispatch_async(dispatchQueue, ^{
        for (id<IFGMediaCaptureSessionOutputObserver> outputClient in self.outputClients) {
            [outputClient
             captureSessionManager:self
             didOutputSampleBuffer:sampleBuffer
             mediaType:mediaType];
        }
        CFRelease(sampleBuffer);
    });
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    IFGMediaCaptureMediaType mediaType = (captureOutput == self.videoOutput) ? IFGMediaCaptureMediaTypeVideo : IFGMediaCaptureMediaTypeAudio;
    CFRetain(sampleBuffer);
    dispatch_async(dispatchQueue, ^{
        for (id<IFGMediaCaptureSessionOutputObserver> outputClient in self.outputClients) {
            [outputClient
             captureSessionManager:self
             didDropSampleBuffer:sampleBuffer
             mediaType:mediaType];
        }
        CFRelease(sampleBuffer);
    });
}

@end

@implementation IFGMediaCaptureSession

- (id)init {
    self = [super init];
    if (self) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            videoCaptureQueue = dispatch_queue_create("IFGMediaCaptureVideoQueue", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0));
            audioCaptureQueue = dispatch_queue_create("IFGMediaCaptureAudioQueue", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0));
            sessionQueue = dispatch_queue_create("IFGMediaCaptureSessionQueue", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0));
            dispatchQueue = dispatch_queue_create("IFGMediaCaptureDispatchQueue", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0));
        });
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSessionStartRunning:) name:AVCaptureSessionDidStartRunningNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSessionStopRunning:) name:AVCaptureSessionDidStopRunningNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSessionInteruprted:) name:AVCaptureSessionWasInterruptedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSessionError:) name:AVCaptureSessionRuntimeErrorNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSessionError:) name:AVCaptureSessionErrorKey object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSessionDeviceRotation:) name:UIDeviceOrientationDidChangeNotification object:nil];
        _outputClients = [NSHashTable hashTableWithOptions:NSHashTableWeakMemory];
        _session = [[AVCaptureSession alloc] init];
        _state = IFGMediaCaptureSessionStateCreated;
    }
    return self;
}

- (void)dealloc {
    // Should not have to but in case of circular references somewhere
    self.session = nil;
    self.outputClients = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (CGSize)videoSize {
    NSDictionary *videoSettings = self.videoOutput.videoSettings;
    int width = [[videoSettings objectForKey:@"Width"] intValue];
    int height = [[videoSettings objectForKey:@"Height"] intValue];
    return CGSizeMake(width - (width % 2), height - (height % 2));
}

- (void)setupCaptureSessionWithConfiguration:(IFGMediaCaptureSessionConfiguration *)configuration onCompletion:(IFGMediaCaptureSessionSetupCompletionBlock)completionBlock {
    __block AVCaptureDevice *videoDevice;
    [self videoDeviceForConfiguration:configuration onCompletion:^(id result, NSError *error) {
        if (error) {
            return completionBlock(error);
        }
        videoDevice = result;
    }];
    __block AVCaptureDevice *audioDevice;
    [self audioDeviceForConfiguration:configuration onCompletion:^(id result, NSError *error) {
        if (error) {
            return completionBlock(error);
        }
        audioDevice = result;
    }];
    dispatch_async(sessionQueue, ^{
        IFGMediaCaptureSessionState state = self.state;
        self.state = IFGMediaCaptureSessionStateConfiguring;
        [self.session beginConfiguration];
        [self configureSessionInputWithSessionPreset:configuration.sessionPreset];
        [self configureSessionInputWithVideoDevice:videoDevice];
        [self configureSessionOutputForVideoDevice:videoDevice];
        [self configureSessionInputWithAudioDevice:audioDevice];
        [self configureSessionOutputForAudioDevice:audioDevice];
        [self configurePreviewLayer:configuration.previewLayer];
        [self updateVideoOutputOrientation];
        [self.session commitConfiguration];
        self.configuration = configuration;
        self.state = state;
        NSLog(@"Configured");
        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock(nil);
        });
    });
}

- (void)registerInterestInOutput:(id<IFGMediaCaptureSessionOutputObserver>)observer onCompletion:(IFGMediaCaptureSessionSetupCompletionBlock)completionBlock {
    dispatch_async(sessionQueue, ^{
        [self.outputClients addObject:observer];
        completionBlock(nil);
    });
}

- (void)unregisterInterestInOutput:(id<IFGMediaCaptureSessionOutputObserver>)observer onCompletion:(IFGMediaCaptureSessionSetupCompletionBlock)completionBlock {
    dispatch_async(sessionQueue, ^{
        [self.outputClients removeObject:observer];
        completionBlock(nil);
    });
}

- (void)start {
    dispatch_async(sessionQueue, ^{
        self.state = IFGMediaCaptureSessionStateStarting;
        [self.session beginConfiguration];
        [self.videoOutput setSampleBufferDelegate:self queue:sessionQueue];
        [self.audioOutput setSampleBufferDelegate:self queue:sessionQueue];
        [self.session commitConfiguration];
        [self.session startRunning];
        self.state = IFGMediaCaptureSessionStateRunning;
    });
}

- (void)stop {
    dispatch_async(sessionQueue, ^{
        self.state = IFGMediaCaptureSessionStateStopping;
        [self.session beginConfiguration];
        [self.videoOutput setSampleBufferDelegate:nil queue:nil];
        [self.audioOutput setSampleBufferDelegate:nil queue:nil];
        [self.session commitConfiguration];
        [self.session stopRunning];
        self.state = IFGMediaCaptureSessionStateStopped;
    });
}

@end
