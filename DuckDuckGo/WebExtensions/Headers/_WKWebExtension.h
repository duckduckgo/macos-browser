#import <Foundation/Foundation.h>

#import "_WKWebExtensionMatchPattern.h"
#import "_WKWebExtensionPermission.h"

#if TARGET_OS_IPHONE
@class UIImage;
#else
@class NSImage;
#endif

NS_ASSUME_NONNULL_BEGIN

WK_EXTERN NSErrorDomain const _WKWebExtensionErrorDomain NS_SWIFT_NAME(_WKWebExtension.ErrorDomain) API_AVAILABLE(macos(13.3), ios(16.4));

typedef NS_ERROR_ENUM(_WKWebExtensionErrorDomain, _WKWebExtensionError) {
    _WKWebExtensionErrorUnknown = 1,
    _WKWebExtensionErrorResourceNotFound,
    _WKWebExtensionErrorInvalidResourceCodeSignature,
    _WKWebExtensionErrorInvalidManifest,
    _WKWebExtensionErrorUnsupportedManifestVersion,
    _WKWebExtensionErrorInvalidManifestEntry,
    _WKWebExtensionErrorInvalidDeclarativeNetRequestEntry,
    _WKWebExtensionErrorInvalidBackgroundPersistence,
} NS_SWIFT_NAME(_WKWebExtension.Error) API_AVAILABLE(macos(13.3), ios(16.4));

API_AVAILABLE(macos(13.3), ios(16.4))
WK_EXTERN NSNotificationName const _WKWebExtensionErrorsWereUpdatedNotification NS_SWIFT_NAME(_WKWebExtension.errorsWereUpdatedNotification);

API_AVAILABLE(macos(13.3), ios(16.4))
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


@property (nonatomic, readonly, copy) NSSet<_WKWebExtensionPermission> *optionalPermissions;

@property (nonatomic, readonly, copy) NSSet<_WKWebExtensionMatchPattern *> *requestedPermissionMatchPatterns;

@property (nonatomic, readonly, copy) NSSet<_WKWebExtensionMatchPattern *> *optionalPermissionMatchPatterns;

@property (nonatomic, readonly, copy) NSSet<_WKWebExtensionMatchPattern *> *allRequestedMatchPatterns;

@property (nonatomic, readonly) BOOL hasBackgroundContent;

@property (nonatomic, readonly) BOOL backgroundContentIsPersistent;

@property (nonatomic, readonly) BOOL hasInjectedContent;

@property (nonatomic, readonly) BOOL hasOptionsPage;

@property (nonatomic, readonly) BOOL hasOverrideNewTabPage;

@property (nonatomic, readonly) BOOL hasCommands;

@property (nonatomic, readonly) BOOL hasContentModificationRules;

@end

NS_ASSUME_NONNULL_END
