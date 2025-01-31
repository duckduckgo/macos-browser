#import <Foundation/Foundation.h>

#import "_WKWebExtensionMatchPattern.h"
#import "_WKWebExtensionPermission.h"
#import "_WKWebExtensionTab.h"

@class WKWebViewConfiguration;
@class _WKWebExtension;
@class _WKWebExtensionAction;
@class _WKWebExtensionCommand;
@class _WKWebExtensionController;

@class NSEvent;
@class NSMenuItem;

#define HAVE_UPDATED_WEB_EXTENSION_CONTEXT_INSPECTION_OVERRIDE_NAME 1

NS_ASSUME_NONNULL_BEGIN

WK_EXTERN NSErrorDomain const _WKWebExtensionContextErrorDomain NS_SWIFT_NAME(_WKWebExtensionContext.ErrorDomain) API_AVAILABLE(macos(13.3), ios(16.4));

typedef NS_ERROR_ENUM(_WKWebExtensionContextErrorDomain, _WKWebExtensionContextError) {
    _WKWebExtensionContextErrorUnknown = 1,
    _WKWebExtensionContextErrorAlreadyLoaded,
    _WKWebExtensionContextErrorNotLoaded,
    _WKWebExtensionContextErrorBaseURLAlreadyInUse,
    _WKWebExtensionContextErrorNoBackgroundContent,
    _WKWebExtensionContextErrorBackgroundContentFailedToLoad,
} NS_SWIFT_NAME(_WKWebExtensionContext.Error) API_AVAILABLE(macos(13.3), ios(16.4));

typedef NS_ENUM(NSInteger, _WKWebExtensionContextPermissionStatus) {
    _WKWebExtensionContextPermissionStatusDeniedExplicitly    = -3,
    _WKWebExtensionContextPermissionStatusDeniedImplicitly    = -2,
    _WKWebExtensionContextPermissionStatusRequestedImplicitly = -1,
    _WKWebExtensionContextPermissionStatusUnknown             =  0,
    _WKWebExtensionContextPermissionStatusRequestedExplicitly =  1,
    _WKWebExtensionContextPermissionStatusGrantedImplicitly   =  2,
    _WKWebExtensionContextPermissionStatusGrantedExplicitly   =  3,
} NS_SWIFT_NAME(_WKWebExtensionContext.PermissionState) API_AVAILABLE(macos(13.3), ios(16.4));

API_AVAILABLE(macos(13.3), ios(16.4))
WK_EXTERN NSNotificationName const _WKWebExtensionContextPermissionsWereGrantedNotification NS_SWIFT_NAME(_WKWebExtensionContext.permissionsWereGrantedNotification);

API_AVAILABLE(macos(13.3), ios(16.4))
WK_EXTERN NSNotificationName const _WKWebExtensionContextPermissionsWereDeniedNotification NS_SWIFT_NAME(_WKWebExtensionContext.permissionsWereDeniedNotification);

API_AVAILABLE(macos(13.3), ios(16.4))
WK_EXTERN NSNotificationName const _WKWebExtensionContextGrantedPermissionsWereRemovedNotification NS_SWIFT_NAME(_WKWebExtensionContext.grantedPermissionsWereRemovedNotification);

API_AVAILABLE(macos(13.3), ios(16.4))
WK_EXTERN NSNotificationName const _WKWebExtensionContextDeniedPermissionsWereRemovedNotification NS_SWIFT_NAME(_WKWebExtensionContext.deniedPermissionsWereRemovedNotification);

API_AVAILABLE(macos(13.3), ios(16.4))
WK_EXTERN NSNotificationName const _WKWebExtensionContextPermissionMatchPatternsWereGrantedNotification NS_SWIFT_NAME(_WKWebExtensionContext.permissionMatchPatternsWereGrantedNotification);

API_AVAILABLE(macos(13.3), ios(16.4))
WK_EXTERN NSNotificationName const _WKWebExtensionContextPermissionMatchPatternsWereDeniedNotification NS_SWIFT_NAME(_WKWebExtensionContext.permissionMatchPatternsWereDeniedNotification);

API_AVAILABLE(macos(13.3), ios(16.4))
WK_EXTERN NSNotificationName const _WKWebExtensionContextGrantedPermissionMatchPatternsWereRemovedNotification NS_SWIFT_NAME(_WKWebExtensionContext.grantedPermissionMatchPatternsWereRemovedNotification);

