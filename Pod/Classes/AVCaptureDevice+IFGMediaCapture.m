//
//  AVCaptureDevice+IFGCaptureDevice.m
//  IFGMediaCapture
//
//  Created by Emmanuel Merali on 16/03/2016.
//  Copyright 2016 rooftoptek.com. All rights reserved.
//

#import "AVCaptureDevice+IFGMediaCapture.h"

@implementation AVCaptureDevice (IFGMediaCapture)

#pragma mark - Convenience device access methods

+ (AVCaptureDevice *)defaultAudioDevice {
    return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
}

+ (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position {
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *videoDevice in videoDevices) {
        if ([videoDevice position] == position) {
            return videoDevice;
        }
    }
    return nil;
}

+ (AVCaptureDevice *)frontFacingCamera {
    return [self cameraWithPosition:AVCaptureDevicePositionFront];
}

+ (AVCaptureDevice *)backFacingCamera {
    return [self cameraWithPosition:AVCaptureDevicePositionBack];
}

#pragma mark - Flash

- (void)setFlashMode:(AVCaptureFlashMode)flashMode onError:(IFGMediaCaptureBlockingErrorBlock)errorBlock {
    if ([self isFlashModeSupported:flashMode] && [self flashMode] != flashMode) {
        NSError *error;
        if ([self lockForConfiguration:&error]) {
            [self setFlashMode:flashMode];
            [self unlockForConfiguration];
        }
        else {
            errorBlock(error);
        }
    }
}

#pragma mark - Torch

- (void)setTorchMode:(AVCaptureTorchMode)torchMode onError:(IFGMediaCaptureBlockingErrorBlock)errorBlock {
    if ([self isTorchModeSupported:torchMode] && [self torchMode] != torchMode) {
        NSError *error;
        if ([self lockForConfiguration:&error]) {
            [self setTorchMode:torchMode];
            [self unlockForConfiguration];
        }
        else {
            errorBlock(error);
        }
    }
}

#pragma mark - Focus

- (void)setFocusMode:(AVCaptureFocusMode)focusMode onError:(IFGMediaCaptureBlockingErrorBlock)errorBlock {
    if ([self isFocusModeSupported:focusMode] && [self focusMode] != focusMode) {
        NSError *error;
        if ([self lockForConfiguration:&error]) {
            [self setFocusMode:focusMode];
            [self unlockForConfiguration];
        }
        else {
            errorBlock(error);
        }
    }
}

- (void)setFocusAtPoint:(CGPoint)point onError:(IFGMediaCaptureBlockingErrorBlock)errorBlock {
    if ([self isFocusPointOfInterestSupported] && [self isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError *error;
        if ([self lockForConfiguration:&error]) {
            [self setFocusPointOfInterest:point];
            [self setFocusMode:AVCaptureFocusModeAutoFocus];
            [self unlockForConfiguration];
        }
        else {
            errorBlock(error);
        }
    }
}

#pragma mark - Zoom

- (void)setZoom:(CGFloat)scale onError:(IFGMediaCaptureBlockingErrorBlock)errorBlock {
    NSError *error;
    if ([self lockForConfiguration:&error]) {
        [self setVideoZoomFactor:scale];
        [self unlockForConfiguration];
    }
    else {
        errorBlock(error);
    }
}

#pragma mark - Exposure

- (void)setExposureMode:(AVCaptureExposureMode)exposureMode onError:(IFGMediaCaptureBlockingErrorBlock)errorBlock {
    if ([self isExposureModeSupported:exposureMode] && [self exposureMode] != exposureMode) {
        NSError *error;
        if ([self lockForConfiguration:&error]) {
            [self setExposureMode:exposureMode];
            [self unlockForConfiguration];
        }
        else {
            errorBlock(error);
        }
    }
}

- (void)setExposureAtPoint:(CGPoint)point onError:(IFGMediaCaptureBlockingErrorBlock)errorBlock {
    if ([self isExposurePointOfInterestSupported] && [self isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
        NSError *error;
        if ([self lockForConfiguration:&error]) {
            [self setExposurePointOfInterest:point];
            [self setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            [self unlockForConfiguration];
        }
        else {
            errorBlock(error);
        }
    }
}

#pragma mark - WhiteBalance

- (void)setWhiteBalanceMode:(AVCaptureWhiteBalanceMode)whiteBalanceMode onError:(IFGMediaCaptureBlockingErrorBlock)errorBlock {
    if ([self isWhiteBalanceModeSupported:whiteBalanceMode] && [self whiteBalanceMode] != whiteBalanceMode) {
        NSError *error;
        if ([self lockForConfiguration:&error]) {
            [self setWhiteBalanceMode:whiteBalanceMode];
            [self unlockForConfiguration];
        }
        else {
            errorBlock(error);
        }
    }
}

@end
