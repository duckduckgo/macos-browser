#import "_WKWebExtensionContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface _WKWebExtensionContext ()

@property (nonatomic, nullable, readonly) WKWebView *_backgroundWebView;

@property (nonatomic, nullable, readonly) NSURL *_backgroundContentURL;

@end

NS_ASSUME_NONNULL_END