API_AVAILABLE(macos(13.3), ios(16.4))
WK_EXTERN NSNotificationName const _WKWebExtensionContextDeniedPermissionMatchPatternsWereRemovedNotification NS_SWIFT_NAME(_WKWebExtensionContext.deniedPermissionMatchPatternsWereRemovedNotification);

API_AVAILABLE(macos(13.3), ios(16.4))
typedef NSString * _WKWebExtensionContextNotificationUserInfoKey NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(_WKWebExtensionContext.NotificationUserInfoKey);

API_AVAILABLE(macos(13.3), ios(16.4))
WK_EXTERN _WKWebExtensionContextNotificationUserInfoKey const _WKWebExtensionContextNotificationUserInfoKeyPermissions;

API_AVAILABLE(macos(13.3), ios(16.4))
WK_EXTERN _WKWebExtensionContextNotificationUserInfoKey const _WKWebExtensionContextNotificationUserInfoKeyMatchPatterns;

API_AVAILABLE(macos(14.4), ios(16.4))
@interface _WKWebExtensionContext : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)contextForExtension:(_WKWebExtension *)extension;

- (instancetype)initForExtension:(_WKWebExtension *)extension NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly, strong) _WKWebExtension *webExtension;

@property (nonatomic, readonly, weak, nullable) _WKWebExtensionController *webExtensionController;

@property (nonatomic, readonly, getter=isLoaded) BOOL loaded;

@property (nonatomic, copy) NSURL *baseURL;

@property (nonatomic, copy) NSString *uniqueIdentifier;

@property (nonatomic, getter=isInspectable) BOOL inspectable;

@property (nonatomic, nullable, copy) NSString *inspectionName;

@property (nonatomic, null_resettable, copy) NSSet<NSString *> *unsupportedAPIs;

@property (nonatomic, readonly, copy, nullable) WKWebViewConfiguration *webViewConfiguration;

@property (nonatomic, readonly, copy, nullable) NSURL *optionsPageURL;

@property (nonatomic, readonly, copy, nullable) NSURL *overrideNewTabPageURL;

@property (nonatomic, copy) NSDictionary<_WKWebExtensionPermission, NSDate *> *grantedPermissions;

@property (nonatomic, copy) NSDictionary<_WKWebExtensionMatchPattern *, NSDate *> *grantedPermissionMatchPatterns;

@property (nonatomic, copy) NSDictionary<_WKWebExtensionPermission, NSDate *> *deniedPermissions;

@property (nonatomic, copy) NSDictionary<_WKWebExtensionMatchPattern *, NSDate *> *deniedPermissionMatchPatterns;

@property (nonatomic) BOOL requestedOptionalAccessToAllHosts;

@property (nonatomic) BOOL hasAccessInPrivateBrowsing;

@property (nonatomic, readonly, copy) NSSet<_WKWebExtensionPermission> *currentPermissions;

@property (nonatomic, readonly, copy) NSSet<_WKWebExtensionMatchPattern *> *currentPermissionMatchPatterns;

- (BOOL)hasPermission:(_WKWebExtensionPermission)permission NS_SWIFT_UNAVAILABLE("Use tab version with nil");

- (BOOL)hasPermission:(_WKWebExtensionPermission)permission inTab:(nullable id <_WKWebExtensionTab>)tab NS_SWIFT_NAME(hasPermission(_:in:));

- (BOOL)hasAccessToURL:(NSURL *)url NS_SWIFT_UNAVAILABLE("Use tab version with nil");

- (BOOL)hasAccessToURL:(NSURL *)url inTab:(nullable id <_WKWebExtensionTab>)tab NS_SWIFT_NAME(hasAccess(to:in:));

@property (nonatomic, readonly) BOOL hasAccessToAllURLs;

@property (nonatomic, readonly) BOOL hasAccessToAllHosts;

@property (nonatomic, readonly) BOOL hasInjectedContent;

- (BOOL)hasInjectedContentForURL:(NSURL *)url;

@property (nonatomic, readonly) BOOL hasContentModificationRules;

- (_WKWebExtensionContextPermissionStatus)permissionStatusForPermission:(_WKWebExtensionPermission)permission NS_SWIFT_UNAVAILABLE("Use tab version with nil");

