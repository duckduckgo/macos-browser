//
//  NavigationResponder.swift
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

enum AuthChallengeDisposition {
    /// Use the specified credential
    case useCredential(URLCredential?)
    /// The entire request will be canceled
    case cancelAuthenticationChallenge
    /// This challenge is rejected and the next authentication protection space should be tried
    case rejectProtectionSpace

    var dispositionAndCredential: (URLSession.AuthChallengeDisposition, URLCredential?) {
        switch self {
        case .useCredential(let credential):
            return (.useCredential, credential)
        case .cancelAuthenticationChallenge:
            return (.cancelAuthenticationChallenge, nil)
        case .rejectProtectionSpace:
            return (.rejectProtectionSpace, nil)
        }
    }
}
extension AuthChallengeDisposition? {
    /// Pass challenge to next responder
    static let next = AuthChallengeDisposition?.none
}

struct SecurityOrigin: Equatable {
    let `protocol`: String
    let host: String
    let port: Int

    init(`protocol`: String, host: String, port: Int) {
        self.`protocol` = `protocol`
        self.host = host
        self.port = port
    }

    init(_ securityOrigin: WKSecurityOrigin) {
        self.init(protocol: securityOrigin.protocol, host: securityOrigin.host, port: securityOrigin.port)
    }

    static let empty = SecurityOrigin(protocol: "", host: "", port: 0)
}

struct NavigationPreferences {
    var userAgent: String?
    var contentMode: WKWebpagePreferences.ContentMode
    private var _javaScriptEnabled: Bool
    @available(macOS 11.0, *)
    var javaScriptEnabled: Bool {
        get {
            _javaScriptEnabled
        }
        set {
            _javaScriptEnabled = newValue
        }
    }

    init(userAgent: String?, preferences: WKWebpagePreferences) {
        self.contentMode = preferences.preferredContentMode
        if #available(macOS 11.0, *) {
            self._javaScriptEnabled = preferences.allowsContentJavaScript
        } else {
            self._javaScriptEnabled = true
        }
    }

    func export(to preferences: WKWebpagePreferences) {
        preferences.preferredContentMode = contentMode
        if #available(macOS 11.0, *) {
            preferences.allowsContentJavaScript = javaScriptEnabled
        }
    }
}

extension WKFrameInfo {
#if DEBUG
    var handle: String {
        String(describing: (self.value(forKey: "_handle") as? NSObject)!.value(forKey: "frameID")!)
    }
#else
    var handle: String? { nil }
#endif
}

struct FrameInfo: Equatable {
    private let frameInfo: WKFrameInfo?
    let isMainFrame: Bool

    let request: URLRequest?
    let securityOrigin: SecurityOrigin

    static let main = FrameInfo(frameInfo: nil, isMainFrame: true, request: nil, securityOrigin: .empty)

    init(frameInfo: WKFrameInfo?, isMainFrame: Bool, request: URLRequest?, securityOrigin: SecurityOrigin) {
        self.frameInfo = frameInfo
        self.isMainFrame = isMainFrame
        self.request = request
        self.securityOrigin = securityOrigin
    }

    init(_ frameInfo: WKFrameInfo) {
        self.init(frameInfo: frameInfo, isMainFrame: frameInfo.isMainFrame, request: frameInfo.request, securityOrigin: .init(frameInfo.securityOrigin))
    }

    var url: URL? {
        request?.url
    }

}
extension FrameInfo: CustomDebugStringConvertible {
    var debugDescription: String {
        "<Frame #\(frameInfo.map { String(describing: $0.handle) } ?? "??")\(isMainFrame ? ": Main" : "")>"
    }
}

enum RedirectType: String, Equatable {
    case developer
    case client
    case server
}
extension RedirectType: CustomStringConvertible {
    var description: String { self.rawValue }
}

