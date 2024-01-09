//
//  URLEventHandler.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import Common
import Foundation

#if NETWORK_PROTECTION
import NetworkProtection
#endif

#if DBP
import DataBrokerProtection
#endif

@MainActor
final class URLEventHandler {

    private let handler: @MainActor (URL) -> Void

    private var didFinishLaunching = false
    private var urlsToOpen = [URL]()

    init(handler: ((URL) -> Void)? = nil) {
        self.handler = handler ?? Self.openURL

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleUrlEvent(event:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching() {
        if !urlsToOpen.isEmpty {

            for url in urlsToOpen {
                self.handler(url)
            }

            self.urlsToOpen = []
        }

        didFinishLaunching = true
    }

    @objc func handleUrlEvent(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let stringValue = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            os_log("UrlEventListener: unable to determine path", type: .error)
            Pixel.fire(.debug(event: .appOpenURLFailed,
                              error: NSError(domain: "CouldNotGetPath", code: -1, userInfo: nil)))
            return
        }

        guard let url = URL.makeURL(from: stringValue) else {
            os_log("UrlEventListener: failed to construct URL from path %s", type: .error, stringValue)
            Pixel.fire(.debug(event: .appOpenURLFailed,
                              error: NSError(domain: "CouldNotConstructURL", code: -1, userInfo: nil)))
            return
        }

        handleURLs([url])
    }

    func handleFiles(_ files: [String]) {
        let urls: [URL] = files.compactMap {
            if let url = URL(string: $0),
               let scheme = url.navigationalScheme,
               URL.NavigationalScheme.validSchemes.contains(scheme) {
                guard !url.isFileURL || FileManager.default.fileExists(atPath: url.path) else { return nil }
                return url
            } else if FileManager.default.fileExists(atPath: $0) {
                let url = URL(fileURLWithPath: $0)
                return url
            }
            return nil
        }

        handleURLs(urls)
    }

    private func handleURLs(_ urls: [URL]) {
        if didFinishLaunching {
            urls.forEach { self.handler($0) }
        } else {
            self.urlsToOpen.append(contentsOf: urls)
        }
    }

    private static func openURL(_ url: URL) {
#if NETWORK_PROTECTION
        if url.scheme?.isNetworkProtectionScheme == true {
            handleNetworkProtectionURL(url)
        }
#endif

#if DBP
        if url.scheme?.isDataBrokerProtectionScheme == true {
            handleDataBrokerProtectionURL(url)
        }
#endif

#if NETWORK_PROTECTION || DBP
        if url.scheme?.isNetworkProtectionScheme == false && url.scheme?.isDataBrokerProtectionScheme == false {
            WaitlistModalDismisser.dismissWaitlistModalViewControllerIfNecessary(url)
            WindowControllersManager.shared.show(url: url, source: .appOpenUrl, newTab: true)
        }
#else
        WindowControllersManager.shared.show(url: url, source: .appOpenUrl, newTab: true)
#endif
    }

#if NETWORK_PROTECTION || DBP

    /// Handles NetP URLs
    ///
    private static func handleNetworkProtectionURL(_ url: URL) {
        switch url {
        case AppLaunchCommand.showStatus.launchURL:
            Task {
                await WindowControllersManager.shared.showNetworkProtectionStatus()
            }
        case AppLaunchCommand.showSettings.launchURL:
            WindowControllersManager.shared.showPreferencesTab(withSelectedPane: .vpn)
        case AppLaunchCommand.shareFeedback.launchURL:
            WindowControllersManager.shared.showShareFeedbackModal()
        default:
            return
        }
    }

#endif

#if DBP
    /// Handles DBP URLs
    ///
    private static func handleDataBrokerProtectionURL(_ url: URL) {
        switch url {
        case DataBrokerProtectionNotificationCommand.showDashboard.url:
            WindowControllersManager.shared.showTab(with: .dataBrokerProtection)
        default:
            return
        }
    }

#endif

}

private extension String {
    static let dataBrokerProtectionScheme = "databrokerprotection"
    static let networkProtectionScheme = "networkprotection"

    var isDataBrokerProtectionScheme: Bool {
        return self == String.dataBrokerProtectionScheme
    }

    var isNetworkProtectionScheme: Bool {
        return self == String.networkProtectionScheme
    }
}
