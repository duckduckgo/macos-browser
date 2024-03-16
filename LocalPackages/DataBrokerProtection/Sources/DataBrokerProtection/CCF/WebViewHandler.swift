//
//  WebViewHandler.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import BrowserServicesKit
import UserScript
import Common

protocol WebViewHandler: NSObject {
    func initializeWebView(showWebView: Bool) async
    func load(url: URL) async throws
    func takeSnaphost(path: String, fileName: String) async throws
    func saveHTML(path: String, fileName: String) async throws
    func waitForWebViewLoad(timeoutInSeconds: Int) async throws
    func finish() async
    func execute(action: Action, data: CCFRequestData) async
    func evaluateJavaScript(_ javaScript: String) async throws
}

@MainActor
final class DataBrokerProtectionWebViewHandler: NSObject, WebViewHandler {
    private var activeContinuation: CheckedContinuation<Void, Error>?

    private let isFakeBroker: Bool
    private let webViewConfiguration: WKWebViewConfiguration
    private var userContentController: DataBrokerUserContentController?

    private var webView: WebView?
    private var window: NSWindow?

    init(privacyConfig: PrivacyConfigurationManaging, prefs: ContentScopeProperties, delegate: CCFCommunicationDelegate, isFakeBroker: Bool = false) {
        let configuration = WKWebViewConfiguration()
        configuration.applyDataBrokerConfiguration(privacyConfig: privacyConfig, prefs: prefs, delegate: delegate)
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        self.webViewConfiguration = configuration
        self.isFakeBroker = isFakeBroker

        let userContentController = configuration.userContentController as? DataBrokerUserContentController
        assert(userContentController != nil)
        self.userContentController = userContentController
    }

    func initializeWebView(showWebView: Bool) async {
        webView = WebView(frame: CGRect(origin: .zero, size: CGSize(width: 1024, height: 1024)), configuration: webViewConfiguration)
        webView?.navigationDelegate = self

        if showWebView {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1024, height: 1024), styleMask: [.titled],
                backing: .buffered, defer: false
            )
            window?.title = "Data Broker Protection"
            window?.contentView = self.webView
            window?.makeKeyAndOrderFront(nil)
        }

        try? await load(url: URL(string: "\(WebViewSchemeHandler.dataBrokerProtectionScheme)://blank")!)
    }

    func load(url: URL) async throws {
        webView?.load(url)
        os_log("Loading URL: %@", log: .action, String(describing: url.absoluteString))
        try await waitForWebViewLoad(timeoutInSeconds: 120)
    }

    func finish() {
        os_log("WebViewHandler finished", log: .action)

        webView?.stopLoading()
        userContentController?.cleanUpBeforeClosing()

        userContentController = nil
        webView?.navigationDelegate = nil
        webView = nil
    }

    deinit {
        print("WebViewHandler Deinit")
    }

    func waitForWebViewLoad(timeoutInSeconds: Int = 0) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.activeContinuation = continuation

            if timeoutInSeconds > 0 {
                Task {
                    try await Task.sleep(nanoseconds: UInt64(timeoutInSeconds) * NSEC_PER_SEC)
                    if self.activeContinuation != nil {
                        self.activeContinuation?.resume()
                        self.activeContinuation = nil
                    }
                }
            }
        }
    }

    func execute(action: Action, data: CCFRequestData) {
        os_log("Executing action: %{public}@", log: .action, String(describing: action.actionType.rawValue))

        userContentController?.dataBrokerUserScripts?.dataBrokerFeature.pushAction(
            method: .onActionReceived,
            webView: self.webView!,
            params: Params(state: ActionRequest(action: action, data: data))
        )
    }

    func evaluateJavaScript(_ javaScript: String) async throws {
        _ = webView?.evaluateJavaScript(javaScript, in: nil, in: WKContentWorld.page)
    }

    func takeSnaphost(path: String, fileName: String) async throws {
        let script = "document.body.scrollHeight"

        let result = try await webView?.evaluateJavaScript(script)

        if let height = result as? CGFloat {
            webView?.frame = CGRect(origin: .zero, size: CGSize(width: 1024, height: height))
            let configuration = WKSnapshotConfiguration()
            configuration.rect = CGRect(x: 0, y: 0, width: webView?.frame.size.width ?? 0.0, height: height)
            if let image = try await webView?.takeSnapshot(configuration: configuration) {
                saveToDisk(image: image, path: path, fileName: fileName)
            }
        }
    }

    func saveHTML(path: String, fileName: String) async throws {
        let result = try await webView?.evaluateJavaScript("document.documentElement.outerHTML")
        let fileManager = FileManager.default

        if let htmlString = result as? String {
            do {
                if !fileManager.fileExists(atPath: path) {
                    try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
                }

                let fileURL = URL(fileURLWithPath: "\(path)/\(fileName)")
                try htmlString.write(to: fileURL, atomically: true, encoding: .utf8)
                print("HTML content saved to file: \(fileURL)")
            } catch {
                print("Error writing HTML content to file: \(error)")
            }
        }
    }

    private func saveToDisk(image: NSImage, path: String, fileName: String) {
        guard let tiffData = image.tiffRepresentation else {
            // Handle the case where tiff representation is not available
            return
        }

        // Create a bitmap representation from the tiff data
        guard let bitmapImageRep = NSBitmapImageRep(data: tiffData) else {
            // Handle the case where bitmap representation cannot be created
            return
        }

        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating folder: \(error)")
            }
        }

        if let pngData = bitmapImageRep.representation(using: .png, properties: [:]) {
            // Save the PNG data to a file
            do {
                let fileURL = URL(fileURLWithPath: "\(path)/\(fileName)")
                try pngData.write(to: fileURL)
            } catch {
                print("Error writing PNG: \(error)")
            }
        } else {
            print("Error png data was not respresented")
        }
    }
}

extension DataBrokerProtectionWebViewHandler: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        os_log("WebViewHandler didFinish", log: .action)

        self.activeContinuation?.resume()
        self.activeContinuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        os_log("WebViewHandler didFail: %{public}@", log: .action, String(describing: error.localizedDescription))
        self.activeContinuation?.resume(throwing: error)
        self.activeContinuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        os_log("WebViewHandler didFailProvisionalNavigation: %{public}@", log: .action, String(describing: error.localizedDescription))
        self.activeContinuation?.resume(throwing: error)
        self.activeContinuation = nil
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        guard let statusCode = (navigationResponse.response as? HTTPURLResponse)?.statusCode else {
            // if there's no http status code to act on, exit and allow navigation
            return .allow
        }

        if statusCode >= 400 {
            os_log("WebViewHandler failed with status code: %{public}@", log: .action, String(describing: statusCode))
            self.activeContinuation?.resume(throwing: DataBrokerProtectionError.httpError(code: statusCode))
            self.activeContinuation = nil
        }

        return .allow
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if !isFakeBroker {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            guard let serverTrust = challenge.protectionSpace.serverTrust else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }

            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic ||
                    challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest {

            let fakeBrokerCredentials = HTTPUtils.fetchFakeBrokerCredentials()
            let credential = URLCredential(user: fakeBrokerCredentials.username, password: fakeBrokerCredentials.password, persistence: .none)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

private class WebView: WKWebView {

    deinit {
        configuration.userContentController.removeAllUserScripts()
        os_log("DBP WebView Deinit", log: .action)
    }
}