indirect enum NavigationType: Equatable {
    case linkActivated
    case formSubmitted
    case backForward
    case reload
    case formResubmitted

    case userEntered
    case redirect(type: RedirectType, navigation: Navigation?)
    case sessionRestoration

    case other

    init(_ navigationType: WKNavigationType) {
        switch navigationType {
        case .linkActivated:
            self = .linkActivated
        case .formSubmitted:
            self = .formSubmitted
        case .backForward:
            self = .backForward
        case .reload:
            self = .reload
        case .formResubmitted:
            self = .formResubmitted
        case .other:
            self = .other
        @unknown default:
            self = .other
        }
    }
}
extension NavigationType: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .linkActivated: return "linkActivated"
        case .formSubmitted: return "formSubmitted"
        case .backForward: return "backForward"
        case .reload: return "reload"
        case .formResubmitted: return "formResubmitted"
        case .userEntered: return "userEntered"
        case .sessionRestoration: return "sessionRestoration"
        case .other: return "other"
        case .redirect(type: let redirectType, navigation: let navigation):
            return "redirect(\(redirectType), navigation: \(navigation?.debugDescription ?? "<nil>")"
        }
    }
}

struct NavigationAction {
#if DEBUG
    private static var maxIdentifier: UInt64 = 0
    private let identifier: UInt64 = {
        Self.maxIdentifier += 1
        return Self.maxIdentifier
    }()
#else
    private var identifier: UInt64? { nil }
#endif

    let navigationType: NavigationType
    let request: URLRequest

    let sourceFrame: FrameInfo
    let targetFrame: FrameInfo

    let shouldDownload: Bool
    let isUserInitiated: Bool
    let isMiddleClick: Bool

    var isForMainFrame: Bool {
        targetFrame.isMainFrame
    }

    var url: URL {
        request.url!
    }

    init(navigationType: NavigationType, request: URLRequest, sourceFrame: FrameInfo, targetFrame: FrameInfo, shouldDownload: Bool, isUserInitiated: Bool, isMiddleClick: Bool) {
        self.navigationType = navigationType
        self.request = request
        self.sourceFrame = sourceFrame
        self.targetFrame = targetFrame
        self.shouldDownload = shouldDownload
        self.isUserInitiated = isUserInitiated
        self.isMiddleClick = isMiddleClick
    }

    init(_ navigationAction: WKNavigationAction, navigationType: NavigationType? = nil) {
        // In this cruel reality the source frame IS Nullable for initial load events
        let sourceFrame = (navigationAction.safeSourceFrame ?? navigationAction.targetFrame).map(FrameInfo.init) ?? .main
        let shouldDownload: Bool
        if #available(macOS 11.3, *) {
            shouldDownload = navigationAction.shouldPerformDownload
        } else {
            shouldDownload = navigationAction._shouldPerformDownload
        }
        // TODO: private API
        let userInitiated = navigationAction.isUserInitiated
        self.init(navigationType: navigationType ?? NavigationType(navigationAction.navigationType),
                  request: navigationAction.request,
                  sourceFrame: sourceFrame,
                  // always has targetFrame if not targeting to a new window
                  targetFrame: navigationAction.targetFrame.map(FrameInfo.init) ?? sourceFrame,
                  shouldDownload: shouldDownload,
                  isUserInitiated: navigationAction.isUserInitiated,
                  isMiddleClick: navigationAction.buttonNumber == 4)
    }

    static func sessionRestoreNavigation(url: URL) -> Self {
        self.init(navigationType: .sessionRestoration, request: URLRequest(url: url), sourceFrame: .main, targetFrame: .main, shouldDownload: false, isUserInitiated: false, isMiddleClick: false)
    }

}

extension NavigationAction: CustomDebugStringConvertible {
    var debugDescription: String {
        "<NavigationAction #\(identifier): url: \"\(url.absoluteString)\" type: \(navigationType.debugDescription)\(isUserInitiated ? " UserInitiated" : "")\(isMiddleClick ? " MiddleClick" : "")\(shouldDownload ? " Download" : "") frame: \(sourceFrame != targetFrame ? sourceFrame.debugDescription + " -> " : "")\(targetFrame.debugDescription)>"
    }
}

