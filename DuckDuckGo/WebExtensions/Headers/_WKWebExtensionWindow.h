#import <Foundation/Foundation.h>

@class _WKWebExtensionContext;
@protocol _WKWebExtensionTab;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, _WKWebExtensionWindowType) {
    _WKWebExtensionWindowTypeNormal,
    _WKWebExtensionWindowTypePopup,
} API_AVAILABLE(macos(14.4), ios(16.4));

typedef NS_ENUM(NSInteger, _WKWebExtensionWindowState) {
    _WKWebExtensionWindowStateNormal,
    _WKWebExtensionWindowStateMinimized,
    _WKWebExtensionWindowStateMaximized,
    _WKWebExtensionWindowStateFullscreen,
} API_AVAILABLE(macos(14.4), ios(16.4));

API_AVAILABLE(macos(14.4), ios(16.4))
@protocol _WKWebExtensionWindow <NSObject>
@optional

- (NSArray<id <_WKWebExtensionTab>> *)tabsForWebExtensionContext:(_WKWebExtensionContext *)context;

- (nullable id <_WKWebExtensionTab>)activeTabForWebExtensionContext:(_WKWebExtensionContext *)context;

- (_WKWebExtensionWindowType)windowTypeForWebExtensionContext:(_WKWebExtensionContext *)context;

- (_WKWebExtensionWindowState)windowStateForWebExtensionContext:(_WKWebExtensionContext *)context;

- (void)setWindowState:(_WKWebExtensionWindowState)state forWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (BOOL)isUsingPrivateBrowsingForWebExtensionContext:(_WKWebExtensionContext *)context;

- (CGRect)screenFrameForWebExtensionContext:(_WKWebExtensionContext *)context;

- (CGRect)frameForWebExtensionContext:(_WKWebExtensionContext *)context;

- (void)setFrame:(CGRect)frame forWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (void)focusForWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (void)closeForWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
