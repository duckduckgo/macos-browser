//
//  ContentPopupViewController.swift
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

import Cocoa
import WebKit
import Combine
import BrowserServicesKit


public final class ContentOverlayViewController: NSViewController, EmailManagerRequestDelegate {
    
    @IBOutlet var webView: WKWebView!
    private let topAutofillUserScript = TopAutofillUserScript()
    private var cancellables = Set<AnyCancellable>()
    @Published var pendingUpdates = Set<String>()
    
    public var messageInterfaceBack: AutofillMessaging?
    
    lazy var emailManager: EmailManager = {
        let emailManager = EmailManager()
        emailManager.requestDelegate = self
        return emailManager
    }()
    
    lazy var vaultManager: SecureVaultManager = {
        let manager = SecureVaultManager()
        manager.delegate = self
        return manager
    }()
    
    public override func viewDidLoad() {
        initWebView()
        print("TODOJKT viewDidLoad")
        addTrackingArea()
    }

    public func setType(inputType: String, zoomFactor: CGFloat?) {
        if let zoomFactor = zoomFactor {
            initWebView()
            webView.magnification = zoomFactor
        }
        topAutofillUserScript.inputType = inputType
    }
    
    public override func mouseMoved(with event: NSEvent) {
        let outY = webView.frame.height - event.locationInWindow.y
        // TODOJKT covert coordinate properly
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
        print("TODOJKT viewWillAppear")
        //let bundle = Bundle.init(identifier: "BrowserServicesKit")
        //let url = bundle!.url(forResource: "TopAutofill", withExtension: "html")!
        topAutofillUserScript.messageInterfaceBack = messageInterfaceBack
        Bundle.allBundles.forEach { bundle in
            let url = bundle.url(forResource: "TopAutofill", withExtension: "html")
            if let url = url {
                print("TODOJKT load url \(url) \(bundle)")
                webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
                return
            }
        }
        // TODOJKT let bundle = Bundle(identifier: "BrowserServicesKit_BrowserServicesKit")

    }

    public override func viewWillDisappear() {
        print("TODOJKT viewWillDisappear")
        cancellables.removeAll()
        // We should never see this but it's better than a flash of old content
        webView.load(URLRequest(url: URL(string: "about:blank")!))
    }

    public func isPendingUpdates() -> Bool {
        return !pendingUpdates.isEmpty
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

    private func initWebView() {
        //guard webView == nil else { return }
        let configuration = WKWebViewConfiguration()
        
#if DEBUG
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
#endif
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView = webView
        self.webView.window?.acceptsMouseMovedEvents = true
        self.webView.window?.ignoresMouseEvents = false
        view.addAndLayout(webView)
        webView.configuration.userContentController.addHandler(topAutofillUserScript)
        webView.configuration.userContentController.addUserScript(topAutofillUserScript.makeWKUserScript())
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

        let finalURL: URL

        if let parameters = parameters {
            finalURL = (try? url.addParameters(parameters)) ?? url
        } else {
            finalURL = url
        }

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
    
}

extension ContentOverlayViewController: TopAutofillUserScriptDelegate {
    public func setSize(height: CGFloat, width: CGFloat) {
        var widthOut = width
        // TODO make constants
        if (widthOut < 315) {
            widthOut = 315
        }
        var heightOut = height
        if (heightOut < 56) {
            heightOut = 56
        }
        self.preferredContentSize = CGSize(width: widthOut, height: heightOut)
    }
}

extension ContentOverlayViewController: SecureVaultManagerDelegate {

    public func secureVaultManager(_: SecureVaultManager, promptUserToStoreCredentials credentials: SecureVaultModels.WebsiteCredentials) {
        // TODO
        // delegate?.tab(self, requestedSaveCredentials: credentials)
    }

    public func secureVaultManager(_: SecureVaultManager, didAutofill type: AutofillType, withObjectId objectId: Int64) {
        // TODO
        // Pixel.fire(.formAutofilled(kind: type.formAutofillKind))
    }

}