enum NavigationActionPolicy {
    case allow
    case cancel
    case download
    case redirect(request: URLRequest)

    case retarget(in: NewWindowKind)

    static func redirect(to url: URL) -> NavigationActionPolicy {
        return .redirect(request: URLRequest(url: url))
    }
}
extension NavigationActionPolicy {
    var debugDescription: String {
        return String(describing: self)
    }
}
extension NavigationActionPolicy? {
    /// Pass decision making to next responder
    static let next = NavigationActionPolicy?.none

    var debugDescription: String {
        if case .some(let policy) = self {
            return policy.debugDescription
        }
        return "next"
    }
}

struct NavigationResponse {
    let navigationResponse: WKNavigationResponse
    let navigation: Navigation?

    init(navigationResponse: WKNavigationResponse, navigation: Navigation?) {
        self.navigationResponse = navigationResponse
        self.navigation = navigation
    }

    var url: URL {
        navigationResponse.response.url!
    }

    var isForMainFrame: Bool {
        navigationResponse.isForMainFrame
    }

    var response: URLResponse {
        navigationResponse.response
    }

    var canShowMIMEType: Bool {
        navigationResponse.canShowMIMEType
    }

    var shouldDownload: Bool {
        let contentDisposition = (response as? HTTPURLResponse)?.allHeaderFields["Content-Disposition"] as? String
        return contentDisposition?.hasPrefix("attachment") ?? false
    }

}

extension NavigationResponse: CustomDebugStringConvertible {
    var debugDescription: String {
        let statusCode = { (self.navigationResponse.response as? HTTPURLResponse)?.statusCode }().map(String.init) ?? "??"
        return "<NavigationResponse: \(statusCode):\(shouldDownload ? " Download" : "") \"\(navigation?.debugDescription ?? "<nil>")\">"
    }
}

enum NavigationResponsePolicy {
    case allow
    case cancel
    case download
}

extension NavigationResponsePolicy? {
    /// Pass decision making to next responder
    static let next = NavigationResponsePolicy?.none
}

enum NavigationState: Equatable {
    case started
    case awaitingFinishOrClientRedirect
    case finished
    case failed(WKError)
    case awaitingRedirect(type: RedirectType, url: URL?)
    case redirected

    var awaitedRedirect: (type: RedirectType, url: URL?)? {
        switch self {
        case .awaitingFinishOrClientRedirect:
            return (.client, nil)
        case .awaitingRedirect(type: let redirectType, url: let url):
            return (redirectType, url)
        case .started, .finished, .failed, .redirected:
            return nil
        }
    }
}

struct Navigation: Equatable {
    fileprivate var navigation: WKNavigation
    let navigationAction: NavigationAction
    fileprivate(set) var state: NavigationState
    fileprivate(set) var isCommitted: Bool = false

    init(navigation: WKNavigation, navigationAction: NavigationAction) {
        self.navigation = navigation
        self.navigationAction = navigationAction
        self.state = .started
    }

    var request: URLRequest {
        navigationAction.request
    }
    var url: URL {
        navigationAction.url
    }

    func ifMatches(_ navigation: WKNavigation) -> Self? {
        guard navigation == self.navigation else { return nil }
        return self
    }

    static func == (lhs: Navigation, rhs: Navigation) -> Bool {
        lhs.navigation === rhs.navigation && lhs.state == rhs.state
    }
}

extension Navigation {

    mutating func committed() {
        assert(state == .started)
        self.isCommitted = true
    }

    // Shortly after receiving webView:didFinishNavigation: a client redirect navigation may start
    mutating func receivedDidFinish() {
        self.state = .awaitingFinishOrClientRedirect
    }
    // On the next RunLop pass we can finish the navigation
    mutating func finished() {
        self.state = .finished
    }

