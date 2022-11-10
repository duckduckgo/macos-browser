//
//  ContentOverlayViewController.swift
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

import Cocoa
import WebKit
import Combine
import BrowserServicesKit
import Autofill

public final class ContentOverlayViewController: NSViewController, EmailManagerRequestDelegate {

    @IBOutlet var webView: WKWebView!
    private var topAutofillUserScript: OverlayAutofillUserScript?
    private var appearanceCancellable: AnyCancellable?

    public weak var autofillInterfaceToChild: OverlayAutofillUserScriptDelegate?

    lazy var emailManager: EmailManager = {
        let emailManager = EmailManager()
        emailManager.requestDelegate = self
        return emailManager
    }()

    lazy var vaultManager: SecureVaultManager = {
        let manager = SecureVaultManager(passwordManager: PasswordManagerCoordinator())
        manager.delegate = self
        return manager
    }()

    public override func viewDidLoad() {
        initWebView()
        addTrackingArea()

        appearanceCancellable = NSApp.publisher(for: \.effectiveAppearance).map { $0 as NSAppearance? }.sink { [weak self] appearance in
            self?.webView.appearance = appearance
        }
    }

    public func setType(serializedInputContext: String, zoomFactor: CGFloat?) {
        guard let topAutofillUserScript = topAutofillUserScript else { return }
        if let zoomFactor = zoomFactor {
            initWebView()
            webView.magnification = zoomFactor
        }
        topAutofillUserScript.serializedInputContext = serializedInputContext
    }

    public override func mouseMoved(with event: NSEvent) {
        // Change to flipped coordinate system
        let outY = webView.frame.height - event.locationInWindow.y
        messageMouseMove(x: event.locationInWindow.x, y: outY)
    }

    private func addTrackingArea() {
        let trackingOptions: NSTrackingArea.Options = [ .activeInActiveApp,
                                                        .enabledDuringMouseDrag,
                                                        .mouseMoved,
                                                        .inVisibleRect ]
        let trackingArea = NSTrackingArea(rect: webView.frame, options: trackingOptions, owner: self, userInfo: nil)
        webView.addTrackingArea(trackingArea)
    }

    public override func viewWillAppear() {
        guard let topAutofillUserScript = topAutofillUserScript else { return }
        topAutofillUserScript.websiteAutofillInstance = autofillInterfaceToChild

        webView.appearance = NSApp.effectiveAppearance

        let url = Autofill.bundle.url(forResource: "assets/TopAutofill", withExtension: "html")
        if let url = url {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            return
        }
    }

    public override func viewWillDisappear() {
        // We should never see this but it's better than a flash of old content
        webView.load(URLRequest(url: URL(string: "about:blank")!))
    }

    public func messageMouseMove(x: CGFloat, y: CGFloat) {
        // Fakes the elements being focused by the user as it doesn't appear there's much else we can do
        let script = """
        (() => {
        const x = \(x);
        const y = \(y);
        window.dispatchEvent(new CustomEvent('mouseMove', {detail: {x, y}}))
        })();
        """
        webView.evaluateJavaScript(script)
    }

    public func buildAutofillSource() -> AutofillUserScriptSourceProvider {
        let scriptSourceProviding = DefaultScriptSourceProvider()
        return scriptSourceProviding.buildAutofillSource()
    }

    private func initWebView() {
        let scriptSourceProvider = buildAutofillSource()
        self.topAutofillUserScript = OverlayAutofillUserScript(scriptSourceProvider: scriptSourceProvider, overlay: self)
        guard let topAutofillUserScript = topAutofillUserScript else { return }
        let configuration = WKWebViewConfiguration()

#if DEBUG
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
#endif

        final class OverlayWebView: WKWebView {
            public override func scrollWheel(with theEvent: NSEvent) {
                // No-op to prevent scrolling
            }
        }

        let webView = OverlayWebView(frame: .zero, configuration: configuration)
        webView.allowsLinkPreview = false
        webView.window?.acceptsMouseMovedEvents = true
        webView.window?.ignoresMouseEvents = false
        webView.configuration.userContentController.addHandler(topAutofillUserScript)
        webView.configuration.userContentController.addUserScript(topAutofillUserScript.makeWKUserScript())
        self.webView = webView
        view.addAndLayout(webView)
        topAutofillUserScript.contentOverlay = self
        topAutofillUserScript.emailDelegate = emailManager
        topAutofillUserScript.vaultDelegate = vaultManager
    }

