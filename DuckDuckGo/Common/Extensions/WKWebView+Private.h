//
//  WKWebView+SessionState.h
//  DuckDuckGo
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
#import <WebKit/WebKit.h>
#import "_WKDownload.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, _WKMediaCaptureStateDeprecated) {
    _WKMediaCaptureStateDeprecatedNone = 0,
    _WKMediaCaptureStateDeprecatedActiveMicrophone = 1 << 0,
    _WKMediaCaptureStateDeprecatedActiveCamera = 1 << 1,
    _WKMediaCaptureStateDeprecatedMutedMicrophone = 1 << 2,
    _WKMediaCaptureStateDeprecatedMutedCamera = 1 << 3,
};
typedef NS_OPTIONS(NSUInteger, _WKMediaMutedState) {
    _WKMediaNoneMuted = 0,
    _WKMediaAudioMuted = 1 << 0,
    _WKMediaCaptureDevicesMuted = 1 << 1,
    _WKMediaScreenCaptureMuted = 1 << 2,
};

#ifndef __MAC_12

typedef NS_ENUM(NSInteger, WKMediaCaptureType) {
    WKMediaCaptureTypeCamera,
    WKMediaCaptureTypeMicrophone,
    WKMediaCaptureTypeCameraAndMicrophone,
} API_AVAILABLE(macosx(11.3));

typedef NS_ENUM(NSInteger, WKPermissionDecision) {
    WKPermissionDecisionPrompt,
    WKPermissionDecisionGrant,
    WKPermissionDecisionDeny,
} API_AVAILABLE(macosx(11.3));

typedef NS_OPTIONS(NSUInteger, _WKCaptureDevices) {
    _WKCaptureDeviceMicrophone = 1 << 0,
    _WKCaptureDeviceCamera = 1 << 1,
    _WKCaptureDeviceDisplay = 1 << 2,
} API_AVAILABLE(macosx(10.3));

typedef NS_ENUM(NSInteger, WKMediaCaptureState) {
    WKMediaCaptureStateNone,
    WKMediaCaptureStateActive,
    WKMediaCaptureStateMuted,
} API_AVAILABLE(macos(12.0), ios(15.0));;

#endif

@interface WKWebView (Private)

- (void)_restoreFromSessionStateData:(NSData *)data;
- (NSData * _Nullable)_sessionStateData;

- (void)createWebArchiveDataWithCompletionHandler:(void (^)(NSData * _Nullable, NSError * _Nullable))completionHandler;
- (void)createPDFWithConfiguration:(id _Nullable)pdfConfiguration completionHandler:(void (^)(NSData * _Nullable pdfDocumentData, NSError * _Nullable error))completionHandler;

#ifndef __MAC_12

@property (nonatomic, readonly) WKMediaCaptureState cameraCaptureState API_AVAILABLE(macos(12.0), ios(15.0));
@property (nonatomic, readonly) WKMediaCaptureState microphoneCaptureState API_AVAILABLE(macos(12.0), ios(15.0));

#endif

@property (nonatomic, readonly) _WKMediaCaptureStateDeprecated _mediaCaptureState;

- (void)setMicrophoneCaptureState:(WKMediaCaptureState)state completionHandler:(void (^)(void))completionHandler API_AVAILABLE(macos(12.0), ios(15.0));
- (void)setCameraCaptureState:(WKMediaCaptureState)state completionHandler:(void (^)(void))completionHandler API_AVAILABLE(macos(12.0), ios(15.0));
- (void)_stopMediaCapture;

- (_WKMediaMutedState)_mediaMutedState;
- (void)_setPageMuted:(_WKMediaMutedState)mutedState;

- (NSPrintOperation *)_printOperationWithPrintInfo:(NSPrintInfo *)printInfo;
@end

NS_ASSUME_NONNULL_END
