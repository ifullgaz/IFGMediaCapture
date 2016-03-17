//
//  IFGCaptureFileOutput.h
//  Pods
//
//  Created by Emmanuel Merali on 17/03/2016.
//
//

#import <Foundation/Foundation.h>
#import "IFGMediaCaptureSession.h"

@class IFGCaptureFileOutput;

// Protocol to let the owner know what's going on
@protocol IFGCaptureFileOutputDelegate <NSObject>

@optional
- (void)captureFileOutputDidStart:(IFGCaptureFileOutput *)captureFileOutput;
- (void)captureFileOutputDidStop:(IFGCaptureFileOutput *)captureFileOutput error:(NSError *)captureError;

@end

// Capture the session to a file
@interface IFGCaptureFileOutput : NSObject

@property (weak, nonatomic) id<IFGCaptureFileOutputDelegate>                    delegate;
@property (strong, nonatomic, readonly) NSURL                                   *outputFileURL;

+ (instancetype)captureFileOutputToURL:(NSURL *)outputFileURL withSession:(IFGMediaCaptureSession *)captureSession;

- (void)startRecordingOnCompletion:(IFGMediaCaptureSessionSetupCompletionBlock)completionBlock;
- (void)stopRecordingOnCompletion:(IFGMediaCaptureSessionSetupCompletionBlock)completionBlock;
- (void)saveToLibraryOnCompletion:(IFGMediaCaptureSessionSetupCompletionBlock)completionBlock;
- (BOOL)isRecording;

@end

