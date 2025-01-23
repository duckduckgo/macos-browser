#import <Foundation/Foundation.h>

#import "_WKWebExtensionPermission.h"

#define HAVE_UPDATED_WEB_EXTENSION_PROMPT_COMPLETION_HANDLER 1

@class _WKWebExtensionAction;
@class _WKWebExtensionContext;
@class _WKWebExtensionController;
@class _WKWebExtensionMatchPattern;
@class _WKWebExtensionMessagePort;
@class _WKWebExtensionTabCreationOptions;
@class _WKWebExtensionWindowCreationOptions;
@protocol _WKWebExtensionTab;
@protocol _WKWebExtensionWindow;

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(macos(14.4), ios(16.4))
@protocol _WKWebExtensionControllerDelegate <NSObject>
@optional

- (NSArray<id <_WKWebExtensionWindow>> *)webExtensionController:(_WKWebExtensionController *)controller openWindowsForExtensionContext:(_WKWebExtensionContext *)extensionContext;

- (nullable id <_WKWebExtensionWindow>)webExtensionController:(_WKWebExtensionController *)controller focusedWindowForExtensionContext:(_WKWebExtensionContext *)extensionContext;

- (void)webExtensionController:(_WKWebExtensionController *)controller openNewWindowWithOptions:(_WKWebExtensionWindowCreationOptions *)options forExtensionContext:(_WKWebExtensionContext *)extensionContext completionHandler:(void (^)(id <_WKWebExtensionWindow> WK_NULLABLE_RESULT newWindow, NSError * _Nullable error))completionHandler;

- (void)webExtensionController:(_WKWebExtensionController *)controller openNewTabWithOptions:(_WKWebExtensionTabCreationOptions *)options forExtensionContext:(_WKWebExtensionContext *)extensionContext completionHandler:(void (^)(id <_WKWebExtensionTab> WK_NULLABLE_RESULT newTab, NSError * _Nullable error))completionHandler;

- (void)webExtensionController:(_WKWebExtensionController *)controller openOptionsPageForExtensionContext:(_WKWebExtensionContext *)extensionContext completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (void)webExtensionController:(_WKWebExtensionController *)controller promptForPermissions:(NSSet<_WKWebExtensionPermission> *)permissions inTab:(nullable id <_WKWebExtensionTab>)tab forExtensionContext:(_WKWebExtensionContext *)extensionContext completionHandler:(void (^)(NSSet<_WKWebExtensionPermission> *allowedPermissions, NSDate * _Nullable expirationDate))completionHandler NS_SWIFT_NAME(webExtensionController(_:promptForPermissions:in:for:completionHandler:));

- (void)webExtensionController:(_WKWebExtensionController *)controller promptForPermissionToAccessURLs:(NSSet<NSURL *> *)urls inTab:(nullable id <_WKWebExtensionTab>)tab forExtensionContext:(_WKWebExtensionContext *)extensionContext completionHandler:(void (^)(NSSet<NSURL *> *allowedURLs, NSDate * _Nullable expirationDate))completionHandler NS_SWIFT_NAME(webExtensionController(_:promptForPermissionToAccess:in:for:completionHandler:));

- (void)webExtensionController:(_WKWebExtensionController *)controller promptForPermissionMatchPatterns:(NSSet<_WKWebExtensionMatchPattern *> *)matchPatterns inTab:(nullable id <_WKWebExtensionTab>)tab forExtensionContext:(_WKWebExtensionContext *)extensionContext completionHandler:(void (^)(NSSet<_WKWebExtensionMatchPattern *> *allowedMatchPatterns, NSDate * _Nullable expirationDate))completionHandler NS_SWIFT_NAME(webExtensionController(_:promptForPermissionMatchPatterns:in:for:completionHandler:));

- (void)webExtensionController:(_WKWebExtensionController *)controller presentPopupForAction:(_WKWebExtensionAction *)action forExtensionContext:(_WKWebExtensionContext *)context completionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (void)webExtensionController:(_WKWebExtensionController *)controller sendMessage:(id)message toApplicationIdentifier:(nullable NSString *)applicationIdentifier forExtensionContext:(_WKWebExtensionContext *)extensionContext replyHandler:(void (^)(id WK_NULLABLE_RESULT replyMessage, NSError * _Nullable error))replyHandler WK_SWIFT_ASYNC(5) NS_SWIFT_NAME(webExtensionController(_:sendMessage:to:for:replyHandler:));

- (void)webExtensionController:(_WKWebExtensionController *)controller connectUsingMessagePort:(_WKWebExtensionMessagePort *)port forExtensionContext:(_WKWebExtensionContext *)extensionContext completionHandler:(void (^)(NSError * _Nullable error))completionHandler NS_SWIFT_NAME(webExtensionController(_:connectUsingMessagePort:for:completionHandler:));

@end

NS_ASSUME_NONNULL_END
