//
//  AVCaptureDevice+IFGMediaCapture.h
//  IFGMediaCapture
//
//  Created by Emmanuel Merali on 16/03/2016.
//  Copyright 2016 rooftoptek.com. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

typedef void(^IFGMediaCaptureBlockingErrorBlock)(NSError *error);

@interface AVCaptureDevice (IFGMediaCapture)

// Convenience device access methods
+ (AVCaptureDevice *)defaultAudioDevice;
+ (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position;
+ (AVCaptureDevice *)frontFacingCamera;
+ (AVCaptureDevice *)backFacingCamera;

// Flash control
- (void)setFlashMode:(AVCaptureFlashMode)flashMode onError:(IFGMediaCaptureBlockingErrorBlock)errorBlock;

// Torch control
- (void)setTorchMode:(AVCaptureTorchMode)torchMode onError:(IFGMediaCaptureBlockingErrorBlock)errorBlock;

// Focus control
- (void)setFocusMode:(AVCaptureFocusMode)focusMode onError:(IFGMediaCaptureBlockingErrorBlock)errorBlock;
- (void)setFocusAtPoint:(CGPoint)point onError:(IFGMediaCaptureBlockingErrorBlock)errorBlock;

// Zoom control
- (void)setZoom:(CGFloat)scale onError:(IFGMediaCaptureBlockingErrorBlock)errorBlock;

// Exposure control
- (void)setExposureMode:(AVCaptureExposureMode)exposureMode onError:(IFGMediaCaptureBlockingErrorBlock)errorBlock;
- (void)setExposureAtPoint:(CGPoint)point onError:(IFGMediaCaptureBlockingErrorBlock)errorBlock;

// White balance control
- (void)setWhiteBalanceMode:(AVCaptureWhiteBalanceMode)whiteBalanceMode onError:(IFGMediaCaptureBlockingErrorBlock)errorBlock;

@end
