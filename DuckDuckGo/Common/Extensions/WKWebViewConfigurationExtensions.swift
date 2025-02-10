//
//  WKWebViewConfigurationExtensions.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import BrowserServicesKit
import Combine
import Common
import WebKit
import UserScript
import os.log

extension WKWebViewConfiguration {

    static var sharedVisitedLinkStore: WKVisitedLinkStoreWrapper?

    @MainActor
    func applyStandardConfiguration(contentBlocking: some ContentBlockingProtocol, burnerMode: BurnerMode, earlyAccessHandlers: [UserScript] = []) {
        if case .burner(let websiteDataStore) = burnerMode {
            self.websiteDataStore = websiteDataStore
            // Fire Window: disable audio/video item info reporting to macOS Control Center / Lock Screen
            preferences[.mediaSessionEnabled] = false

        } else if let sharedVisitedLinkStore = Self.sharedVisitedLinkStore {
            // share visited link store between regular tabs
            self.visitedLinkStore = sharedVisitedLinkStore
        } else {
            // set shared object if not set yet
            Self.sharedVisitedLinkStore = self.visitedLinkStore
        }

        allowsAirPlayForMediaPlayback = true
        if #available(macOS 12.3, *) {
            preferences.isElementFullscreenEnabled = true
        } else {
            preferences[.fullScreenEnabled] = true
        }

#if !APPSTORE
        preferences[.allowsPictureInPictureMediaPlayback] = true
#endif

        preferences[.developerExtrasEnabled] = true
        preferences[.backspaceKeyNavigationEnabled] = false
        preferences.javaScriptCanOpenWindowsAutomatically = true
        preferences.isFraudulentWebsiteWarningEnabled = false

        if SupportedOSChecker.isCurrentOSReceivingUpdates {
            if urlSchemeHandler(forURLScheme: URL.NavigationalScheme.duck.rawValue) == nil {
                setURLSchemeHandler(
                    DuckURLSchemeHandler(featureFlagger: NSApp.delegateTyped.featureFlagger),
                    forURLScheme: URL.NavigationalScheme.duck.rawValue
                )
            }
        }

#if !APPSTORE
        if #available(macOS 14.4, *), WebExtensionManager.shared.areExtenstionsEnabled {
            self._webExtensionController = WebExtensionManager.shared.controller
        }
#endif

        let userContentController = UserContentController(assetsPublisher: contentBlocking.contentBlockingAssetsPublisher,
                                                          privacyConfigurationManager: contentBlocking.privacyConfigurationManager,
                                                          earlyAccessHandlers: earlyAccessHandlers)

        self.userContentController = userContentController
        self.processPool.geolocationProvider = GeolocationProvider(processPool: self.processPool)

        _=NSPopover.swizzleShowRelativeToRectOnce
    }

}

extension WKPreferences {

    // !!! Do not change the key names as they are directly mirrored into WKPreferences keys !!!
    enum Key: String {
        case allowsPictureInPictureMediaPlayback
        case mediaSessionEnabled
        case developerExtrasEnabled
        case backspaceKeyNavigationEnabled
        case fullScreenEnabled
    }

    subscript(_ key: Key, default defaultValue: Bool = false) -> Bool {
        get {
            value(forKey: key.rawValue) as? Bool ?? defaultValue
        }
        set {
            setValue(newValue, forKey: key.rawValue)
        }
    }

    // prevent crashing on undefined key
    open override func setValue(_ value: Any?, forUndefinedKey key: String) {
        assertionFailure("WKPreferences.setValueForUndefinedKey: \(key)")
    }

}

extension NSPopover {

    fileprivate static let swizzleShowRelativeToRectOnce: () = {
        guard let originalMethod = class_getInstanceMethod(NSPopover.self, #selector(show(relativeTo:of:preferredEdge:))),
              let swizzledMethod = class_getInstanceMethod(NSPopover.self, #selector(swizzled_show(relativeTo:of:preferredEdge:))) else {
            assertionFailure("Methods not available")
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    // ignore popovers shown from a view not in view hierarchy
    // https://app.asana.com/0/1201037661562251/1206407295280737/f
    @objc(swizzled_showRelativeToRect:ofView:preferredEdge:)
    private dynamic func swizzled_show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        if positioningView.window == nil {
            var observer: Cancellable?
            observer = positioningView.observe(\.window) { positioningView, _ in
                if positioningView.window != nil {
                    self.swizzled_show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
                    observer?.cancel()
                }
            }
            positioningView.onDeinit {
                observer?.cancel()
            }

            Logger.general.error("trying to present \(self) from \(positioningView) not in view hierarchy")
            return
        }
        self.swizzled_show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }

}
