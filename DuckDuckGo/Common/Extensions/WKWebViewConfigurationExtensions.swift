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

extension WKWebViewConfiguration {

    var allowsPictureInPictureMediaPlayback: Bool {
        get {
            return preferences.value(forKey: "allowsPictureInPictureMediaPlayback") as? Bool ?? false
        }
        set {
            preferences.setValue(newValue, forKey: "allowsPictureInPictureMediaPlayback")
        }
    }

    @MainActor
    func applyStandardConfiguration(contentBlocking: some ContentBlockingProtocol, burnerMode: BurnerMode) {
        if case .burner(let websiteDataStore) = burnerMode {
            self.websiteDataStore = websiteDataStore
        }
        allowsAirPlayForMediaPlayback = true
        if #available(macOS 12.3, *) {
            preferences.isElementFullscreenEnabled = true
        } else {
            preferences.setValue(true, forKey: "fullScreenEnabled")
        }

#if !APPSTORE
        allowsPictureInPictureMediaPlayback = true
#endif

        preferences.setValue(true, forKey: "developerExtrasEnabled")
        preferences.setValue(false, forKey: "backspaceKeyNavigationEnabled")
        preferences.javaScriptCanOpenWindowsAutomatically = true
        preferences.isFraudulentWebsiteWarningEnabled = false

        if SupportedOSChecker.isCurrentOSReceivingUpdates {
            if urlSchemeHandler(forURLScheme: URL.NavigationalScheme.duck.rawValue) == nil {
                setURLSchemeHandler(DuckURLSchemeHandler(), forURLScheme: URL.NavigationalScheme.duck.rawValue)
            }
        }

//        if urlSchemeHandler(forURLScheme: "duck") == nil {
//            setURLSchemeHandler(OnboardingSchemeHandler(), forURLScheme: "duck")
//        }

        let userContentController = UserContentController(assetsPublisher: contentBlocking.contentBlockingAssetsPublisher,
                                                          privacyConfigurationManager: contentBlocking.privacyConfigurationManager)

        self.userContentController = userContentController
        self.processPool.geolocationProvider = GeolocationProvider(processPool: self.processPool)

        _=NSPopover.swizzleShowRelativeToRectOnce
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
        if positioningView.superview == nil {
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

            os_log(.error, "trying to present \(self) from \(positioningView) not in view hierarchy")
            return
        }
        self.swizzled_show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }

}