- (_WKWebExtensionContextPermissionStatus)permissionStatusForPermission:(_WKWebExtensionPermission)permission inTab:(nullable id <_WKWebExtensionTab>)tab NS_SWIFT_NAME(permissionStatus(for:in:));

- (void)setPermissionStatus:(_WKWebExtensionContextPermissionStatus)status forPermission:(_WKWebExtensionPermission)permission NS_SWIFT_UNAVAILABLE("Use expirationDate version with nil");

- (void)setPermissionStatus:(_WKWebExtensionContextPermissionStatus)status forPermission:(_WKWebExtensionPermission)permission expirationDate:(nullable NSDate *)expirationDate NS_SWIFT_NAME(setPermissionStatus(_:for:expirationDate:));

- (_WKWebExtensionContextPermissionStatus)permissionStatusForURL:(NSURL *)url NS_SWIFT_UNAVAILABLE("Use tab version with nil");

- (_WKWebExtensionContextPermissionStatus)permissionStatusForURL:(NSURL *)url inTab:(nullable id <_WKWebExtensionTab>)tab NS_SWIFT_NAME(permissionStatus(for:in:));

- (void)setPermissionStatus:(_WKWebExtensionContextPermissionStatus)status forURL:(NSURL *)url NS_SWIFT_UNAVAILABLE("Use expirationDate version with nil");

- (void)setPermissionStatus:(_WKWebExtensionContextPermissionStatus)status forURL:(NSURL *)url expirationDate:(nullable NSDate *)expirationDate NS_SWIFT_NAME(setPermissionStatus(_:for:expirationDate:));

- (_WKWebExtensionContextPermissionStatus)permissionStatusForMatchPattern:(_WKWebExtensionMatchPattern *)pattern NS_SWIFT_UNAVAILABLE("Use tab version with nil");

- (_WKWebExtensionContextPermissionStatus)permissionStatusForMatchPattern:(_WKWebExtensionMatchPattern *)pattern inTab:(nullable id <_WKWebExtensionTab>)tab NS_SWIFT_NAME(permissionStatus(for:in:));

- (void)setPermissionStatus:(_WKWebExtensionContextPermissionStatus)status forMatchPattern:(_WKWebExtensionMatchPattern *)pattern NS_SWIFT_UNAVAILABLE("Use expirationDate version with nil");

- (void)setPermissionStatus:(_WKWebExtensionContextPermissionStatus)status forMatchPattern:(_WKWebExtensionMatchPattern *)pattern expirationDate:(nullable NSDate *)expirationDate NS_SWIFT_NAME(setPermissionStatus(_:for:expirationDate:));

- (void)loadBackgroundContentWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (nullable _WKWebExtensionAction *)actionForTab:(nullable id <_WKWebExtensionTab>)tab NS_SWIFT_NAME(action(for:)) API_AVAILABLE(macos(14.4));

- (void)performActionForTab:(nullable id <_WKWebExtensionTab>)tab NS_SWIFT_NAME(performAction(for:));

@property (nonatomic, readonly, copy) NSArray<_WKWebExtensionCommand *> *commands;

- (void)performCommand:(_WKWebExtensionCommand *)command;

- (BOOL)performCommandForEvent:(NSEvent *)event;
- (nullable _WKWebExtensionCommand *)commandForEvent:(NSEvent *)event;

- (NSArray<NSMenuItem *> *)menuItemsForTab:(id <_WKWebExtensionTab>)tab;

- (void)userGesturePerformedInTab:(id <_WKWebExtensionTab>)tab NS_SWIFT_NAME(userGesturePerformed(in:));

- (BOOL)hasActiveUserGestureInTab:(id <_WKWebExtensionTab>)tab NS_SWIFT_NAME(hasActiveUserGesture(in:));

- (void)clearUserGestureInTab:(id <_WKWebExtensionTab>)tab NS_SWIFT_NAME(clearUserGesture(in:));

@property (nonatomic, readonly, copy) NSArray<id <_WKWebExtensionWindow>> *openWindows;

@property (nonatomic, readonly, weak, nullable) id <_WKWebExtensionWindow> focusedWindow;

@property (nonatomic, readonly, copy) NSSet<id <_WKWebExtensionTab>> *openTabs;

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

NS_ASSUME_NONNULL_END
