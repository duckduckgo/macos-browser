@class WKWebView;
@class _WKWebExtensionController;

typedef NS_ENUM(NSUInteger, _WKContentSecurityPolicyModeForExtension) {
    _WKContentSecurityPolicyModeForExtensionNone = 0,
    _WKContentSecurityPolicyModeForExtensionManifestV2,
    _WKContentSecurityPolicyModeForExtensionManifestV3
} API_AVAILABLE(macos(13.0), ios(16.0));

API_AVAILABLE(macos(13.3))
@interface WKWebViewConfiguration (WKPrivate)

// Specifies the base URL that the web view must use for navigation. Navigation to URLs not matching this base URL will result in a navigation error.
// When not set, the web view allows navigation to any URL that isn't a web extension URL. This is needed to ensure proper configuration of the web view.
@property (nonatomic, strong, setter=_setRequiredWebExtensionBaseURL:) NSURL *_requiredWebExtensionBaseURL;

@property (nonatomic, strong, readonly) _WKWebExtensionController *_strongWebExtensionController;
@property (nonatomic, weak, setter=_setWeakWebExtensionController:) _WKWebExtensionController *_weakWebExtensionController;
@property (nonatomic, strong, setter=_setWebExtensionController:) _WKWebExtensionController *_webExtensionController;

@property (nonatomic, setter=_setContentSecurityPolicyModeForExtension:) _WKContentSecurityPolicyModeForExtension _contentSecurityPolicyModeForExtension API_AVAILABLE(macos(13.0), ios(16.0));


@end
