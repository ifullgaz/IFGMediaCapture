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
@property (strong, nonatomic) AVAssetWriterInput                                *videoWriterInput;
@property (strong, nonatomic) AVAssetWriterInputPixelBufferAdaptor              *videoWriterInputAdaptor;
@property (strong, nonatomic) AVAssetWriterInput                                *audioWriterInput;
@property (assign, nonatomic) BOOL                                              videoWriterInputConfigured;
@property (assign, nonatomic) BOOL                                              audioWriterInputConfigured;
@property (assign, nonatomic) CMTime                                            recordingTime;
@property (assign, nonatomic) CMTime                                            relativeTime;
@property (assign, nonatomic) CMTime                                            lastVideoTime;
@property (assign, nonatomic) CMTime                                            lastAudioTime;
@property (assign, atomic) BOOL                                                 paused;
@property (assign, atomic) BOOL                                                 needResume;

@end

@interface IFGCaptureFileOutput (Private)

+ (NSDictionary *)defaultOutputVideoSettingsForSession:(IFGMediaCaptureSession *)captureSession;
+ (NSDictionary *)defaultOutputAudioSettingsForSession:(IFGMediaCaptureSession *)captureSession;
+ (NSDictionary *)videoWriterInputAdaptorAttributesForSettings:(NSDictionary *)settings;
- (BOOL)hasVideoInput;
- (BOOL)hasAudioInput;
- (void)createVideoInputForSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)createAudioInputForSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)createWritingSession;
- (CMSampleBufferRef)createSampleBufferByPrepending:(CMItemCount)numberOfSamples silentAudioSamplesToSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (CMSampleBufferRef)createSampleBufferWithAdjustedPresentationTimeFromSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (CMSampleBufferRef)createAdjustedAudioSampleBufferFromSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)writeVideoFrame:(CMSampleBufferRef)sampleBuffer;
- (void)recordVideoFrame:(CMSampleBufferRef)sampleBuffer;
- (void)writeAudioFrame:(CMSampleBufferRef)sampleBuffer;
- (void)recordAudioFrame:(CMSampleBufferRef)sampleBuffer;
- (void)setMetaData;
- (void)reset;

@end

@interface IFGCaptureFileOutput (IFGMediaCaptureSessionOutputObserver) <IFGMediaCaptureSessionOutputObserver>

- (void)captureSessionManager:(IFGMediaCaptureSession *)captureSessionManager didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(IFGMediaCaptureMediaType)mediaType;
- (void)captureSessionManager:(IFGMediaCaptureSession *)captureSessionManager didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(IFGMediaCaptureMediaType)mediaType;

@end


@implementation IFGCaptureFileOutput (Private)

+ (NSDictionary *)defaultOutputVideoSettingsForSession:(IFGMediaCaptureSession *)captureSession {
    CGSize videoSize = captureSession.videoSize;
    return @{
             AVVideoCodecKey: AVVideoCodecH264,
             AVVideoWidthKey: [NSNumber numberWithInt:videoSize.width],
             AVVideoHeightKey: [NSNumber numberWithInt:videoSize.height]
             };
}

+ (NSDictionary *)defaultOutputAudioSettingsForSession:(IFGMediaCaptureSession *)captureSession {
    AudioChannelLayout acl;
    bzero(&acl, sizeof(acl));
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
    return @{
             AVFormatIDKey: [NSNumber numberWithInt:kAudioFormatMPEG4AAC],
             AVNumberOfChannelsKey: [NSNumber numberWithInt:1],
             AVSampleRateKey:  [NSNumber numberWithFloat:44100.0],
             AVChannelLayoutKey: [NSData dataWithBytes:&acl length: sizeof(AudioChannelLayout)],
             AVEncoderBitRateKey: [NSNumber numberWithInt:64000]
             };
}

+ (NSDictionary *)videoWriterInputAdaptorAttributesForSettings:(NSDictionary *)settings {
  return @{
    (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_32BGRA],
    (id)kCVPixelBufferWidthKey : [settings objectForKey:AVVideoWidthKey],
    (id)kCVPixelBufferHeightKey : [settings objectForKey:AVVideoHeightKey]
    };
}

