#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class _WKWebExtension;

WK_EXTERN NSErrorDomain const _WKWebExtensionMatchPatternErrorDomain API_AVAILABLE(macos(13.3), ios(16.4));

typedef NS_ERROR_ENUM(_WKWebExtensionMatchPatternErrorDomain, _WKWebExtensionMatchPatternError) {
    _WKWebExtensionMatchPatternErrorUnknown,
    _WKWebExtensionMatchPatternErrorInvalidScheme,
    _WKWebExtensionMatchPatternErrorInvalidHost,
    _WKWebExtensionMatchPatternErrorInvalidPath,
} NS_SWIFT_NAME(_WKWebExtensionMatchPattern.Error) API_AVAILABLE(macos(13.3), ios(16.4));

typedef NS_OPTIONS(NSUInteger, _WKWebExtensionMatchPatternOptions) {
    _WKWebExtensionMatchPatternOptionsNone                 = 0,
    _WKWebExtensionMatchPatternOptionsIgnoreSchemes        = 1 << 0,
    _WKWebExtensionMatchPatternOptionsIgnorePaths          = 1 << 1,
    _WKWebExtensionMatchPatternOptionsMatchBidirectionally = 1 << 2,
} NS_SWIFT_NAME(_WKWebExtensionMatchPattern.Options) API_AVAILABLE(macos(13.3), ios(16.4));

API_AVAILABLE(macos(13.3), ios(16.4))
NS_SWIFT_NAME(_WKWebExtension.MatchPattern)
@interface _WKWebExtensionMatchPattern : NSObject <NSSecureCoding, NSCopying>

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (void)registerCustomURLScheme:(NSString *)urlScheme;

+ (instancetype)allURLsMatchPattern;

+ (instancetype)allHostsAndSchemesMatchPattern;

+ (nullable instancetype)matchPatternWithString:(NSString *)string;

+ (nullable instancetype)matchPatternWithScheme:(NSString *)scheme host:(NSString *)host path:(NSString *)path;

- (nullable instancetype)initWithString:(NSString *)string error:(NSError **)error NS_DESIGNATED_INITIALIZER;

- (nullable instancetype)initWithScheme:(NSString *)scheme host:(NSString *)host path:(NSString *)path error:(NSError **)error NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly, copy) NSString *string;

@property (nonatomic, nullable, readonly, copy) NSString *scheme;

@property (nonatomic, nullable, readonly, copy) NSString *host;

@property (nonatomic, nullable, readonly, copy) NSString *path;

@property (nonatomic, readonly) BOOL matchesAllURLs;

@property (nonatomic, readonly) BOOL matchesAllHosts;

- (BOOL)matchesURL:(nullable NSURL *)url NS_SWIFT_UNAVAILABLE("Use options version with empty options set");

- (BOOL)matchesURL:(nullable NSURL *)url options:(_WKWebExtensionMatchPatternOptions)options NS_SWIFT_NAME(matches(_:options:));

- (BOOL)matchesPattern:(nullable _WKWebExtensionMatchPattern *)pattern NS_SWIFT_UNAVAILABLE("Use options version with empty options set");

- (BOOL)matchesPattern:(nullable _WKWebExtensionMatchPattern *)pattern options:(_WKWebExtensionMatchPatternOptions)options NS_SWIFT_NAME(matches(_:options:));

@end

NS_ASSUME_NONNULL_END
