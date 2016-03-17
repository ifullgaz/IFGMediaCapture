//
//  IFGCaptureFileOutput.m
//  Pods
//
//  Created by Emmanuel Merali on 17/03/2016.
//
//

#import "IFGCaptureFileOutput.h"
#import <AVFoundation/AVFoundation.h>

static dispatch_queue_t                                                         captureFileOutputQueue;

@interface IFGCaptureFileOutput ()

@property (weak, nonatomic) IFGMediaCaptureSession                              *captureSession;
@property (strong, nonatomic) NSURL                                             *outputFileURL;
@property (strong, nonatomic) AVAssetWriter                                     *assetWriter;
@property (weak, nonatomic) AVAssetWriterInput                                  *videoWriterInput;
@property (weak, nonatomic) AVAssetWriterInput                                  *audioWriterInput;

@end

@interface IFGCaptureFileOutput (Private)

- (void)recordVideoFrame:(CMSampleBufferRef)sampleBuffer;
- (void)recordAudioFrame:(CMSampleBufferRef)sampleBuffer;
- (void)setMetaData;

@end

@interface IFGCaptureFileOutput (IFGMediaCaptureSessionOutputObserver) <IFGMediaCaptureSessionOutputObserver>

- (void)captureSessionManager:(IFGMediaCaptureSession *)captureSessionManager didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(NSString *)mediaType;
- (void)captureSessionManager:(IFGMediaCaptureSession *)captureSessionManager didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(NSString *)mediaType;

@end


@implementation IFGCaptureFileOutput (Private)

- (void)recordVideoFrame:(CMSampleBufferRef)sampleBuffer {
    if (self.assetWriter.status == AVAssetWriterStatusUnknown) {
        if ([self.assetWriter startWriting]) {
            CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            [self.assetWriter startSessionAtSourceTime:presentationTime];
        }
    }
    CFRetain(sampleBuffer);
    dispatch_async(captureFileOutputQueue, ^{
        if (self.assetWriter.status == AVAssetWriterStatusWriting &&
            [self.videoWriterInput isReadyForMoreMediaData]) {
            [self.videoWriterInput appendSampleBuffer:sampleBuffer];
        }
        CFRelease(sampleBuffer);
    });
}

- (void)recordAudioFrame:(CMSampleBufferRef)sampleBuffer {
    if (self.assetWriter.status == AVAssetWriterStatusUnknown) {
        return;
    }
    CFRetain(sampleBuffer);
    dispatch_async(captureFileOutputQueue, ^{
        if (self.assetWriter.status == AVAssetWriterStatusWriting &&
            [self.audioWriterInput isReadyForMoreMediaData]) {
            [self.audioWriterInput appendSampleBuffer:sampleBuffer];
        }
        CFRelease(sampleBuffer);
    });
}

- (void)setMetaData {}

@end

@implementation IFGCaptureFileOutput (IFGMediaCaptureSessionOutputObserver)

- (void)captureSessionManager:(IFGMediaCaptureSession *)captureSessionManager didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(NSString *)mediaType {
    if ([mediaType isEqualToString:AVMediaTypeVideo]) {
        [self recordVideoFrame:sampleBuffer];
    }
    else if ([mediaType isEqualToString:AVMediaTypeAudio]) {
        [self recordAudioFrame:sampleBuffer];
    }
}

- (void)captureSessionManager:(IFGMediaCaptureSession *)captureSessionManager didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(NSString *)mediaType {}

@end

@implementation IFGCaptureFileOutput

+ (instancetype)captureFileOutputToURL:(NSURL *)outputFileURL withSession:(IFGMediaCaptureSession *)captureSession {
    IFGCaptureFileOutput *captureFileOutput = [[self class] new];
    captureFileOutput.captureSession = captureSession;
    captureFileOutput.outputFileURL = outputFileURL;
    return captureFileOutput;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            captureFileOutputQueue = dispatch_queue_create("IFGCaptureFileOutputQueue", DISPATCH_QUEUE_SERIAL);
        });
    }
    return self;
}