    // EmailManagerRequestDelegate

    // swiftlint:disable function_parameter_count
    public func emailManager(_ emailManager: EmailManager,
                             requested url: URL,
                             method: String,
                             headers: [String: String],
                             parameters: [String: String]?,
                             httpBody: Data?,
                             timeoutInterval: TimeInterval,
                             completion: @escaping (Data?, Error?) -> Void) {
        let currentQueue = OperationQueue.current

        let finalURL = url.appendingParameters(parameters ?? [:])

        var request = URLRequest(url: finalURL, timeoutInterval: timeoutInterval)
        request.allHTTPHeaderFields = headers
        request.httpMethod = method
        request.httpBody = httpBody
        URLSession.shared.dataTask(with: request) { (data, _, error) in
            currentQueue?.addOperation {
                completion(data, error)
            }
        }.resume()
    }
    // swiftlint:enable function_parameter_count
    
    public func emailManagerKeychainAccessFailed(accessType: EmailKeychainAccessType, error: EmailKeychainAccessError) {
        var parameters = [
            "access_type": accessType.rawValue,
            "error": error.errorDescription
        ]
        
        if case let .keychainLookupFailure(status) = error {
            parameters["keychain_status"] = String(status)
            parameters["keychain_operation"] = "lookup"
        }
        
        if case let .keychainDeleteFailure(status) = error {
            parameters["keychain_status"] = String(status)
            parameters["keychain_operation"] = "delete"
        }
        
        if case let .keychainSaveFailure(status) = error {
            parameters["keychain_status"] = String(status)
            parameters["keychain_operation"] = "save"
        }

        Pixel.fire(.debug(event: .emailAutofillKeychainError), withAdditionalParameters: parameters)
    }

    private enum Constants {
        static let minWidth: CGFloat = 315
        static let minHeight: CGFloat = 56
    }

    public func requestResizeToSize(_ size: CGSize) {
        var widthOut = size.width
        if widthOut < Constants.minWidth {
            widthOut = Constants.minWidth
        }
        var heightOut = size.height
        if heightOut < Constants.minHeight {
            heightOut = Constants.minHeight
        }
        self.preferredContentSize = CGSize(width: widthOut, height: heightOut)
    }
}

extension ContentOverlayViewController: OverlayAutofillUserScriptPresentationDelegate {
    public func overlayAutofillUserScript(_ overlayAutofillUserScript: OverlayAutofillUserScript, requestResizeToSize: CGSize) {
        self.requestResizeToSize(requestResizeToSize)
    }
}

extension ContentOverlayViewController: SecureVaultManagerDelegate {
    
    public func secureVaultManagerIsEnabledStatus(_: SecureVaultManager) -> Bool {
        return true
    }

    public func secureVaultManager(_: SecureVaultManager, promptUserToStoreAutofillData data: AutofillData) {
        // No-op, the content overlay view controller should not be prompting the user to store data
    }
    
    public func secureVaultManager(_: SecureVaultManager,
                                   promptUserToAutofillCredentialsForDomain domain: String,
                                   withAccounts accounts: [SecureVaultModels.WebsiteAccount],
                                   withTrigger trigger: AutofillUserScript.GetTriggerType,
                                   completionHandler: @escaping (SecureVaultModels.WebsiteAccount?) -> Void) {
        // no-op on macOS
    }

    public func secureVaultManager(_: SecureVaultManager, didAutofill type: AutofillType, withObjectId objectId: String) {
        Pixel.fire(.formAutofilled(kind: type.formAutofillKind))
    }
    
    public func secureVaultManagerShouldAutomaticallyUpdateCredentialsWithoutUsername(_: SecureVaultManager) -> Bool {
        return true
    }
    
    public func secureVaultManager(_: SecureVaultManager, didRequestAuthenticationWithCompletionHandler handler: @escaping (Bool) -> Void) {
        DeviceAuthenticator.shared.authenticateUser(reason: .autofill) { authenticationResult in
            handler(authenticationResult.authenticated)
        }
    }

    public func secureVaultInitFailed(_ error: SecureVaultError) {
        SecureVaultErrorReporter.shared.secureVaultInitFailed(error)
    }

}
