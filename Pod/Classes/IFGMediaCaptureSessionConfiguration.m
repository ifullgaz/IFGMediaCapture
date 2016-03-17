//
//  IFGMediaCaptureSessionConfiguration.m
//  IFGMediaCapture
//
//  Created by Emmanuel Merali on 17/03/2016.
//  Copyright 2016 rooftoptek.com. All rights reserved.
//

#import "IFGMediaCaptureSessionConfiguration.h"

@implementation IFGMediaCaptureSessionConfiguration

+ (instancetype)defaultBackCameraConfigurationWithLayer:(AVCaptureVideoPreviewLayer *)previewLayer {
    IFGMediaCaptureSessionConfiguration *configuration = [IFGMediaCaptureSessionConfiguration new];
    configuration.previewLayer = previewLayer;
    return configuration;
}

+ (instancetype)defaultFrontCameraConfigurationWithLayer:(AVCaptureVideoPreviewLayer *)previewLayer {
    IFGMediaCaptureSessionConfiguration *configuration = [IFGMediaCaptureSessionConfiguration defaultBackCameraConfigurationWithLayer:previewLayer];
    configuration.cameraPosition = AVCaptureDevicePositionFront;
    return configuration;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.sessionPreset = AVCaptureSessionPresetHigh;
        self.cameraPosition = AVCaptureDevicePositionBack;
        self.shouldCaptureVideo = IFGMediaCaptureSessionConfigurationChoiceOptional;
        self.shouldCaptureAudio = IFGMediaCaptureSessionConfigurationChoiceOptional;
        self.shouldUseLocation = IFGMediaCaptureSessionConfigurationChoiceOptional;
        self.shouldMirrorFrontCamera = IFGMediaCaptureSessionConfigurationChoiceYes;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    IFGMediaCaptureSessionConfiguration *newConfiguration = [IFGMediaCaptureSessionConfiguration new];
    newConfiguration.sessionPreset = [self.sessionPreset copy];
    newConfiguration.cameraPosition = self.cameraPosition;
    newConfiguration.previewLayer = self.previewLayer;
    newConfiguration.shouldCaptureVideo = self.shouldCaptureVideo;
    newConfiguration.shouldCaptureAudio = self.shouldCaptureAudio;
    newConfiguration.shouldUseLocation = self.shouldUseLocation;
    newConfiguration.shouldMirrorFrontCamera = self.shouldMirrorFrontCamera;
    return newConfiguration;
}

@end