// Should always be called on the captureFileOutputQueue
- (BOOL)hasVideoInput {
    return self.videoWriterInput != nil;
}

// Should always be called on the captureFileOutputQueue
- (BOOL)hasAudioInput {
    return self.audioWriterInput != nil;
}

#pragma mark Recording session setup
// Should always be called on the captureFileOutputQueue
- (void)createVideoInputForSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    NSDictionary *settings;
    settings = self.videoOutputSettings ?: [IFGCaptureFileOutput defaultOutputVideoSettingsForSession:self.captureSession];
    self.videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
    self.videoWriterInput.expectsMediaDataInRealTime = YES;
    NSDictionary *pixelBufferAttributes = [IFGCaptureFileOutput videoWriterInputAdaptorAttributesForSettings:settings];
    self.videoWriterInputAdaptor = [AVAssetWriterInputPixelBufferAdaptor
                                    assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.videoWriterInput
                                    sourcePixelBufferAttributes:pixelBufferAttributes];
    self.videoWriterInputConfigured = YES;
    if (self.audioWriterInputConfigured) {
        [self createWritingSession];
    }
}

// Should always be called on the captureFileOutputQueue
- (void)createAudioInputForSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    NSDictionary *settings;
    // Add the audio input
    settings = self.audioOutputSettings ?: [IFGCaptureFileOutput defaultOutputAudioSettingsForSession:self.captureSession];
    self.audioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:settings];
    self.audioWriterInput.expectsMediaDataInRealTime = YES;
    self.audioWriterInputConfigured = YES;
    if (self.videoWriterInputConfigured) {
        [self createWritingSession];
    }
}

- (void)createWritingSession {
    NSError *error = nil;
    self.assetWriter = [[AVAssetWriter alloc] initWithURL:self.outputFileURL fileType:AVFileTypeMPEG4 error:&error];
    self.assetWriter.shouldOptimizeForNetworkUse = YES;
    if ([self.assetWriter canAddInput:self.videoWriterInput]) {
        [self.assetWriter addInput:self.videoWriterInput];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(captureFileOutput:didAddInputOfType:)]) {
                [self.delegate captureFileOutput:self didAddInputOfType:IFGMediaCaptureMediaTypeVideo];
            }
        });
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(captureFileOutput:didFailToAddInputOfType:)]) {
                [self.delegate captureFileOutput:self didFailToAddInputOfType:IFGMediaCaptureMediaTypeVideo];
            }
        });
    }
    if ([self.assetWriter canAddInput:self.audioWriterInput]) {
        [self.assetWriter addInput:self.audioWriterInput];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(captureFileOutput:didAddInputOfType:)]) {
                [self.delegate captureFileOutput:self didAddInputOfType:IFGMediaCaptureMediaTypeAudio];
            }
        });
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(captureFileOutput:didFailToAddInputOfType:)]) {
                [self.delegate captureFileOutput:self didFailToAddInputOfType:IFGMediaCaptureMediaTypeAudio];
            }
        });
    }
    [self setMetaData];
    if ([self.assetWriter startWriting]) {
        [self.assetWriter startSessionAtSourceTime:kCMTimeZero];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(captureFileOutputDidStartRecording:)]) {
                [self.delegate captureFileOutputDidStartRecording:self];
            }
        });
    }
}

#pragma mark Buffer adjustment

