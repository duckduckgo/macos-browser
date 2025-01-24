#import "_WKWebExtensionControllerDelegate.h"

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(macos(14.4), ios(16.4))
@protocol _WKWebExtensionControllerDelegatePrivate <_WKWebExtensionControllerDelegate>
@optional

- (void)_webExtensionController:(_WKWebExtensionController *)controller recordTestAssertionResult:(BOOL)result withMessage:(NSString *)message andSourceURL:(NSString *)sourceURL lineNumber:(unsigned)lineNumber;

- (void)_webExtensionController:(_WKWebExtensionController *)controller recordTestEqualityResult:(BOOL)result expectedValue:(NSString *)expectedValue actualValue:(NSString *)actualValue withMessage:(NSString *)message andSourceURL:(NSString *)sourceURL lineNumber:(unsigned)lineNumber;

- (void)_webExtensionController:(_WKWebExtensionController *)controller recordTestMessage:(NSString *)message andSourceURL:(NSString *)sourceURL lineNumber:(unsigned)lineNumber;

- (void)_webExtensionController:(_WKWebExtensionController *)controller recordTestYieldedWithMessage:(NSString *)message andSourceURL:(NSString *)sourceURL lineNumber:(unsigned)lineNumber;

- (void)_webExtensionController:(_WKWebExtensionController *)controller recordTestFinishedWithResult:(BOOL)result message:(NSString *)message andSourceURL:(NSString *)sourceURL lineNumber:(unsigned)lineNumber;

- (void)_webExtensionController:(_WKWebExtensionController *)controller didCreateBackgroundWebView:(WKWebView *)webView forExtensionContext:(_WKWebExtensionContext *)context;

@end

NS_ASSUME_NONNULL_END
