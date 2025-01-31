#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class WKWebViewConfiguration;
@class WKWebsiteDataStore;
@class _WKWebExtensionController;

API_AVAILABLE(macos(13.3), ios(16.4))
NS_SWIFT_NAME(_WKWebExtensionController.Configuration)
@interface _WKWebExtensionControllerConfiguration : NSObject <NSSecureCoding, NSCopying>

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)defaultConfiguration;

+ (instancetype)nonPersistentConfiguration;

+ (instancetype)configurationWithIdentifier:(NSUUID *)identifier;

@property (nonatomic, readonly, getter=isPersistent) BOOL persistent;

@property (nonatomic, nullable, readonly, copy) NSUUID *identifier;

@property (nonatomic, null_resettable, copy) WKWebViewConfiguration *webViewConfiguration;

@property (nonatomic, null_resettable, retain) WKWebsiteDataStore *defaultWebsiteDataStore;

@end

NS_ASSUME_NONNULL_END