// From http://stackoverflow.com/questions/34441648/create-a-silent-audio-cmsamplebufferref
- (CMSampleBufferRef)createSampleBufferByPrepending:(CMItemCount)numberOfSamples silentAudioSamplesToSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    OSStatus status;
    CMBlockBufferRef fillerSampleDataBuffer;
    // Get number of frames per sample
    CMItemCount sampleBufferNumberOfFrames = CMSampleBufferGetNumSamples(sampleBuffer);
    // Get the sample buffer format description
    CMFormatDescriptionRef sampleBufferFormat = CMSampleBufferGetFormatDescription(sampleBuffer);
    // From the description we can extract the audio stream description
    const AudioStreamBasicDescription *sampleBufferAudioStreamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(sampleBufferFormat);
    // Get the number of bytes per frame
    UInt32 bytesPerFrame = sampleBufferAudioStreamDescription->mBytesPerFrame;
    // Get the sample rate
    UInt32 sampleRate = sampleBufferAudioStreamDescription->mSampleRate;
    // Calculate the size in bytes of the new filler data block
    size_t fillerSampleDataSize = numberOfSamples * bytesPerFrame * sampleBufferNumberOfFrames;
    // Create the filler sample block buffer
    status = CMBlockBufferCreateWithMemoryBlock(
                                                kCFAllocatorDefault,            // Use default CMBlockBuffer allocator
                                                nil,                            // Memory block
                                                fillerSampleDataSize,           // Number of bytes to allocate
                                                nil,                            // Default allocator
                                                nil,                            // No custom block source
                                                0,                              // Offset into the data block
                                                fillerSampleDataSize,           // Size of the data block
                                                0,                              // Flags
                                                &fillerSampleDataBuffer);
    assert(status == kCMBlockBufferNoErr);
    // Ensure that the block is initialized to 0s
    status = CMBlockBufferFillDataBytes(0, fillerSampleDataBuffer, 0, fillerSampleDataSize);
    assert(status == kCMBlockBufferNoErr);
    // Append the sample buffer data to the filler data
    CMBlockBufferRef sampleBufferDataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    status = CMBlockBufferAppendBufferReference(
                                                fillerSampleDataBuffer,         // Destination block buffer
                                                sampleBufferDataBuffer,         // The block buffer to append
                                                0,                              // Offset into the data to append
                                                0,                              // Use the data length from the block to append
                                                0);                             // Flags
    CMAudioFormatDescriptionRef fillerSampleFormatDescription;
    status = CMAudioFormatDescriptionCreate(
                                            kCFAllocatorDefault,                // Use default allocator
                                            sampleBufferAudioStreamDescription, // Audio format description
                                            0,                                  // Layout size
                                            nil,                                // Layout
                                            0,                                  // Magic cookie size
                                            nil,                                // Magic cookie
                                            nil,                                // Extensions
                                            &fillerSampleFormatDescription);
    assert(status == noErr);
    CMSampleBufferRef fillerSampleBuffer;
    CMTime fillerSamplePresentationTime = CMTimeConvertScale(self.recordingTime, sampleRate, kCMTimeRoundingMethod_RoundHalfAwayFromZero);
    status = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
                                                                  kCFAllocatorDefault,                          // Default allocator
                                                                  fillerSampleDataBuffer,                       // Block buffer with the data
                                                                  fillerSampleFormatDescription,                // Format description
                                                                  (numberOfSamples + 1) * sampleBufferNumberOfFrames,  // Total number of samples in the sample buffer
                                                                  fillerSamplePresentationTime,                 // Presentation time of the sample buffer
                                                                  nil,                                          // Packet description
                                                                  &fillerSampleBuffer);
    assert(status == noErr);
    CFRelease(fillerSampleFormatDescription);
    CFRelease(fillerSampleDataBuffer);
    return fillerSampleBuffer;
}

//
// The following function is from http://www.gdcl.co.uk/2013/02/20/iPhone-Pause.html
//
- (CMSampleBufferRef)createSampleBufferWithAdjustedPresentationTimeFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    // Initialise the global time offset
    if (CMTIME_IS_INVALID(self.relativeTime)) {
        CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        self.relativeTime = presentationTime;
    }
    CMItemCount count;
    CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, 0, nil, &count);
    CMSampleTimingInfo *timingInfoArray = malloc(sizeof(CMSampleTimingInfo) * count);
    CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, count, timingInfoArray, &count);
    
    for (CMItemCount i = 0; i < count; i++) {
        timingInfoArray[i].presentationTimeStamp = CMTimeSubtract(timingInfoArray[i].presentationTimeStamp, self.relativeTime);
        timingInfoArray[i].decodeTimeStamp = CMTimeSubtract(timingInfoArray[i].decodeTimeStamp, self.relativeTime);
    }
    
    CMSampleBufferRef adjustedSampleBuffer;
    CMSampleBufferCreateCopyWithNewTiming(nil, sampleBuffer, count, timingInfoArray, &adjustedSampleBuffer);
    free(timingInfoArray);
    return adjustedSampleBuffer;
}

