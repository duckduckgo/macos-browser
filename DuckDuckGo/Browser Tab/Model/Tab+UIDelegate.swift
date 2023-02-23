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

import Combine
import Foundation
import Navigation
import WebKit

extension Tab: WKUIDelegate, PrintingUserScriptDelegate {

    // "protected" delegate property
    private var delegate: TabDelegate? {
        self.value(forKeyPath: Tab.objcDelegateKeyPath) as? TabDelegate
    }

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

        let fileTypes = UTType(mimeType: mimeType).map { [$0] } ?? []
        let dialog = UserDialogType.savePanel(.init(SavePanelParameters(suggestedFilename: suggestedFilename, fileTypes: fileTypes)) { result in
            guard let url = (try? result.get())?.url else { return }
            try? write(to: url)
        })
        userInteractionDialog = UserDialog(sender: .user, dialog: dialog)
    }

    @objc(_webView:createWebViewWithConfiguration:forNavigationAction:windowFeatures:completionHandler:)
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures,
                 completionHandler: @escaping (WKWebView?) -> Void) {

        let newWindowPolicy: NavigationDecision? = {
            // Are we handling custom Context Menu navigation action? (see ContextMenuManager)
            if let newWindowPolicy = self.contextMenuManager?.decideNewWindowPolicy(for: navigationAction) {
                return newWindowPolicy
            }

            return nil
        }()
        switch newWindowPolicy {
        // popup kind is known, action doesn‘t require Popup Permission
        case .allow(let targetKind):
            // proceed to web view creation
            completionHandler(self.createWebView(from: webView, with: configuration, for: navigationAction, of: targetKind))
            return
        // action doesn‘t require Popup Permission as it‘s user-initiated
        // TO BE FIXED: this also opens a new window when a popup ad is shown on click simultaneously with the main frame navigation:
        // https://app.asana.com/0/1177771139624306/1203798645462846/f
        case .none where navigationAction.isUserInitiated == true:
            // try to guess popup kind from provided windowFeatures
            let shouldSelectNewTab = !NSApp.isCommandPressed // this is actually not correct, to be fixed later
            let targetKind = NewWindowPolicy(windowFeatures, shouldSelectNewTab: shouldSelectNewTab)
            // proceed to web view creation
            completionHandler(self.createWebView(from: webView, with: configuration, for: navigationAction, of: targetKind))
            return
        case .cancel:
            // navigation action was handled before and cancelled
            completionHandler(nil)
            return
        case .none:
            break
        }

        // Popup Permission is needed: firing an async PermissionAuthorizationQuery
        let url = navigationAction.request.url
        let domain = navigationAction.safeSourceFrame?.safeRequest?.url?.host ?? self.url?.host
        self.permissions.request([.popups], forDomain: domain, url: url).receive { [weak self] result in
            guard let self, case .success(true) = result else {
                completionHandler(nil)
                return
            }
            let webView = self.createWebView(from: webView, with: configuration, for: navigationAction, of: .popup(size: windowFeatures.windowContentSize))

            self.permissions.permissions.popups
                .popupOpened(nextQuery: self.permissions.authorizationQueries.first(where: { $0.permissions.contains(.popups) }))
            completionHandler(webView)
        }
    }

    /// create a new Tab returning its WebView to a createWebViewWithConfiguration callback
    private func createWebView(from webView: WKWebView, with configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, of kind: NewWindowPolicy) -> WKWebView? {

        guard let delegate else { return nil }

        let tab = Tab(content: .none, webViewConfiguration: configuration, parentTab: self, canBeClosedWithBack: kind.isSelectedTab, webViewFrame: webView.superview?.bounds ?? .zero)
        delegate.tab(self, createdChild: tab, of: kind)

        let webView = tab.webView

        // WebKit automatically loads the request in the returned web view.
        return webView
    }

    /// official API callback fallback if async _webView::::completionHandler: can‘t be called for whatever reason
    @MainActor
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {

        var isCalledSynchronously = true
        var synchronousResultWebView: WKWebView?
        self.webView(webView, createWebViewWith: configuration, for: navigationAction, windowFeatures: windowFeatures) { [weak self] webView in
            guard self != nil else { return }
            if isCalledSynchronously {
                synchronousResultWebView = webView
            } else {
                // automatic loading won‘t start for asynchronous callback as we‘ve already returned nil at this point
                webView?.load(navigationAction.request)
            }
        }
        isCalledSynchronously = false

        return synchronousResultWebView
    }

    @objc(_webView:checkUserMediaPermissionForURL:mainFrameURL:frameIdentifier:decisionHandler:)
    func webView(_ webView: WKWebView,
                 checkUserMediaPermissionFor url: URL,
                 mainFrameURL: URL,
                 frameIdentifier: UInt64,
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
        self.permissions.permissions(.geolocation, requestedForDomain: frame.safeRequest?.url?.host, decisionHandler: decisionHandler)
    }

    // https://github.com/WebKit/WebKit/blob/9d7278159234e0bfa3d27909a19e695928f3b31e/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegatePrivate.h#L132
    @objc(_webView:requestGeolocationPermissionForOrigin:initiatedByFrame:decisionHandler:)
    @available(macOS 12, *)
    func webView(_ webView: WKWebView,
                 requestGeolocationPermissionFor origin: WKSecurityOrigin,
                 initiatedBy frame: WKFrameInfo,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        self.permissions.permissions(.geolocation, requestedForDomain: frame.safeRequest?.url?.host) { granted in
            decisionHandler(granted ? .grant : .deny)
        }
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let dialog = UserDialogType.openPanel(.init(parameters) { result in
            completionHandler(try? result.get())
        })
        userInteractionDialog = UserDialog(sender: .page(domain: frame.safeRequest?.url?.host), dialog: dialog)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        createAlertDialog(initiatedByFrame: frame, prompt: message) { parameters in
            .alert(.init(parameters, callback: { result in
                switch result {
                case .failure:
                    completionHandler()
                case .success:
                    completionHandler()
                }
            }))
        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        createAlertDialog(initiatedByFrame: frame, prompt: message) { parameters in
            .confirm(.init(parameters, callback: { result in
                switch result {
                case .failure:
                    completionHandler(false)
                case .success(let alertResult):
                    completionHandler(alertResult)
                }
            }))
        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        createAlertDialog(initiatedByFrame: frame, prompt: prompt, defaultInputText: defaultText) { parameters in
            .textInput(.init(parameters, callback: { result in
                switch result {
                case .failure:
                    completionHandler(nil)
                case .success(let alertResult):
                    completionHandler(alertResult)
                }
            }))
        }
    }

    private func createAlertDialog(initiatedByFrame frame: WKFrameInfo, prompt: String, defaultInputText: String? = nil, queryCreator: (JSAlertParameters) -> JSAlertQuery) {
        let parameters = JSAlertParameters(
            domain: frame.safeRequest?.url?.host ?? "",
            prompt: prompt,
            defaultInputText: defaultInputText
        )
        let alertQuery = queryCreator(parameters)
        let dialog = UserDialogType.jsDialog(alertQuery)
        userInteractionDialog = UserDialog(sender: .page(domain: frame.safeRequest?.url?.host), dialog: dialog)
    }

    func webViewDidClose(_ webView: WKWebView) {
        delegate?.closeTab(self)
    }

    func runPrintOperation(for frameHandle: FrameHandle?, in webView: WKWebView, completionHandler: ((Bool) -> Void)? = nil) {
        guard let printOperation = webView.printOperation(for: frameHandle) else { return }

        if printOperation.view?.frame.isEmpty == true {
            printOperation.view?.frame = webView.bounds
        }

        let dialog = UserDialogType.print(.init(printOperation) { result in
            completionHandler?((try? result.get()) ?? false)
        })
        userInteractionDialog = UserDialog(sender: .user, dialog: dialog)
    }

    @objc(_webView:printFrame:)
    func webView(_ webView: WKWebView, printFrame frameHandle: FrameHandle?) {
        self.runPrintOperation(for: frameHandle, in: webView)
    }

    @objc(_webView:printFrame:pdfFirstPageSize:completionHandler:)
    func webView(_ webView: WKWebView, printFrame frameHandle: FrameHandle?, pdfFirstPageSize size: CGSize, completionHandler: @escaping () -> Void) {
        self.runPrintOperation(for: frameHandle, in: webView) { _ in completionHandler() }
    }

    func print() {
        self.runPrintOperation(for: nil, in: self.webView)
    }

}
