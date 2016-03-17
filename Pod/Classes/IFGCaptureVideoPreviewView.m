//
//  IFGCaptureVideoPreviewView.m
//  Pods
//
//  Created by Emmanuel Merali on 17/03/2016.
//
//

#import "IFGCaptureVideoPreviewView.h"
#import <AVFoundation/AVFoundation.h>

@implementation IFGCaptureVideoPreviewView

+ (Class)layerClass {
    return [AVCaptureVideoPreviewLayer class];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [(AVCaptureVideoPreviewLayer *)self.layer setVideoGravity:AVLayerVideoGravityResizeAspect];
}

@end
