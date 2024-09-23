#import <WebKit/WKWebExtension.h>
#import <WebKit/WKWebExtensionAction.h>
#import <WebKit/WKWebExtensionContext.h>
#import <WebKit/WKWebExtensionContextPrivate.h>
#import <WebKit/WKWebExtensionController.h>
#import <WebKit/WKWebExtensionControllerPrivate.h>
#import <WebKit/WKWebExtensionControllerConfiguration.h>
#import <WebKit/WKWebExtensionControllerConfigurationPrivate.h>
#import <WebKit/WKWebExtensionControllerPrivate.h>
#import <WebKit/WKWebExtensionMatchPattern.h>
#import <WebKit/WKWebExtensionMatchPatternPrivate.h>
#import <WebKit/WKWebExtensionPrivate.h>
#import <WebKit/WKWebExtensionTab.h>
//#import <WebKit/WKWebExtensionTabCreationOptions.h>
//#import <WebKit/WKWebExtensionWebNavigationURLFilter.h>
#import <WebKit/WKWebExtensionWindow.h>
//#import <WebKit/WKWebExtensionWindowCreationOptions.h>

#import "WKWebViewConfiguration+Private.h"


/*! @abstract Constants for specifying permission in a ``WKWebExtensionContext``. */
typedef NSString * WKWebExtensionPermission NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(WKWebExtension.Permission);

/*! @abstract The `activeTab` permission requests that when the user interacts with the extension, the extension is granted extra permissions for the active tab only. */
WKWebExtensionPermission const WKWebExtensionPermissionActiveTab NS_SWIFT_NONISOLATED;

/*! @abstract The `alarms` permission requests access to the `browser.alarms` APIs. */
WKWebExtensionPermission const WKWebExtensionPermissionAlarms NS_SWIFT_NONISOLATED;

/*! @abstract The `clipboardWrite` permission requests access to write to the clipboard. */
WKWebExtensionPermission const WKWebExtensionPermissionClipboardWrite NS_SWIFT_NONISOLATED;

/*! @abstract The `contextMenus` permission requests access to the `browser.contextMenus` APIs. */
WKWebExtensionPermission const WKWebExtensionPermissionContextMenus NS_SWIFT_NONISOLATED;

/*! @abstract The `cookies` permission requests access to the `browser.cookies` APIs. */
WKWebExtensionPermission const WKWebExtensionPermissionCookies NS_SWIFT_NONISOLATED;

/*! @abstract The `declarativeNetRequest` permission requests access to the `browser.declarativeNetRequest` APIs. */
WKWebExtensionPermission const WKWebExtensionPermissionDeclarativeNetRequest NS_SWIFT_NONISOLATED;

/*! @abstract The `declarativeNetRequestFeedback` permission requests access to the `browser.declarativeNetRequest` APIs with extra information on matched rules. */
WKWebExtensionPermission const WKWebExtensionPermissionDeclarativeNetRequestFeedback NS_SWIFT_NONISOLATED;

/*! @abstract The `declarativeNetRequestWithHostAccess` permission requests access to the `browser.declarativeNetRequest` APIs with the ability to modify or redirect requests. */
WKWebExtensionPermission const WKWebExtensionPermissionDeclarativeNetRequestWithHostAccess NS_SWIFT_NONISOLATED;

/*! @abstract The `menus` permission requests access to the `browser.menus` APIs. */
WKWebExtensionPermission const WKWebExtensionPermissionMenus NS_SWIFT_NONISOLATED;

/*! @abstract The `nativeMessaging` permission requests access to send messages to the App Extension bundle. */
WKWebExtensionPermission const WKWebExtensionPermissionNativeMessaging NS_SWIFT_NONISOLATED;

/*! @abstract The `scripting` permission requests access to the `browser.scripting` APIs. */
WKWebExtensionPermission const WKWebExtensionPermissionScripting NS_SWIFT_NONISOLATED;

/*! @abstract The `storage` permission requests access to the `browser.storage` APIs. */
WKWebExtensionPermission const WKWebExtensionPermissionStorage NS_SWIFT_NONISOLATED;

/*! @abstract The `tabs` permission requests access extra information on the `browser.tabs` APIs. */
WKWebExtensionPermission const WKWebExtensionPermissionTabs NS_SWIFT_NONISOLATED;

/*! @abstract The `unlimitedStorage` permission requests access to an unlimited quota on the `browser.storage.local` APIs. */
WKWebExtensionPermission const WKWebExtensionPermissionUnlimitedStorage NS_SWIFT_NONISOLATED;

/*! @abstract The `webNavigation` permission requests access to the `browser.webNavigation` APIs. */
WKWebExtensionPermission const WKWebExtensionPermissionWebNavigation NS_SWIFT_NONISOLATED;

/*! @abstract The `webRequest` permission requests access to the `browser.webRequest` APIs. */
WKWebExtensionPermission const WKWebExtensionPermissionWebRequest NS_SWIFT_NONISOLATED;
