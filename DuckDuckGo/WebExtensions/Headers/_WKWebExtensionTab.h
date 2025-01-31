#import <Foundation/Foundation.h>

@class WKWebView;
@class _WKWebExtensionContext;
@class _WKWebExtensionTabCreationOptions;
@protocol _WKWebExtensionWindow;

@class NSImage;

NS_ASSUME_NONNULL_BEGIN

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
} API_AVAILABLE(macos(13.3), ios(16.4));

API_AVAILABLE(macos(13.3), ios(16.4))
@protocol _WKWebExtensionTab <NSObject>
@optional

- (nullable id <_WKWebExtensionWindow>)windowForWebExtensionContext:(_WKWebExtensionContext *)context;

- (NSUInteger)indexInWindowForWebExtensionContext:(_WKWebExtensionContext *)context;

- (nullable id <_WKWebExtensionTab>)parentTabForWebExtensionContext:(_WKWebExtensionContext *)context;

- (void)setParentTab:(nullable id <_WKWebExtensionTab>)parentTab forWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (nullable WKWebView *)mainWebViewForWebExtensionContext:(_WKWebExtensionContext *)context;

- (nullable NSString *)tabTitleForWebExtensionContext:(_WKWebExtensionContext *)context;

- (BOOL)isPinnedForWebExtensionContext:(_WKWebExtensionContext *)context;

- (void)pinForWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (void)unpinForWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (BOOL)isReaderModeAvailableForWebExtensionContext:(_WKWebExtensionContext *)context;

- (BOOL)isShowingReaderModeForWebExtensionContext:(_WKWebExtensionContext *)context;

- (void)toggleReaderModeForWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (BOOL)isAudibleForWebExtensionContext:(_WKWebExtensionContext *)context;

- (BOOL)isMutedForWebExtensionContext:(_WKWebExtensionContext *)context;

- (void)muteForWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (void)unmuteForWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (CGSize)sizeForWebExtensionContext:(_WKWebExtensionContext *)context;

- (double)zoomFactorForWebExtensionContext:(_WKWebExtensionContext *)context;

- (void)setZoomFactor:(double)zoomFactor forWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (nullable NSURL *)urlForWebExtensionContext:(_WKWebExtensionContext *)context;

- (nullable NSURL *)pendingURLForWebExtensionContext:(_WKWebExtensionContext *)context;

- (BOOL)isLoadingCompleteForWebExtensionContext:(_WKWebExtensionContext *)context;

- (void)detectWebpageLocaleForWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSLocale * WK_NULLABLE_RESULT locale, NSError * _Nullable error))completionHandler;

- (void)captureVisibleWebpageForWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSImage * WK_NULLABLE_RESULT visibleWebpageImage, NSError * _Nullable error))completionHandler;

- (void)loadURL:(NSURL *)url forWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (void)reloadForWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (void)reloadFromOriginForWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (void)goBackForWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (void)goForwardForWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (void)activateForWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (BOOL)isSelectedForWebExtensionContext:(_WKWebExtensionContext *)context;

- (void)selectForWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (void)deselectForWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (void)duplicateForWebExtensionContext:(_WKWebExtensionContext *)context withOptions:(_WKWebExtensionTabCreationOptions *)options completionHandler:(void (^)(id <_WKWebExtensionTab> WK_NULLABLE_RESULT duplicatedTab, NSError * _Nullable error))completionHandler;

- (void)closeForWebExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (BOOL)shouldGrantTabPermissionsOnUserGestureForWebExtensionContext:(_WKWebExtensionContext *)context;

@end

NS_ASSUME_NONNULL_END
