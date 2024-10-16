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

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, _WKMediaCaptureStateDeprecated) {
    _WKMediaCaptureStateDeprecatedNone = 0,
    _WKMediaCaptureStateDeprecatedActiveMicrophone = 1 << 0,
    _WKMediaCaptureStateDeprecatedActiveCamera = 1 << 1,
    _WKMediaCaptureStateDeprecatedMutedMicrophone = 1 << 2,
    _WKMediaCaptureStateDeprecatedMutedCamera = 1 << 3,
} API_AVAILABLE(macos(10.13), ios(11.0));

typedef NS_OPTIONS(NSUInteger, _WKMediaMutedState) {
    _WKMediaNoneMuted = 0,
    _WKMediaAudioMuted = 1 << 0,
    _WKMediaCaptureDevicesMuted = 1 << 1,
    _WKMediaScreenCaptureMuted = 1 << 2,
} API_AVAILABLE(macos(10.13), ios(11.0));

typedef NS_OPTIONS(NSUInteger, _WKCaptureDevices) {
    _WKCaptureDeviceMicrophone = 1 << 0,
    _WKCaptureDeviceCamera = 1 << 1,
    _WKCaptureDeviceDisplay = 1 << 2,
} API_AVAILABLE(macos(10.13), ios(11.0));

typedef NS_OPTIONS(NSUInteger, _WKFindOptions) {
    _WKFindOptionsCaseInsensitive = 1 << 0,
    _WKFindOptionsAtWordStarts = 1 << 1,
    _WKFindOptionsTreatMedialCapitalAsWordStart = 1 << 2,
    _WKFindOptionsBackwards = 1 << 3,
    _WKFindOptionsWrapAround = 1 << 4,
    _WKFindOptionsShowOverlay = 1 << 5,
    _WKFindOptionsShowFindIndicator = 1 << 6,
    _WKFindOptionsShowHighlight = 1 << 7,
    _WKFindOptionsNoIndexChange = 1 << 8,
    _WKFindOptionsDetermineMatchIndex = 1 << 9,
} API_AVAILABLE(macos(10.10));

@interface WKWebView (Private)

- (void)_restoreFromSessionStateData:(NSData *)data;
- (NSData * _Nullable)_sessionStateData;

@property (nonatomic, readonly) _WKMediaCaptureStateDeprecated _mediaCaptureState API_AVAILABLE(macos(10.15), ios(13.0));

- (void)_stopMediaCapture API_AVAILABLE(macos(10.15.4), ios(13.4));
- (void)_stopAllMediaPlayback;

@end

typedef NS_OPTIONS(NSUInteger, _WKWebExtensionTabChangedProperties) {
    _WKWebExtensionTabChangedPropertiesNone       = 0,
    _WKWebExtensionTabChangedPropertiesAudible    = 1 << 1,
    _WKWebExtensionTabChangedPropertiesLoading    = 1 << 2,
    _WKWebExtensionTabChangedPropertiesMuted      = 1 << 3,
    _WKWebExtensionTabChangedPropertiesPinned     = 1 << 4,
    _WKWebExtensionTabChangedPropertiesReaderMode = 1 << 5,
    _WKWebExtensionTabChangedPropertiesSize       = 1 << 6,
    _WKWebExtensionTabChangedPropertiesTitle      = 1 << 7,
    _WKWebExtensionTabChangedPropertiesURL        = 1 << 8,
    _WKWebExtensionTabChangedPropertiesZoomFactor = 1 << 9,
    _WKWebExtensionTabChangedPropertiesAll        = NSUIntegerMax,
} API_AVAILABLE(macos(13.3));

@class _WKWebExtension;
@class _WKWebExtensionContext;
@class _WKWebExtensionControllerConfiguration;
@class _WKWebExtensionDataRecord;
@protocol _WKWebExtensionControllerDelegate;
typedef NSString * _WKWebExtensionDataType NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(_WKWebExtension.DataType);
@protocol _WKWebExtensionTab;
@protocol _WKWebExtensionWindow <NSObject>;

@end
@interface _WKWebExtensionController

- (instancetype)init;
- (instancetype)initWithConfiguration:(_WKWebExtensionControllerConfiguration *)configuration;

@property (nonatomic, weak) id <_WKWebExtensionControllerDelegate> delegate;
@property (nonatomic, readonly, copy) _WKWebExtensionControllerConfiguration *configuration;


- (BOOL)loadExtensionContext:(_WKWebExtensionContext *)extensionContext error:(NSError **)error;
- (BOOL)unloadExtensionContext:(_WKWebExtensionContext *)extensionContext error:(NSError **)error;
- (nullable _WKWebExtensionContext *)extensionContextForExtension:(_WKWebExtension *)extension NS_SWIFT_NAME(extensionContext(for:));
- (nullable _WKWebExtensionContext *)extensionContextForURL:(NSURL *)URL NS_SWIFT_NAME(extensionContext(for:));

@property (nonatomic, readonly, copy) NSSet<_WKWebExtension *> *extensions;
@property (nonatomic, readonly, copy) NSSet<_WKWebExtensionContext *> *extensionContexts;
@property (class, nonatomic, readonly, copy) NSSet<_WKWebExtensionDataType> *allExtensionDataTypes;

