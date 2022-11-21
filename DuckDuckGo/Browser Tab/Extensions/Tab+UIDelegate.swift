//
//  TabUIDelegate.swift
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

extension Tab: WebViewUIDelegate {

    @objc(_webView:saveDataToFile:suggestedFilename:mimeType:originatingURL:)
    func webView(_ webView: WKWebView, saveDataToFile data: Data, suggestedFilename: String, mimeType: String, originatingURL: URL) {
        func write(to url: URL) throws {
            let progress = Progress(totalUnitCount: 1,
                                    fileOperationKind: .downloading,
                                    kind: .file,
                                    isPausable: false,
                                    isCancellable: false,
                                    fileURL: url)
            progress.publish()
            defer {
                progress.unpublish()
            }

            try data.write(to: url)
            progress.completedUnitCount = progress.totalUnitCount
        }

        let prefs = DownloadsPreferences()
        if !prefs.alwaysRequestDownloadLocation,
           let location = prefs.effectiveDownloadLocation {
            let url = location.appendingPathComponent(suggestedFilename)
            try? write(to: url)

            return
        }

        delegate?.chooseDestination(suggestedFilename: suggestedFilename,
                                    directoryURL: prefs.effectiveDownloadLocation,
                                    fileTypes: UTType(mimeType: mimeType).map { [$0] } ?? []) { url, _ in
            guard let url = url else { return }
            try? write(to: url)
        }
    }

