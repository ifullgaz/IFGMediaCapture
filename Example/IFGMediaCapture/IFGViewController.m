//
//  IFGViewController.m
//  IFGMediaCapture
//
//  Created by ifullgaz on 03/16/2016.
//  Copyright (c) 2016 ifullgaz. All rights reserved.
//

#import "IFGViewController.h"
#import <IFGMediaCapture/IFGMediaCapture.h>

@interface IFGViewController ()

@property (weak, nonatomic) IBOutlet IFGCaptureVideoPreviewView                 *captureVideoPreviewView;
@property (weak, nonatomic) IBOutlet UIButton                                   *recordButton;
@property (strong, nonatomic) IFGMediaCaptureSession                            *captureSessionManager;
@property (strong, nonatomic) IFGCaptureFileOutput                              *captureMovieFileOutput;

@end

@interface IFGViewController (IFGCaptureFileOutputDelegate) <IFGCaptureFileOutputDelegate>

- (void)captureFileOutputDidStart:(IFGCaptureFileOutput *)captureFileOutput;
- (void)captureFileOutputDidStop:(IFGCaptureFileOutput *)captureFileOutput error:(NSError *)captureError;

@end


@implementation IFGViewController (IFGCaptureFileOutputDelegate)

- (void)captureFileOutputDidStart:(IFGCaptureFileOutput *)captureFileOutput {
    [self.recordButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
}

- (void)captureFileOutputDidStop:(IFGCaptureFileOutput *)captureFileOutput error:(NSError *)captureError {
    [self.recordButton setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    captureFileOutput.delegate = self;
    if (self.captureMovieFileOutput == captureFileOutput) {
        self.captureMovieFileOutput = nil;
    }
}

@end

@implementation IFGViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.captureSessionManager = [IFGMediaCaptureSession new];
    [self.captureSessionManager
     setupCaptureSessionWithConfiguration:[IFGMediaCaptureSessionConfiguration
                                           defaultBackCameraConfigurationWithLayer:(AVCaptureVideoPreviewLayer *)self.captureVideoPreviewView.layer]
     onCompletion:^(NSError *error) {
         [self.captureSessionManager start];
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)cameraButtonPressed:(id)sender {
    IFGMediaCaptureSessionConfiguration *configuration = [self.captureSessionManager.configuration copy];
    if (configuration.cameraPosition == AVCaptureDevicePositionBack) {
        configuration.cameraPosition = AVCaptureDevicePositionFront;
    }
    else {
        configuration.cameraPosition = AVCaptureDevicePositionBack;
    }
    [self.captureSessionManager
     setupCaptureSessionWithConfiguration:configuration
     onCompletion:^(NSError *error) {
         // If error do something;
     }];
}

- (IBAction)recordButtonPressed:(id)sender {
    if (!self.captureMovieFileOutput) {
        NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        NSURL *documentsURL = [paths firstObject];
        NSURL *movieFileURL = [documentsURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%.0f.mov", [[NSDate date] timeIntervalSince1970]]];
        self.captureMovieFileOutput = [IFGCaptureFileOutput captureFileOutputToURL:movieFileURL withSession:self.captureSessionManager];
        self.captureMovieFileOutput.delegate = self;
        [self.captureMovieFileOutput startRecordingOnCompletion:^(NSError *error) {
        }];
    }
    else {
        [self.captureMovieFileOutput stopRecordingOnCompletion:^(NSError *error) {
            
        }];
    }
}

@end