    mutating func didFail(with error: WKError) {
        self.state = .failed(error)
    }

    mutating func willRedirect(type: RedirectType, url: URL?) {
        self.state = .awaitingRedirect(type: type, url: url)
    }

    mutating func redirected() {
        self.state = .redirected
    }

}

extension Navigation: CustomDebugStringConvertible {
    var debugDescription: String {
        let navigationDescription = navigation.debugDescription.dropping(prefix: "<WK").dropping(suffix: ">")
        return "<\(navigationDescription): url: \"\(url.absoluteString)\" type: \(navigationAction.navigationType)>"
    }
}

protocol NavigationResponder {

    // MARK: - Expectation

    // Item is nil if the gesture ended without navigation.
//    @MainActor
//    func webView(_ webView: WebView, didEndNavigationGestureWithNavigationTo backForwardListItem: WKBackForwardListItem?)

    /// Called when WebView navigation is initated by `goBack`, `goForward` and `goToBackForwardListItem:` methods
    /// won‘t get called when a Page Web Process is hung, should handle using methods above and navigation gestures callback
    /// !!! called twice: before _webViewDidEndNavigationGesture: and after decidePolicyForNavigationAction:
//    @MainActor
//    func webView(_ webView: WebView, willGoTo backForwardListItem: WKBackForwardListItem, inPageCache: Bool)

    /// called when WebView navigation is initiated by `loadRequest:` method
//    @MainActor
//    func webView(_ webView: WebView, willStartNavigation navigation: WKNavigation?, with request: URLRequest)

    /// Called when WebView navigation is initated by `reload` method
//    @MainActor
//    func webView(_ webView: WebView, willStartReloadNavigation navigation: WKNavigation?)

    /// Called when WebView navigation is initated by `goBack`, `goForward` and `goToBackForwardListItem:` methods
//    @MainActor
//    func webView(_ webView: WebView, willStartUserInitiatedNavigation navigation: WKNavigation?, to backForwardListItem: WKBackForwardListItem?)

//    @MainActor
//    func webView(_ webView: WebView, willRequestNewWebViewFor url: URL, with windowKind: NewWindowKind?)

    /// called when WebView is about to restore Session State
//    @MainActor
//    func webViewWillRestoreSessionState(_ webView: WebView)

    // MARK: Decision making

    /// Decides whether to allow or cancel a navigation.
    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy?

//    @MainActor
// TODO:   func willStart(_ navigationAction: NavigationAction, redirectingTo request: URLRequest, in newWindowKind: NewWindowKind?)

//    @MainActor
// TODO:   func didCancel(_ navigationAction: NavigationAction, redirectingTo request: URLRequest)

    // MARK: Navigation

//    @MainActor
// TODO:   func navigation(_ navigation: Navigation, didRedirectTo url: URL or URLRequest?, redirectType: RedirectType)

    /// Invoked when the web view needs to respond to an authentication challenge.
    @MainActor
    func didReceive(_ authenticationChallenge: URLAuthenticationChallenge) async -> AuthChallengeDisposition?

    @MainActor
    func decidePolicy(for navigationResponse: NavigationResponse) async -> NavigationResponsePolicy?

    @MainActor
    func didStart(_ navigation: Navigation)
//    @MainActor
//    func webView(_ webView: WebView, didStartNavigationWith request: URLRequest, in frame: WKFrameInfo)

    @MainActor
    func didCommit(_ navigation: Navigation)
//    @MainActor
//    func webView(_ webView: WebView, didCommitNavigationWith request: URLRequest, in frame: WKFrameInfo)

//    @MainActor
//    func navigationDidFinishOrReceivedClientRedirect(_ navigation: Navigation)
    @MainActor
    func navigationDidFinish(_ navigation: Navigation)
//    @MainActor
//    func webView(_ webView: WebView, didFinishNavigationWith request: URLRequest, in frame: WKFrameInfo)

