//
//  IFGMediaCaptureTypes.h
//  Pods
//
//  Created by Emmanuel Merali on 20/03/2016.
//
//

#ifndef IFGMediaCaptureTypes_h
#define IFGMediaCaptureTypes_h

typedef enum {
    IFGMediaCaptureMediaTypeUnknown = 0,
    IFGMediaCaptureMediaTypeVideo,
    IFGMediaCaptureMediaTypeAudio
} IFGMediaCaptureMediaType;

#define IFGMediaCaptureSessionErrorDomain @"IFGMediaCaptureSessionErrorDomain"

typedef enum {
    IFGMediaCaptureSessionErrorPreset            = -1,
    IFGMediaCaptureSessionErrorNoVideoDevice     = -2,
    IFGMediaCaptureSessionErrorPresetVideoDevice = -3,
    IFGMediaCaptureSessionErrorNoAudioDevice     = -4
} IFGMediaCaptureSessionError;

typedef enum {
    IFGMediaCaptureSessionStateCreated,
    IFGMediaCaptureSessionStateConfiguring,
    IFGMediaCaptureSessionStateStarting,
    IFGMediaCaptureSessionStateRunning,
    IFGMediaCaptureSessionStateStopping,
    IFGMediaCaptureSessionStateStopped
} IFGMediaCaptureSessionState;

typedef enum {
    IFGMediaCaptureSessionAuthorisationHelperTypeVideo    = 1<<0,
    IFGMediaCaptureSessionAuthorisationHelperTypeAudio    = 1<<1,
    IFGMediaCaptureSessionAuthorisationHelperTypeLibrary  = 1<<2,
    IFGMediaCaptureSessionAuthorisationHelperTypeLocation = 1<<3,
} IFGMediaCaptureSessionAuthorisationHelperType;

typedef enum {
    IFGMediaCaptureSessionConfigurationChoiceNo = 0,
    IFGMediaCaptureSessionConfigurationChoiceYes,
    IFGMediaCaptureSessionConfigurationChoiceOptional
} IFGMediaCaptureSessionConfigurationChoice;

typedef void(^IFGMediaCaptureSessionAuthorisationHelperCompletionBlock)(BOOL granted);
typedef void(^IFGMediaCaptureSessionSetupCompletionBlock)(NSError *error);
typedef void(^IFGMediaCaptureSessionValidationCompletionBlock)(id result, NSError *error);
typedef void(^IFGMediaCaptureBlockingErrorBlock)(NSError *error);

#endif /* IFGMediaCaptureTypes_h */
