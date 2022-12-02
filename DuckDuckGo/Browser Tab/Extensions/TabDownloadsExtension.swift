//
//  TabDownloadsExtension.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import Foundation
import WebKit

final class TabDownloadsExtension: TabExtension {

    private weak var tab: Tab?
    // Used to track if an error was caused by a download navigation.
    private var currentDownload: URL?

    init() {}

    func attach(to tab: Tab) {
        self.tab = tab
    }

}

extension TabDownloadsExtension: NSCodingExtension {

    private enum NSSecureCodingKeys {
        static let currentDownload = "currentDownload"
    }

    func encode(using coder: NSCoder) {
        coder.encode(currentDownload, forKey: NSSecureCodingKeys.currentDownload)
    }
    func awakeAfter(using decoder: NSCoder) {
        self.currentDownload = decoder.decodeObject(of: NSURL.self, forKey: NSSecureCodingKeys.currentDownload) as? URL
    }

}

extension TabDownloadsExtension: NavigationResponder {

    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
//        var isDownloadLinkAction: Bool {
//            // TODO: move NSApp modifier options check to dependedncies
//            navigationAction.navigationType == .linkActivated && NSApp.isOptionPressed && !NSApp.isCommandPressed
//        }

        if navigationAction.request.url != currentDownload || navigationAction.isUserInitiated {
            currentDownload = nil
        }
//        if navigationAction.shouldDownload || isDownloadLinkAction {
//            return .download
//        }

        return .next
    }

    func decidePolicy(for navigationResponse: NavigationResponse) async -> NavigationResponsePolicy? {
        guard !navigationResponse.canShowMIMEType || navigationResponse.shouldDownload else { return .next }

        if navigationResponse.response.isSuccessfulHTTPURLResponse {
            // prevent download twice
            guard currentDownload != navigationResponse.response.url else {
                // prevent download twice
                return .cancel
            }
            currentDownload = navigationResponse.response.url
            return .download
        }

        return .next
    }

    func navigationAction(_ navigationAction: NavigationAction, didBecome download: WebKitDownload) {
        FileDownloadManager.shared.add(download, delegate: tab?.delegate, location: .auto, postflight: .none)
    }

    func navigationResponse(_ navigationResponse: NavigationResponse, didBecome download: WebKitDownload) {
        FileDownloadManager.shared.add(download, delegate: tab?.delegate, location: .auto, postflight: .none)

        // Note this can result in tabs being left open, e.g. download button on this page:
        // https://en.wikipedia.org/wiki/Guitar#/media/File:GuitareClassique5.png
        // Safari closes new tabs that were opened and then create a download instantly.
        // TODO: Navigation.didComit?
        if tab?.canBeClosedWithBack ?? false {
            DispatchQueue.main.async { [weak tab] in
                tab?.close()
            }
        }
    }

}