- (void)fetchDataRecordsOfTypes:(NSSet<_WKWebExtensionDataType> *)dataTypes completionHandler:(void (^)(NSArray<_WKWebExtensionDataRecord *> *))completionHandler WK_SWIFT_ASYNC_NAME(dataRecords(ofTypes:));
- (void)fetchDataRecordOfTypes:(NSSet<_WKWebExtensionDataType> *)dataTypes forExtensionContext:(_WKWebExtensionContext *)extensionContext completionHandler:(void (^)(_WKWebExtensionDataRecord * _Nullable))completionHandler WK_SWIFT_ASYNC_NAME(dataRecord(ofTypes:for:));
- (void)removeDataOfTypes:(NSSet<_WKWebExtensionDataType> *)dataTypes forDataRecords:(NSArray<_WKWebExtensionDataRecord *> *)dataRecords completionHandler:(void (^)(void))completionHandler;
- (void)didOpenWindow:(id <_WKWebExtensionWindow>)newWindow;
- (void)didCloseWindow:(id <_WKWebExtensionWindow>)closedWindow;
- (void)didFocusWindow:(nullable id <_WKWebExtensionWindow>)focusedWindow;
- (void)didOpenTab:(id <_WKWebExtensionTab>)newTab;
- (void)didCloseTab:(id <_WKWebExtensionTab>)closedTab windowIsClosing:(BOOL)windowIsClosing;
- (void)didActivateTab:(id<_WKWebExtensionTab>)activatedTab previousActiveTab:(nullable id<_WKWebExtensionTab>)previousTab;
- (void)didSelectTabs:(NSSet<id <_WKWebExtensionTab>> *)selectedTabs;
- (void)didDeselectTabs:(NSSet<id <_WKWebExtensionTab>> *)deselectedTabs;
- (void)didMoveTab:(id <_WKWebExtensionTab>)movedTab fromIndex:(NSUInteger)index inWindow:(nullable id <_WKWebExtensionWindow>)oldWindow NS_SWIFT_NAME(didMoveTab(_:from:in:));
- (void)didReplaceTab:(id <_WKWebExtensionTab>)oldTab withTab:(id <_WKWebExtensionTab>)newTab NS_SWIFT_NAME(didReplaceTab(_:with:));
- (void)didChangeTabProperties:(_WKWebExtensionTabChangedProperties)properties forTab:(id <_WKWebExtensionTab>)changedTab NS_SWIFT_NAME(didChangeTabProperties(_:for:));

@end

@class NSImage;

@interface _WKWebExtension : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (void)extensionWithAppExtensionBundle:(NSBundle *)appExtensionBundle completionHandler:(void (^)(_WKWebExtension * _Nullable extension, NSError * _Nullable error))completionHandler WK_SWIFT_ASYNC_THROWS_ON_FALSE(1);
+ (void)extensionWithResourceBaseURL:(NSURL *)resourceBaseURL completionHandler:(void (^)(_WKWebExtension * _Nullable extension, NSError * _Nullable error))completionHandler WK_SWIFT_ASYNC_THROWS_ON_FALSE(1);

@property (nonatomic, readonly, copy) NSArray<NSError *> *errors;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *manifest;
@property (nonatomic, readonly) double manifestVersion;

- (BOOL)supportsManifestVersion:(double)manifestVersion;

@property (nonatomic, nullable, readonly, copy) NSLocale *defaultLocale;
@property (nonatomic, nullable, readonly, copy) NSString *displayName;
@property (nonatomic, nullable, readonly, copy) NSString *displayShortName;
@property (nonatomic, nullable, readonly, copy) NSString *displayVersion;
@property (nonatomic, nullable, readonly, copy) NSString *displayDescription;
@property (nonatomic, nullable, readonly, copy) NSString *displayActionLabel;
@property (nonatomic, nullable, readonly, copy) NSString *version;

#if TARGET_OS_IPHONE
- (nullable UIImage *)iconForSize:(CGSize)size;
#else
- (nullable NSImage *)iconForSize:(CGSize)size;
#endif

#if TARGET_OS_IPHONE
- (nullable UIImage *)actionIconForSize:(CGSize)size;
#else
- (nullable NSImage *)actionIconForSize:(CGSize)size;
#endif

//@property (nonatomic, readonly, copy) NSSet<_WKWebExtensionPermission> *requestedPermissions;

//@property (nonatomic, readonly, copy) NSSet<_WKWebExtensionPermission> *optionalPermissions;

//@property (nonatomic, readonly, copy) NSSet<_WKWebExtensionMatchPattern *> *requestedPermissionMatchPatterns;

//@property (nonatomic, readonly, copy) NSSet<_WKWebExtensionMatchPattern *> *optionalPermissionMatchPatterns;

//@property (nonatomic, readonly, copy) NSSet<_WKWebExtensionMatchPattern *> *allRequestedMatchPatterns;

@property (nonatomic, readonly) BOOL hasBackgroundContent;
@property (nonatomic, readonly) BOOL backgroundContentIsPersistent;
@property (nonatomic, readonly) BOOL hasInjectedContent;
@property (nonatomic, readonly) BOOL hasOptionsPage;
@property (nonatomic, readonly) BOOL hasOverrideNewTabPage;
@property (nonatomic, readonly) BOOL hasCommands;
@property (nonatomic, readonly) BOOL hasContentModificationRules;

@end

NS_ASSUME_NONNULL_END

