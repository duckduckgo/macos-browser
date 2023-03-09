//
//  WebViewMock.swift
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

import Foundation
import WebKit
@testable import DuckDuckGo_Privacy_Browser

@objc protocol WebViewPermissionsDelegate: WKUIDelegate {
    @objc(_webView:checkUserMediaPermissionForURL:mainFrameURL:frameIdentifier:decisionHandler:)
    func webView(_ webView: WKWebView,
                 checkUserMediaPermissionFor url: URL,
                 mainFrameURL: URL,
                 frameIdentifier frame: UInt,
                 decisionHandler: @escaping (String, Bool) -> Void)

    @objc(webView:requestMediaCapturePermissionForOrigin:initiatedByFrame:type:decisionHandler:)
    @available(macOS 12.0, *)
    optional func webView(_ webView: WKWebView,
                          requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                          initiatedByFrame frame: WKFrameInfo,
                          type: WKMediaCaptureType,
                          decisionHandler: @escaping (WKPermissionDecision) -> Void)

    @objc(_webView:requestUserMediaAuthorizationForDevices:url:mainFrameURL:decisionHandler:)
    func webView(_ webView: WKWebView,
                 requestUserMediaAuthorizationFor devices: _WKCaptureDevices,
                 url: URL,
                 mainFrameURL: URL,
                 decisionHandler: @escaping (Bool) -> Void)

    @objc(_webView:mediaCaptureStateDidChange:)
    func webView(_ webView: WKWebView, mediaCaptureStateDidChange state: _WKMediaCaptureStateDeprecated)

    @objc(_webView:requestGeolocationPermissionForFrame:decisionHandler:)
    func webView(_ webView: WKWebView, requestGeolocationPermissionFor frame: WKFrameInfo, decisionHandler: @escaping (Bool) -> Void)

    @objc(_webView:requestGeolocationPermissionForOrigin:initiatedByFrame:decisionHandler:)
    @available(macOS 12, *)
    func webView(_ webView: WKWebView,
                 requestGeolocationPermissionFor origin: WKSecurityOrigin,
                 initiatedBy frame: WKFrameInfo,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void)

}

final class WebViewMock: WKWebView {

    var urlValue: URL?
    override var url: URL? {
        urlValue
    }

    private var microphoneStateValue: Int = 0
    @available(macOS 12.0, *)
    override var microphoneCaptureState: WKMediaCaptureState {
        get {
            WKMediaCaptureState(rawValue: microphoneStateValue)!
        }
        set {
            willChangeValue(for: \.microphoneCaptureState)
            microphoneStateValue = newValue.rawValue
            didChangeValue(for: \.microphoneCaptureState)
        }
    }

    private var cameraStateValue: Int = 0
    @available(macOS 12.0, *)
    override var cameraCaptureState: WKMediaCaptureState {
        get {
            WKMediaCaptureState(rawValue: cameraStateValue)!
        }
        set {
            willChangeValue(for: \.cameraCaptureState)
            cameraStateValue = newValue.rawValue
            didChangeValue(for: \.cameraCaptureState)
        }
    }

    var mediaCaptureState: _WKMediaCaptureStateDeprecated = [] {
        didSet {
            (self.uiDelegate as? WebViewPermissionsDelegate)!
                .webView(self, mediaCaptureStateDidChange: mediaCaptureState)
        }
    }
    override var _mediaCaptureState: _WKMediaCaptureStateDeprecated {
        mediaCaptureState
    }

    var stopMediaCaptureHandler: (() -> Void)?
    override func _stopMediaCapture() {
        mediaCaptureState = []
        stopMediaCaptureHandler?()
    }

    var mediaMutedStateValue = _WKMediaMutedState()
    override func _mediaMutedState() -> _WKMediaMutedState {
        mediaMutedStateValue
    }

    var setPageMutedHandler: ((_WKMediaMutedState) -> Void)?
    override func _setPageMuted(_ mutedState: _WKMediaMutedState) {
        mediaMutedStateValue = mutedState
        setPageMutedHandler?(mutedState)
    }

    var setCameraCaptureStateHandler: ((Bool?) -> Void)?
    @available(macOS 12.0, *)
    override func setCameraCaptureState(_ state: WKMediaCaptureState, completionHandler: (() -> Void)?) {
        cameraCaptureState = state
        switch state {
        case .none: setCameraCaptureStateHandler?(.none)
        case .active: setCameraCaptureStateHandler?(true)
        case .muted: setCameraCaptureStateHandler?(false)
        @unknown default: fatalError()
        }
    }

    var setMicCaptureStateHandler: ((Bool?) -> Void)?
    @available(macOS 12.0, *)
    override func setMicrophoneCaptureState(_ state: WKMediaCaptureState, completionHandler: (() -> Void)?) {
        microphoneCaptureState = state
        switch state {
        case .none: setMicCaptureStateHandler?(.none)
        case .active: setMicCaptureStateHandler?(true)
        case .muted: setMicCaptureStateHandler?(false)
        @unknown default: fatalError()
        }
    }

}

@objc final class WKSecurityOriginMock: WKSecurityOrigin {
    var _protocol: String!
    override var `protocol`: String { _protocol }
    var _host: String!
    override var host: String { _host }
    var _port: Int!
    override var port: Int { _port }

    internal func setURL(_ url: URL) {
        self._protocol = url.scheme!
        self._host = url.host!
        self._port = url.port ?? url.navigationalScheme?.defaultPort ?? 0
    }

    class func new(url: URL) -> WKSecurityOriginMock {
        let mock = (self.perform(NSSelectorFromString("alloc")).takeUnretainedValue() as? WKSecurityOriginMock)!
        mock.setURL(url)
        return mock
    }

}

final class WKFrameInfoMock: WKFrameInfo {
    var _isMainFrame: Bool!
    override var isMainFrame: Bool { _isMainFrame }
    var _request: URLRequest!
    override var request: URLRequest { _request }
    var _securityOrigin: WKSecurityOrigin!
    override var securityOrigin: WKSecurityOrigin { _securityOrigin }
    weak var _webView: WKWebView?
    override var webView: WKWebView? { _webView }

    init(webView: WKWebView, securityOrigin: WKSecurityOrigin, request: URLRequest, isMainFrame: Bool) {
        self._webView = webView
        self._securityOrigin = securityOrigin
        self._request = request
        self._isMainFrame = isMainFrame
    }

}