- (void)startRecordingOnCompletion:(IFGMediaCaptureSessionSetupCompletionBlock)completionBlock {
    if (!self.assetWriter) {
        NSError *error = nil;
        NSDictionary *settings;
        self.assetWriter = [[AVAssetWriter alloc] initWithURL:self.outputFileURL fileType:AVFileTypeMPEG4 error:&error];
        self.assetWriter.shouldOptimizeForNetworkUse = YES;
        CGSize videoSize = self.captureSession.videoSize;
        settings = @{
                     AVVideoCodecKey: AVVideoCodecH264,
                     AVVideoWidthKey: [NSNumber numberWithInt:videoSize.width],
                     AVVideoHeightKey: [NSNumber numberWithInt:videoSize.height]
                     };
        AVAssetWriterInput *videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
        videoWriterInput.expectsMediaDataInRealTime = YES;
        
        // Add the audio input
        AudioChannelLayout acl;
        bzero(&acl, sizeof(acl));
        acl.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
        settings = @{
                     AVFormatIDKey: [NSNumber numberWithInt:kAudioFormatMPEG4AAC],
                     AVNumberOfChannelsKey: [NSNumber numberWithInt:2],
                     AVSampleRateKey:  [NSNumber numberWithFloat:44100.0],
                     AVChannelLayoutKey: [NSData dataWithBytes:&acl length: sizeof(AudioChannelLayout)],
                     AVEncoderBitRateKey: [NSNumber numberWithInt:64000]
                     };
        AVAssetWriterInput *audioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:settings];
        audioWriterInput.expectsMediaDataInRealTime = YES;
        
        // add input
        if([self.assetWriter canAddInput:videoWriterInput]) {
            [self.assetWriter addInput:videoWriterInput];
            self.videoWriterInput = videoWriterInput;
        }
        if([self.assetWriter canAddInput:audioWriterInput]) {
            [self.assetWriter addInput:audioWriterInput];
            self.audioWriterInput = audioWriterInput;
        }
        [self setMetaData];
        [self.captureSession registerInterestInOutput:self onCompletion:^(NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(captureFileOutputDidStart:)]) {
                    [self.delegate captureFileOutputDidStart:self];
                }
                completionBlock(error);
            });
        }];
    }
}

- (void)stopRecordingOnCompletion:(IFGMediaCaptureSessionSetupCompletionBlock)completionBlock {
    [self.videoWriterInput markAsFinished];
    [self.assetWriter finishWritingWithCompletionHandler:^{
        dispatch_async(captureFileOutputQueue, ^{
            self.assetWriter = nil;
            [self.captureSession unregisterInterestInOutput:self onCompletion:^(NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([self.delegate respondsToSelector:@selector(captureFileOutputDidStop:error:)]) {
                        [self.delegate captureFileOutputDidStop:self error:error];
                    }
                    completionBlock(nil);
                });
            }];
        });
    }];
}

- (void)saveToLibraryOnCompletion:(IFGMediaCaptureSessionSetupCompletionBlock)completionBlock {
    
}

- (BOOL)isRecording {
    return self.assetWriter.status == AVAssetWriterStatusWriting;
}

//- (IBAction)tapStartRecord:(id)sender {
//    if([[btnRecord titleForState:UIControlStateNormal] isEqualToString:@"START"]) {
//        [btnRecord setTitle:@"STOP" forState:UIControlStateNormal];
//        isCapturingInput=YES;
//    }
//    else if([[btnRecord titleForState:UIControlStateNormal] isEqualToString:@"STOP"]) {
//        isCapturingInput=NO;
//        dispatch_async(_captureQueue, ^{
//            [self.assetWriter finishWritingWithCompletionHandler:^{
//                ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
//                [library writeVideoAtPathToSavedPhotosAlbum:recordingFile completionBlock:^(NSURL *assetURL, NSError *error) {
//                    if (error) {
//                        NSLog(@"assets library failed (%@)", error);
//                    }
//                    else {
//                        NSLog(@"file saved to library");
//                    }
//                    [self.captureSession stopRunning];
//                    self.assetWriter=nil;
//                    recordingFile = nil;
//                }];
//            }];
//            
//        });
//        
//        [btnRecord setTitle:@"START" forState:UIControlStateNormal];
//    }
//}

@end