    @objc(_webView:createWebViewWithConfiguration:forNavigationAction:windowFeatures:completionHandler:)
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures,
                 completionHandler: @escaping (WKWebView?) -> Void) {

        let url = navigationAction.request.url
        let domain = navigationAction.sourceFrame.request.url?.host ?? self.url?.host
        let webViewFrame = webView.frame
        let windowContentSize = NSSize(width: windowFeatures.width?.intValue ?? 1024,
                                       height: windowFeatures.height?.intValue ?? 752)

        // TODO: works wrong!
        // cmd+click should open background tab
        // cmd+shift+click should open selected tab
        // cmd+alt+click should open background window
        // cmd+alt+shift+click should open new window
        // alt+[shift]+click should download

        let popup = windowFeatures.toolbarsVisibility?.boolValue != true
        let windowFeatures = self.webView.expectedNavigation?.find(lastWhere: {
            if case .willRequestNewWebView(url: url, target: _, windowFeatures: let expectedFeatures) = $0 { return expectedFeatures }
            return nil
        }) ?? {
            // not initiated by Tab - check initiating event
            // TODO: !NSApp.isCommandPressed? what about this event? NSApp.currentEvent maybe?
            WindowFeatures(wkWindowFeatures: windowFeatures, selected: NSApp.isShiftPressed)
        }()
        
        let newWindow = windowFeatures.window ?? false
        let selected = windowFeatures.selected ?? false

        func nextQuery(for parentTab: Tab) -> PermissionAuthorizationQuery? {
            parentTab.permissions.authorizationQueries.first(where: { $0.permissions.contains(.popups) })
        }
        let shouldOpenPopupNow: Bool = {
            if navigationAction.isUserInitiated { return true }

            var isCalledSynchronously = true
            defer { isCalledSynchronously = false }
            var result = false

            self.permissions.permissions(.popups, requestedForDomain: domain, url: url) { [weak self] granted in
                if isCalledSynchronously {
                    result = granted
                    return
                }

                guard granted, let self = self else {
                    completionHandler(nil)
                    return
                }

                let tab = Tab(content: .none, webViewConfiguration: configuration, parentTab: self, webViewFrame: webViewFrame)
                if popup {
                    WindowsManager.openPopUpWindow(with: tab, contentSize: windowContentSize)
                } else {
                    WindowsManager.openNewWindow(with: tab)
                }

                self.permissions.permissions.popups.popupOpened(nextQuery: nextQuery(for: self))

                completionHandler(tab.webView)
            }
            return result
        }()

        guard shouldOpenPopupNow else { return }

        let tab = Tab(content: .none, webViewConfiguration: configuration, parentTab: self, webViewFrame: webViewFrame)
        if popup {
            WindowsManager.openPopUpWindow(with: tab, contentSize: windowContentSize)
        } else if newWindow {
            WindowsManager.openNewWindow(with: tab)
        } else {
            self.delegate?.tab(self, createdChild: tab, selected: selected)
        }

        self.permissions.permissions.popups.popupOpened(nextQuery: nextQuery(for: self))

        // WebKit automatically loads the request in the returned web view.
        completionHandler(tab.webView)
    }

    // official API callback fallback if async _webView::::completionHandler: can‘t be called for whatever reason
    @MainActor
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {

        var result: WKWebView?
        var isCalledSynchronously = true
        defer { isCalledSynchronously = false }

        self.webView(webView, createWebViewWith: configuration, for: navigationAction, windowFeatures: windowFeatures) { [weak self] webView in
            guard self != nil else { return }
            result = webView
            if !isCalledSynchronously,
               let url = navigationAction.request.url {
                // automatic loading won‘t start for async callback
                webView?.load(url)
            }
        }

        return result
    }

    @objc(_webView:checkUserMediaPermissionForURL:mainFrameURL:frameIdentifier:decisionHandler:)
    func webView(_ webView: WKWebView,
                 checkUserMediaPermissionFor url: URL,
                 mainFrameURL: URL,
                 frameIdentifier frame: UInt,
                 decisionHandler: @escaping (String, Bool) -> Void) {
        self.permissions.checkUserMediaPermission(for: url, mainFrameURL: mainFrameURL, decisionHandler: decisionHandler)
    }

    // https://github.com/WebKit/WebKit/blob/995f6b1595611c934e742a4f3a9af2e678bc6b8d/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegate.h#L147
    @objc(webView:requestMediaCapturePermissionForOrigin:initiatedByFrame:type:decisionHandler:)
    @available(macOS 12, *)
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        guard let permissions = [PermissionType](devices: type) else {
            assertionFailure("Could not decode PermissionType")
            decisionHandler(.deny)
            return
        }

        self.permissions.permissions(permissions, requestedForDomain: origin.host) { granted in
            decisionHandler(granted ? .grant : .deny)
        }
    }

    // https://github.com/WebKit/WebKit/blob/9d7278159234e0bfa3d27909a19e695928f3b31e/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegatePrivate.h#L126
    @objc(_webView:requestUserMediaAuthorizationForDevices:url:mainFrameURL:decisionHandler:)
    func webView(_ webView: WKWebView,
                 requestUserMediaAuthorizationFor devices: _WKCaptureDevices,
                 url: URL,
                 mainFrameURL: URL,
                 decisionHandler: @escaping (Bool) -> Void) {
        guard let permissions = [PermissionType](devices: devices) else {
            decisionHandler(false)
            return
        }

        self.permissions.permissions(permissions, requestedForDomain: url.host, decisionHandler: decisionHandler)
    }

    @objc(_webView:mediaCaptureStateDidChange:)
    func webView(_ webView: WKWebView, mediaCaptureStateDidChange state: _WKMediaCaptureStateDeprecated) {
        self.permissions.mediaCaptureStateDidChange()
    }

    // https://github.com/WebKit/WebKit/blob/9d7278159234e0bfa3d27909a19e695928f3b31e/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegatePrivate.h#L131
    @objc(_webView:requestGeolocationPermissionForFrame:decisionHandler:)
    func webView(_ webView: WKWebView, requestGeolocationPermissionFor frame: WKFrameInfo, decisionHandler: @escaping (Bool) -> Void) {
        self.permissions.permissions(.geolocation, requestedForDomain: frame.request.url?.host, decisionHandler: decisionHandler)
    }

    // https://github.com/WebKit/WebKit/blob/9d7278159234e0bfa3d27909a19e695928f3b31e/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegatePrivate.h#L132
    @objc(_webView:requestGeolocationPermissionForOrigin:initiatedByFrame:decisionHandler:)
    @available(macOS 12, *)
    func webView(_ webView: WKWebView,
                 requestGeolocationPermissionFor origin: WKSecurityOrigin,
                 initiatedBy frame: WKFrameInfo,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        self.permissions.permissions(.geolocation, requestedForDomain: frame.request.url?.host) { granted in
            decisionHandler(granted ? .grant : .deny)
        }
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo) async -> [URL]? {
        await delegate?.tab(self, runOpenPanelAllowingMultipleSelection: parameters.allowsMultipleSelection, allowsDirectories: false)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async {

//        guard webView === self.webView, let window = view.window else {
//            os_log("%s: Could not display JS alert panel", type: .error, className)
//            completionHandler()
//            return
//        }
//
//        let alert = NSAlert.javascriptAlert(with: message)
//        alert.beginSheetModal(for: window) { _ in
//            completionHandler()
//        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {

//        guard webView === self.webView, let window = view.window else {
//            os_log("%s: Could not display JS confirmation panel", type: .error, className)
//            completionHandler(false)
//            return
//        }
//
//        let alert = NSAlert.javascriptConfirmation(with: message)
//        alert.beginSheetModal(for: window) { response in
//            completionHandler(response == .alertFirstButtonReturn)
//        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {

//        guard webView === self.webView, let window = view.window else {
//            os_log("%s: Could not display JS text input panel", type: .error, className)
//            completionHandler(nil)
//            return
//        }
//
//        let alert = NSAlert.javascriptTextInput(prompt: prompt, defaultText: defaultText)
//        alert.beginSheetModal(for: window) { response in
//            guard let textField = alert.accessoryView as? NSTextField else {
//                os_log("BrowserTabViewController: Textfield not found in alert", type: .error)
//                completionHandler(nil)
//                return
//            }
//            let answer = response == .alertFirstButtonReturn ? textField.stringValue : nil
//            completionHandler(answer)
//        }
    }

    func webViewDidClose(_ webView: WKWebView) {
        delegate?.closeTab(self)
    }

    @objc(_webView:printFrame:)
    func webView(_ webView: WKWebView, printFrame handle: Any) {
        self.extensions.printing?.print(using: webView, frameHandle: handle)
    }

    @available(macOS 12, *)
    @objc(_webView:printFrame:pdfFirstPageSize:completionHandler:)
    func webView(_ webView: WKWebView, printFrame handle: Any, pdfFirstPageSize size: CGSize, completionHandler: () -> Void) {
        self.webView(webView, printFrame: handle)
        completionHandler()
    }

}
