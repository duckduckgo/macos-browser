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
import AppKit
import PixelKit
import Subscription
import NetworkProtectionUI
import VPNAppLauncher
import DataBrokerProtection
import os.log
import BrowserServicesKit

// @MainActor
final class URLEventHandler {

    @MainActor
    private static let vpnURLEventHandler = VPNURLEventHandler()

    private let handler: (URL) -> Void

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
                DispatchQueue.main.async {
                    self.handler(url)
                }
            }

            self.urlsToOpen = []
        }

        didFinishLaunching = true
    }

    @objc func handleUrlEvent(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let stringValue = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            Logger.general.error("UrlEventListener: unable to determine path")
            let error = NSError(domain: "CouldNotGetPath", code: -1, userInfo: nil)
            PixelKit.fire(DebugEvent(GeneralPixel.appOpenURLFailed, error: error))
            return
        }

        guard let url = URL.makeURL(from: stringValue) else {
            Logger.general.debug("UrlEventListener: failed to construct URL from path \(stringValue)")
            let error = NSError(domain: "CouldNotConstructURL", code: -1, userInfo: nil)
            PixelKit.fire(DebugEvent(GeneralPixel.appOpenURLFailed, error: error))
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
            urls.forEach {
                self.handler($0)
            }
        } else {
            self.urlsToOpen.append(contentsOf: urls)
        }
    }

    private static func openURL(_ url: URL) {
        if url.scheme?.isNetworkProtectionScheme == true {
            Task { @MainActor in
                await vpnURLEventHandler.handle(url)
            }
        }

        if url.scheme?.isDataBrokerProtectionScheme == true {
            handleDataBrokerProtectionURL(url)
        }

        DispatchQueue.main.async {
            if url.isFileURL && url.pathExtension == WebKitDownloadTask.downloadExtension {
                guard let mainViewController = {
                    if let mainWindowController = WindowControllersManager.shared.lastKeyMainWindowController {
                        return mainWindowController.mainViewController
                    }
                    return WindowsManager.openNewWindow(with: .newtab, source: .ui, isBurner: false)?.contentViewController as? MainViewController
                }() else { return }

                if !mainViewController.navigationBarViewController.isDownloadsPopoverShown {
                    mainViewController.navigationBarViewController.toggleDownloadsPopover(keepButtonVisible: false)
                }

                return
            }

            if url.scheme?.isNetworkProtectionScheme == false && url.scheme?.isDataBrokerProtectionScheme == false {
                WindowControllersManager.shared.show(url: url, source: .appOpenUrl, newTab: true)
            }
        }
    }

    /// Handles DBP URLs
    ///
    private static func handleDataBrokerProtectionURL(_ url: URL) {
        switch url {
        case DataBrokerProtectionNotificationCommand.showDashboard.url:
            NotificationCenter.default.post(name: DataBrokerProtectionNotifications.shouldReloadUI, object: nil)
            DispatchQueue.main.async {
                WindowControllersManager.shared.showTab(with: .dataBrokerProtection)
            }
        default:
            return
        }
    }
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
