//
//  WKWebView+Download.swift
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

import WebKit

extension WKWebView {

    func startDownload(from url: URL, completionHandler: @escaping (WebKitDownload) -> Void) {
        func completion(_ download: NSObject) {
            let casted = withUnsafePointer(to: download) {
                $0.withMemoryRebound(to: WebKitDownload.self, capacity: 1) { $0.pointee }
            }
            completionHandler(casted)
        }

        let request = URLRequest(url: url)
        if #available(macOS 11.3, *) {
            self.startDownload(using: request) { download in
                completion(download)
            }
        } else if configuration.processPool.responds(to: #selector(WKProcessPool._downloadURLRequest(_:websiteDataStore:originatingWebView:))) {
            configuration.processPool.setDownloadDelegateIfNeeded(using: LegacyWebKitDownloadDelegate.init)
            let download = configuration.processPool._downloadURLRequest(request,
                                                                         websiteDataStore: self.configuration.websiteDataStore,
                                                                         originatingWebView: self)
            completion(download)
        } else {
            assertionFailure("WKProcessPool does not respond to _downloadURLRequest:websiteDataStore:originatingWebView:")
        }
    }

}

extension WKNavigationActionPolicy {
    // https://github.com/WebKit/WebKit/blob/9a6f03d46238213231cf27641ed1a55e1949d074/Source/WebKit/UIProcess/API/Cocoa/WKNavigationDelegate.h#L49
    private static let download = WKNavigationActionPolicy(rawValue: Self.allow.rawValue + 1) ?? .cancel

    static func download(_ navigationAction: WKNavigationAction,
                         using webView: WKWebView) -> WKNavigationActionPolicy {
        webView.configuration.processPool
            .setDownloadDelegateIfNeeded(using: LegacyWebKitDownloadDelegate.init)?
            .registerDownloadNavigationAction(navigationAction)
        return .download
    }

}

extension WKNavigationResponsePolicy {
    private static let download = WKNavigationResponsePolicy(rawValue: Self.allow.rawValue + 1) ?? .cancel

    static func download(_ navigationResponse: WKNavigationResponse,
                         using webView: WKWebView) -> WKNavigationResponsePolicy {
        webView.configuration.processPool
            .setDownloadDelegateIfNeeded(using: LegacyWebKitDownloadDelegate.init)?
            .registerDownloadNavigationResponse(navigationResponse)
        return .download
    }
}