- (CMSampleBufferRef)createAdjustedAudioSampleBufferFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CMSampleBufferRef adjustedSampleBuffer;
    adjustedSampleBuffer = [self createSampleBufferWithAdjustedPresentationTimeFromSampleBuffer:sampleBuffer];
    CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(adjustedSampleBuffer);
    CMTime duration = CMSampleBufferGetDuration(adjustedSampleBuffer);
    CMTime diff = CMTimeSubtract(presentationTime, self.lastAudioTime);
    if (CMTIME_COMPARE_INLINE(diff, >, duration)) {
        CMItemCount numberOfSilentSamples = CMTimeGetSeconds(diff) / CMTimeGetSeconds(duration);
        sampleBuffer = [self createSampleBufferByPrepending:numberOfSilentSamples silentAudioSamplesToSampleBuffer:adjustedSampleBuffer];
        CFRelease(adjustedSampleBuffer);
        return sampleBuffer;
    }
    return adjustedSampleBuffer;
}

#pragma mark Video processing

- (void)writeVideoFrame:(CMSampleBufferRef)sampleBuffer {
    sampleBuffer = [self createSampleBufferWithAdjustedPresentationTimeFromSampleBuffer:sampleBuffer];
    CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    // Make sure we don't output old samples
    if (CMTIME_COMPARE_INLINE(presentationTime, >=, kCMTimeZero)) {
        // Get the pixelf buffer from the sample buffer
        // It will allow us to plug in some filters if we want to
        CVPixelBufferRef samplePixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        if ([self.videoWriterInputAdaptor appendPixelBuffer:samplePixelBuffer withPresentationTime:presentationTime]) {
            // Get the sample duration to adjust the recording time
            CMTime duration = CMSampleBufferGetDuration(sampleBuffer);
            CMTime recordingTime = CMTimeAdd(presentationTime, duration);
            if (CMTIME_COMPARE_INLINE(self.recordingTime, >, kCMTimeZero)) {
                if (CMTIME_COMPARE_INLINE(recordingTime, >, self.recordingTime)) {
                    self.recordingTime = recordingTime;
                }
            }
            else {
                self.recordingTime = recordingTime;
            }
            self.lastVideoTime = recordingTime;
        }
    }
    CFRelease(sampleBuffer);
}

- (void)recordVideoFrame:(CMSampleBufferRef)sampleBuffer {
    if (self.assetWriter.status == AVAssetWriterStatusUnknown) {
        if (![self hasVideoInput] && !self.videoWriterInputConfigured) {
            [self createVideoInputForSampleBuffer:sampleBuffer];
        }
    }
    if (self.assetWriter.status == AVAssetWriterStatusWriting &&
        [self.videoWriterInput isReadyForMoreMediaData] &&
        [self hasVideoInput]) {
        [self writeVideoFrame:sampleBuffer];
    }
}

#pragma mark Audio processing

- (void)writeAudioFrame:(CMSampleBufferRef)sampleBuffer {
    sampleBuffer = [self createAdjustedAudioSampleBufferFromSampleBuffer:sampleBuffer];
    CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    // Make sure we don't output old samples
    if (CMTIME_COMPARE_INLINE(presentationTime, >=, kCMTimeZero)) {
        if ([self.audioWriterInput appendSampleBuffer:sampleBuffer]) {
            // Get the sample duration to adjust the recording time
            CMTime duration = CMSampleBufferGetDuration(sampleBuffer);
            CMTime lastAudioTime = CMTimeAdd(presentationTime, duration);
            if (CMTIME_COMPARE_INLINE(self.recordingTime, >, kCMTimeZero)) {
                if (CMTIME_COMPARE_INLINE(lastAudioTime, >, self.recordingTime)) {
                    self.recordingTime = lastAudioTime;
                }
            }
            else {
                self.recordingTime = lastAudioTime;
            }
            self.lastAudioTime = lastAudioTime;
            
        }
    }
    CFRelease(sampleBuffer);
}

