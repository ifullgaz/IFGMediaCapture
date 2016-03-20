//
//  IFGCaptureFileOutput.h
//  Pods
//
//  Created by Emmanuel Merali on 17/03/2016.
//
//

#import <Foundation/Foundation.h>
#import "IFGMediaCaptureSession.h"
#import "IFGMediaCaptureTypes.h"

@class IFGCaptureFileOutput;

// Protocol to let the owner know what's going on
@protocol IFGCaptureFileOutputDelegate <NSObject>

@optional
- (void)captureFileOutputDidStartRecording:(IFGCaptureFileOutput *)captureFileOutput;
- (void)captureFileOutputDidStopRecording:(IFGCaptureFileOutput *)captureFileOutput;
- (void)captureFileOutput:(IFGCaptureFileOutput *)captureFileOutput didAddInputOfType:(IFGMediaCaptureMediaType)mediaType;
- (void)captureFileOutput:(IFGCaptureFileOutput *)captureFileOutput didFailToAddInputOfType:(IFGMediaCaptureMediaType)mediaType;

@end

// Capture the session to a file
@interface IFGCaptureFileOutput : NSObject

@property (weak, nonatomic) id<IFGCaptureFileOutputDelegate>                    delegate;
@property (strong, nonatomic) NSDictionary                                      *videoOutputSettings;
@property (strong, nonatomic) NSDictionary                                      *audioOutputSettings;
@property (strong, nonatomic, readonly) NSURL                                   *outputFileURL;
@property (assign, atomic, readonly) BOOL                                       paused;

+ (instancetype)captureFileOutputToURL:(NSURL *)outputFileURL withSession:(IFGMediaCaptureSession *)captureSession;

- (void)start;
- (void)pause;
- (void)resume;
- (void)stop;

@end

