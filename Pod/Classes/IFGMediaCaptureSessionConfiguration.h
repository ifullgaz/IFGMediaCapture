//
//  IFGMediaCaptureSessionConfiguration.h
//  IFGMediaCapture
//
//  Created by Emmanuel Merali on 17/03/2016.
//  Copyright 2016 rooftoptek.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AvFoundation.h>

typedef enum {
    IFGMediaCaptureSessionConfigurationChoiceNo = 0,
    IFGMediaCaptureSessionConfigurationChoiceYes,
    IFGMediaCaptureSessionConfigurationChoiceOptional
} IFGMediaCaptureSessionConfigurationChoice;

@interface IFGMediaCaptureSessionConfiguration : NSObject <NSCopying>

@property (copy, nonatomic) NSString                                            *sessionPreset;
@property (assign, nonatomic) AVCaptureDevicePosition                           cameraPosition;
@property (weak, nonatomic) AVCaptureVideoPreviewLayer                          *previewLayer;
@property (assign, nonatomic) IFGMediaCaptureSessionConfigurationChoice       shouldCaptureVideo;
@property (assign, nonatomic) IFGMediaCaptureSessionConfigurationChoice       shouldCaptureAudio;
@property (assign, nonatomic) IFGMediaCaptureSessionConfigurationChoice       shouldUseLocation;
@property (assign, nonatomic) IFGMediaCaptureSessionConfigurationChoice       shouldMirrorFrontCamera;

+ (instancetype)defaultBackCameraConfigurationWithLayer:(AVCaptureVideoPreviewLayer *)previewLayer;
+ (instancetype)defaultFrontCameraConfigurationWithLayer:(AVCaptureVideoPreviewLayer *)previewLayer;

@end
