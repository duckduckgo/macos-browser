//
//  WebViewUIDelegate.swift
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

@MainActor
@objc protocol WebViewUIDelegate: WKUIDelegate {

    // MARK: Private WebKit methods

    @objc(_webView:createWebViewWithConfiguration:forNavigationAction:windowFeatures:completionHandler:)
    optional func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures, completionHandler: @escaping (WKWebView?) -> Void)

    @objc(_webView:printFrame:)
    optional func webView(_ webView: WKWebView, printFrame handle: Any)

    @available(macOS 12, *)
    @objc(_webView:printFrame:pdfFirstPageSize:completionHandler:)
    optional func webView(_ webView: WKWebView, printFrame handle: Any, pdfFirstPageSize size: CGSize, completionHandler: () -> Void)

    @objc(_webView:saveDataToFile:suggestedFilename:mimeType:originatingURL:)
    optional func webView(_ webView: WKWebView, saveDataToFile data: Data, suggestedFilename: String, mimeType: String, originatingURL: URL)

    @objc(_webView:checkUserMediaPermissionForURL:mainFrameURL:frameIdentifier:decisionHandler:)
    optional func webView(_ webView: WKWebView, checkUserMediaPermissionFor url: URL, mainFrameURL: URL, frameIdentifier frame: UInt, decisionHandler: @escaping (String, Bool) -> Void)

    // https://github.com/WebKit/WebKit/blob/9d7278159234e0bfa3d27909a19e695928f3b31e/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegatePrivate.h#L126
    @objc(_webView:requestUserMediaAuthorizationForDevices:url:mainFrameURL:decisionHandler:)
    optional func webView(_ webView: WKWebView, requestUserMediaAuthorizationFor devices: _WKCaptureDevices, url: URL, mainFrameURL: URL, decisionHandler: @escaping (Bool) -> Void)

    @objc(_webView:mediaCaptureStateDidChange:)
    optional func webView(_ webView: WKWebView, mediaCaptureStateDidChange state: _WKMediaCaptureStateDeprecated)

    // https://github.com/WebKit/WebKit/blob/9d7278159234e0bfa3d27909a19e695928f3b31e/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegatePrivate.h#L131
    @objc(_webView:requestGeolocationPermissionForFrame:decisionHandler:)
    optional func webView(_ webView: WKWebView, requestGeolocationPermissionFor frame: WKFrameInfo, decisionHandler: @escaping (Bool) -> Void)

    // https://github.com/WebKit/WebKit/blob/9d7278159234e0bfa3d27909a19e695928f3b31e/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegatePrivate.h#L132
    @objc(_webView:requestGeolocationPermissionForOrigin:initiatedByFrame:decisionHandler:)
    @available(macOS 12, *)
    optional func webView(_ webView: WKWebView, requestGeolocationPermissionFor origin: WKSecurityOrigin, initiatedBy frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void)

    @objc optional func webView(_ webView: WebView, willOpenContextMenu menu: NSMenu, with event: NSEvent)
    @objc optional func webView(_ webView: WebView, didCloseContextMenu menu: NSMenu, with event: NSEvent?)

}
