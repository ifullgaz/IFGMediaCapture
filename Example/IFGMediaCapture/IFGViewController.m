//
//  IFGViewController.m
//  IFGMediaCapture
//
//  Created by ifullgaz on 03/16/2016.
//  Copyright (c) 2016 ifullgaz. All rights reserved.
//

#import "IFGViewController.h"
#import <IFGMediaCapture/IFGMediaCapture.h>
#import <AVKit/AVKit.h>

@interface IFGViewController ()

@property (weak, nonatomic) IBOutlet IFGCaptureVideoPreviewView                 *captureVideoPreviewView;
@property (weak, nonatomic) IBOutlet UIButton                                   *recordButton;
@property (strong, nonatomic) IFGMediaCaptureSession                            *captureSessionManager;
@property (strong, nonatomic) IFGCaptureFileOutput                              *captureMovieFileOutput;

@end

@interface IFGViewController (IFGCaptureFileOutputDelegate) <IFGCaptureFileOutputDelegate>

- (void)captureFileOutputDidStartRecording:(IFGCaptureFileOutput *)captureFileOutput;
- (void)captureFileOutputDidStopRecording:(IFGCaptureFileOutput *)captureFileOutput;

@end


@implementation IFGViewController (IFGCaptureFileOutputDelegate)

- (void)captureFileOutputDidStartRecording:(IFGCaptureFileOutput *)captureFileOutput {
    [self.recordButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
}

- (void)captureFileOutputDidStopRecording:(IFGCaptureFileOutput *)captureFileOutput {
    [self.recordButton setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    captureFileOutput.delegate = self;
    if (self.captureMovieFileOutput == captureFileOutput) {
        self.captureMovieFileOutput = nil;
        [self performSegueWithIdentifier:@"ShowPlayerSegue" sender:captureFileOutput.outputFileURL];
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
        [self.captureMovieFileOutput start];
    }
    else {
        [self.captureMovieFileOutput stop];
    }
}

- (IBAction)pauseAudioButtonPressed:(id)sender {
    if ([self.captureMovieFileOutput paused]) {
        [self.captureMovieFileOutput resume];
    }
    else {
        [self.captureMovieFileOutput pause];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSString *segueIdentifier = segue.identifier;
    if ([segueIdentifier isEqualToString:@"ShowPlayerSegue"]) {
        AVPlayerViewController *viewController = (AVPlayerViewController *)segue.destinationViewController;
        viewController.player = [AVPlayer playerWithURL:sender];
    }
}

@end
