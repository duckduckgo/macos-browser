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
        self.value(forKey: Tab.objcDelegateKeyPath) as? TabDelegate
    }

    // "protected" newWindowPolicyDecisionMakers
    private var newWindowPolicyDecisionMakers: [NewWindowPolicyDecisionMaker]? {
        self.value(forKey: Tab.objcNewWindowPolicyDecisionMakersKeyPath) as? [NewWindowPolicyDecisionMaker]
    }

    @objc(_webView:saveDataToFile:suggestedFilename:mimeType:originatingURL:)
    func webView(_ webView: WKWebView, saveDataToFile data: Data, suggestedFilename: String, mimeType: String, originatingURL: URL) {
        let prefs = DownloadsPreferences()
        if !prefs.alwaysRequestDownloadLocation,
           let location = prefs.effectiveDownloadLocation {
            let url = location.appendingPathComponent(suggestedFilename)
            try? data.writeFileWithProgress(to: url)
            return
        }

        let fileTypes = UTType(mimeType: mimeType).map { [$0] } ?? []
        let dialog = UserDialogType.savePanel(.init(SavePanelParameters(suggestedFilename: suggestedFilename, fileTypes: fileTypes)) { result in
            guard let url = (try? result.get())?.url else { return }
            try? data.writeFileWithProgress(to: url)
        })
        userInteractionDialog = UserDialog(sender: .user, dialog: dialog)
    }

    @MainActor
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {

        var isCalledSynchronously = true
        var synchronousResultWebView: WKWebView?
        handleCreateWebViewRequest(from: webView, with: configuration, for: navigationAction, windowFeatures: windowFeatures) { [weak self] webView in
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

    @MainActor
    private func handleCreateWebViewRequest(from webView: WKWebView,
                                            with configuration: WKWebViewConfiguration,
                                            for navigationAction: WKNavigationAction,
                                            windowFeatures: WKWindowFeatures,
                                            completionHandler: @escaping (WKWebView?) -> Void) {

        switch newWindowPolicy(for: navigationAction) {
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
            let targetKind = NewWindowPolicy(windowFeatures, shouldSelectNewTab: shouldSelectNewTab, isBurner: burnerMode.isBurner)
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

        let url = navigationAction.request.url
        let sourceUrl = navigationAction.safeSourceFrame?.safeRequest?.url ?? self.url ?? .empty
        guard let domain = sourceUrl.isFileURL ? .localhost : sourceUrl.host else {
            completionHandler(nil)
            return
        }
        // Popup Permission is needed: firing an async PermissionAuthorizationQuery
        self.permissions.request([.popups], forDomain: domain, url: url).receive { [weak self] result in
            guard let self, case .success(true) = result else {
                completionHandler(nil)
                return
            }
            let webView = self.createWebView(from: webView, with: configuration, for: navigationAction, of: .popup(origin: windowFeatures.origin, size: windowFeatures.size))

            completionHandler(webView)
        }
    }

    private func newWindowPolicy(for navigationAction: WKNavigationAction) -> NavigationDecision? {
        if let newWindowPolicy = self.decideNewWindowPolicy(for: navigationAction) {
            return newWindowPolicy
        }

        // Are we handling custom Context Menu navigation action or link click with a hotkey?
        for handler in self.newWindowPolicyDecisionMakers ?? [] {
            guard let newWindowPolicy = handler.decideNewWindowPolicy(for: navigationAction) else { continue }
            return newWindowPolicy
        }

        // allow popups opened from an empty window console
        let sourceUrl = navigationAction.safeSourceFrame?.safeRequest?.url ?? self.url ?? .empty
        if sourceUrl.isEmpty || sourceUrl.scheme == URL.NavigationalScheme.about.rawValue {
            return .allow(.tab(selected: true, burner: burnerMode.isBurner))
        }

        return nil
    }

    /// create a new Tab returning its WebView to a createWebViewWithConfiguration callback
    @MainActor
    private func createWebView(from webView: WKWebView, with configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, of kind: NewWindowPolicy) -> WKWebView? {
        guard let delegate else { return nil }

        let tab = Tab(content: .none,
                      webViewConfiguration: configuration,
                      parentTab: self,
                      burnerMode: burnerMode,
                      canBeClosedWithBack: kind.isSelectedTab,
                      webViewSize: webView.superview?.bounds.size ?? .zero)
        delegate.tab(self, createdChild: tab, of: kind)

        let webView = tab.webView

        // WebKit automatically loads the request in the returned web view.
        return webView
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

        self.permissions.permissions(permissions, requestedForDomain: origin.host, decisionHandler: decisionHandler)
    }

    // https://github.com/WebKit/WebKit/blob/9d7278159234e0bfa3d27909a19e695928f3b31e/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegatePrivate.h#L126
    @objc(_webView:requestUserMediaAuthorizationForDevices:url:mainFrameURL:decisionHandler:)
    func webView(_ webView: WKWebView,
                 requestUserMediaAuthorizationFor devices: _WKCaptureDevices,
                 url: URL,
                 mainFrameURL: URL,
                 decisionHandler: @escaping (Bool) -> Void) {
        guard let permissions = [PermissionType](devices: devices),
              let host = url.isFileURL ? .localhost : url.host,
              !host.isEmpty else {
            decisionHandler(false)
            return
        }

        self.permissions.permissions(permissions, requestedForDomain: host, decisionHandler: decisionHandler)
    }

    @objc(_webView:mediaCaptureStateDidChange:)
    func webView(_ webView: WKWebView, mediaCaptureStateDidChange state: _WKMediaCaptureStateDeprecated) {
        self.permissions.mediaCaptureStateDidChange()
    }

    // https://github.com/WebKit/WebKit/blob/9d7278159234e0bfa3d27909a19e695928f3b31e/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegatePrivate.h#L131
    @objc(_webView:requestGeolocationPermissionForFrame:decisionHandler:)
    func webView(_ webView: WKWebView, requestGeolocationPermissionFor frame: WKFrameInfo, decisionHandler: @escaping (Bool) -> Void) {
        let url = frame.safeRequest?.url ?? .empty
        let host = url.isFileURL ? .localhost : (url.host ?? "")
        self.permissions.permissions(.geolocation, requestedForDomain: host, decisionHandler: decisionHandler)
    }

    // https://github.com/WebKit/WebKit/blob/9d7278159234e0bfa3d27909a19e695928f3b31e/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegatePrivate.h#L132
    @objc(_webView:requestGeolocationPermissionForOrigin:initiatedByFrame:decisionHandler:)
    @available(macOS 12, *)
    func webView(_ webView: WKWebView,
                 requestGeolocationPermissionFor origin: WKSecurityOrigin,
                 initiatedBy frame: WKFrameInfo,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        let url = frame.safeRequest?.url ?? .empty
        let host = url.isFileURL ? .localhost : (url.host ?? "")
        self.permissions.permissions(.geolocation, requestedForDomain: host) { granted in
            decisionHandler(granted ? .grant : .deny)
        }
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let dialog = UserDialogType.openPanel(.init(parameters) { result in
            completionHandler(try? result.get())
        })
        let url = frame.safeRequest?.url ?? .empty
        let host = url.isFileURL ? .localhost : (url.host ?? "")
        userInteractionDialog = UserDialog(sender: .page(domain: host), dialog: dialog)
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
        let url = frame.safeRequest?.url ?? .empty
        let host = url.isFileURL ? .localhost : (url.host ?? "")
        userInteractionDialog = UserDialog(sender: .page(domain: host), dialog: dialog)
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