- (void)recordAudioFrame:(CMSampleBufferRef)sampleBuffer {
    if (self.assetWriter.status == AVAssetWriterStatusUnknown) {
        if (![self hasAudioInput] && !self.audioWriterInputConfigured) {
            [self createAudioInputForSampleBuffer:sampleBuffer];
        }
    }
    if (self.assetWriter.status == AVAssetWriterStatusWriting &&
        [self.audioWriterInput isReadyForMoreMediaData] &&
        [self hasAudioInput] &&
        // Always start recording on a video frame.
        !CMTIME_COMPARE_INLINE(self.recordingTime, ==, kCMTimeZero)) {
        [self writeAudioFrame:sampleBuffer];
    }
}

- (void)setMetaData {}

- (void)reset {
    self.assetWriter = nil;
    self.videoWriterInput = nil;
    self.videoWriterInputAdaptor = nil;
    self.audioWriterInput = nil;
    self.videoWriterInputConfigured = NO;
    self.audioWriterInputConfigured = NO;
    self.recordingTime = kCMTimeZero;
    self.relativeTime = kCMTimeInvalid;
    self.lastVideoTime = kCMTimeZero;
    self.lastAudioTime = kCMTimeZero;
    self.paused = NO;
    self.needResume = NO;
}

@end

@implementation IFGCaptureFileOutput (IFGMediaCaptureSessionOutputObserver)

- (void)captureSessionManager:(IFGMediaCaptureSession *)captureSessionManager didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(IFGMediaCaptureMediaType)mediaType {
    if (self.paused) {
        return;
    }
    CFRetain(sampleBuffer);
    dispatch_async(captureFileOutputQueue, ^{
        if (self.needResume) {
            CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            self.relativeTime = CMTimeSubtract(presentationTime, self.recordingTime);
            self.needResume = NO;
        }
        switch (mediaType) {
            case IFGMediaCaptureMediaTypeVideo:
                [self recordVideoFrame:sampleBuffer];
                break;
            case IFGMediaCaptureMediaTypeAudio:
                [self recordAudioFrame:sampleBuffer];
                break;
            default:
                break;
        }
        CFRelease(sampleBuffer);
    });
}

- (void)captureSessionManager:(IFGMediaCaptureSession *)captureSessionManager didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(IFGMediaCaptureMediaType)mediaType {
    NSLog(@"Dropped frame of type %@", (mediaType == IFGMediaCaptureMediaTypeVideo ? @"Video" : @"Audio"));
}

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
        [self reset];
    }
    return self;
}

- (void)start {
    dispatch_async(captureFileOutputQueue, ^{
        if (!self.assetWriter) {
            [self.captureSession registerInterestInOutput:self onCompletion:^(NSError *error) {}];
        }
    });
}

- (void)stop {
    dispatch_async(captureFileOutputQueue, ^{
        [self.assetWriter finishWritingWithCompletionHandler:^{
            dispatch_async(captureFileOutputQueue, ^{
                [self reset];
                [self.captureSession unregisterInterestInOutput:self onCompletion:^(NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([self.delegate respondsToSelector:@selector(captureFileOutputDidStopRecording:)]) {
                            [self.delegate captureFileOutputDidStopRecording:self];
                        }
                    });
                }];
            });
        }];
    });
}

- (void)pause {
    dispatch_async(captureFileOutputQueue, ^{
        _paused = YES;
        _needResume = YES;
    });
}

- (void)resume {
    dispatch_async(captureFileOutputQueue, ^{
        _paused = NO;
    });
}
@end