    @MainActor
    func navigation(_ navigation: Navigation, didFailWith error: WKError)
//    @MainActor
//    func webView(_ webView: WebView, navigationWith request: URLRequest, in frame: WKFrameInfo, didFailWith error: Error)

//    @MainActor
//    func webView(_ webView: WebView, willPerformClientRedirectTo url: URL, delay: TimeInterval)

    @MainActor
    func navigationAction(_ navigationAction: NavigationAction, didBecome download: WebKitDownload)
    @MainActor
    func navigationResponse(_ navigationResponse: NavigationResponse, didBecome download: WebKitDownload)
    @MainActor
    func contextMenuDidCreateDownload(_ download: WebKitDownload)

    @MainActor
    func webContentProcessDidTerminate(currentNavigation: Navigation?)

    //
    //
    //    /** @abstract Invoked when the web view is establishing a network connection using a deprecated version of TLS.
    //     @param webView The web view initiating the connection.
    //     @param challenge The authentication challenge.
    //     @param decisionHandler The decision handler you must invoke to respond to indicate whether or not to continue with the connection establishment.
    //     */
    //    @available(macOS 11.0, *)
    //    func webView(_ webView: WebView, authenticationChallenge challenge: URLAuthenticationChallenge, shouldAllowDeprecatedTLS decisionHandler: @escaping (Bool) -> Void)
    //
    //    /** @abstract Invoked when the web view is establishing a network connection using a deprecated version of TLS.
    //     @param webView The web view initiating the connection.
    //     @param challenge The authentication challenge.
    //     @param decisionHandler The decision handler you must invoke to respond to indicate whether or not to continue with the connection establishment.
    //     */
    //    @available(macOS 11.0, *)
    //    func webView(_ webView: WebView, shouldAllowDeprecatedTLSFor challenge: URLAuthenticationChallenge) async -> Bool
    //
    //

}

extension NavigationResponder {

//    func webView(_ webView: WebView, willGoTo backForwardListItem: WKBackForwardListItem, inPageCache: Bool) {}
//    func webView(_ webView: WebView, willStartUserInitiatedNavigation _: WKNavigation?, to _: WKBackForwardListItem?) {}
//    func webView(_ webView: WebView, willStartNavigation navigation: WKNavigation?, with request: URLRequest) {}
//    func webView(_ webView: WebView, willStartReloadNavigation navigation: WKNavigation?) {}
//    func webView(_ webView: WebView, didEndNavigationGestureWithNavigationTo _: WKBackForwardListItem?) {}
//    func webView(_ webView: WebView, willRequestNewWebViewFor url: URL, with windowKind: NewWindowKind?) {}
//    func webViewWillRestoreSessionState(_ webView: WebView) {}

    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        return .next
    }

    func didReceive(_ authenticationChallenge: URLAuthenticationChallenge) async -> AuthChallengeDisposition? {
        return .next
    }

    func decidePolicy(for navigationResponse: NavigationResponse) async -> NavigationResponsePolicy? {
        return .next
    }

    func didStart(_ navigation: Navigation) {}

    func didCommit(_ navigation: Navigation) {}

    func navigationDidFinishOrReceivedClientRedirect(_ navigation: Navigation) {}
    func navigationDidFinish(_ navigation: Navigation) {}

    func navigation(_ navigation: Navigation, didFailWith error: WKError) {}

    func navigationAction(_ navigationAction: NavigationAction, didBecome download: WebKitDownload) {}
    func navigationResponse(_ navigationResponse: NavigationResponse, didBecome download: WebKitDownload) {}
    func contextMenuDidCreateDownload(_ download: WebKitDownload) {}

    func webContentProcessDidTerminate(currentNavigation: Navigation?) {}

}
