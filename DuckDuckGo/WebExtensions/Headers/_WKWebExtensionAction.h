#import <Foundation/Foundation.h>

@class WKWebView;
@class _WKWebExtensionContext;
@protocol _WKWebExtensionTab;

@class NSImage;
@class NSMenuItem;
@class NSPopover;

#define HAVE_UPDATED_WEB_EXTENSION_ACTION_INSPECTION_OVERRIDE_NAME 1

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(macos(14.4), ios(17.4), visionos(1.1))
WK_EXTERN NSNotificationName const _WKWebExtensionActionPropertiesDidChangeNotification NS_SWIFT_NAME(_WKWebExtensionAction.propertiesDidChangeNotification);

API_AVAILABLE(macos(14.4), ios(17.4), visionos(1.1))
NS_SWIFT_NAME(_WKWebExtension.Action)
@interface _WKWebExtensionAction : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)new NS_UNAVAILABLE;

@property (nonatomic, readonly, weak) _WKWebExtensionContext *webExtensionContext;

@property (nonatomic, readonly, nullable, weak) id <_WKWebExtensionTab> associatedTab;

- (nullable NSImage *)iconForSize:(CGSize)size;

@property (nonatomic, readonly, copy) NSString *label;

@property (nonatomic, readonly, copy) NSString *badgeText;

@property (nonatomic) BOOL hasUnreadBadgeText;

@property (nonatomic, nullable, copy) NSString *inspectionName;

@property (nonatomic, readonly, getter=isEnabled) BOOL enabled;

@property (nonatomic, readonly, copy) NSArray<NSMenuItem *> *menuItems;

@property (nonatomic, readonly) BOOL presentsPopup;

@property (nonatomic, readonly, nullable) NSPopover *popupPopover;

@property (nonatomic, readonly, nullable) WKWebView *popupWebView;

- (void)closePopup;

@end

NS_ASSUME_NONNULL_END
