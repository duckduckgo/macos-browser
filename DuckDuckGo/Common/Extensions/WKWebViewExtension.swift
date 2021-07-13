//
//  WKWebViewExtension.swift
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

    var permissions: Permissions {
        var permissions = Permissions()
        if self.responds(to: #selector(getter: WKWebView._mediaCaptureState)) {
            permissions = Permissions(mediaCaptureState: self._mediaCaptureState)
        } else if #available(macOS 12.0, *) {
            #warning("Sound state")
            permissions = Permissions(microphoneCaptureState: self.microphoneCaptureState,
                                      cameraCaptureState: self.cameraCaptureState,
                                      soundState: .none)
        }
        if let geolocationProvider = self.configuration.processPool.geolocationProvider {
            permissions.geolocation = PermissionState(isActive: geolocationProvider.isActive,
                                                      isPaused: geolocationProvider.isDisabled)
        }
        return permissions
    }

    private func setMediaCaptureMuted(_ muted: Bool) {
        guard self.responds(to: #selector(WKWebView._setPageMuted(_:))) else {
            assertionFailure("WKWebView does not respond to selector _stopMediaCapture")
            return
        }
        var mutedState: _WKMediaMutedState = {
            guard self.responds(to: #selector(WKWebView._mediaMutedState)) else { return [] }
            return self._mediaMutedState()
        }()
        if muted {
            mutedState.insert(.captureDevicesMuted)
        } else {
            mutedState.remove(.captureDevicesMuted)
        }
        self._setPageMuted(mutedState)
    }

    var canMuteCameraAndMicrophoneSeparately: Bool {
        if #available(macOS 12.0, *) {
            return true
        }
        return false
    }

    func setPermission(_ permission: PermissionType, muted: Bool) {
        switch permission {
        case .camera:
            if #available(macOS 12.0, *) {
                self.setCameraCaptureState(muted ? .muted : .active, completionHandler: {})
            } else {
                self.setMediaCaptureMuted(muted)
            }
        case .microphone:
            if #available(macOS 12.0, *) {
                self.setMicrophoneCaptureState(muted ? .muted : .active, completionHandler: {})
            } else {
                self.setMediaCaptureMuted(muted)
            }
        case .cameraAndMicrophone:
            if #available(macOS 12.0, *) {
                self.setCameraCaptureState(muted ? .muted : .active, completionHandler: {})
                self.setMicrophoneCaptureState(muted ? .muted : .active, completionHandler: {})
            } else {
                self.setMediaCaptureMuted(muted)
            }
        case .geolocation:
            self.configuration.processPool.geolocationProvider?.isDisabled = muted
        case .sound:
            break
        }
    }

    func revokePermission(_ permission: PermissionType) {
        switch permission {
        case .camera:
            if #available(macOS 12.0, *) {
                self.setCameraCaptureState(.none, completionHandler: {})
            } else if self.responds(to: #selector(_stopMediaCapture)) {
                self._stopMediaCapture()
            } else {
                assertionFailure("WKWebView does not respond to _stopMediaCapture")
            }
        case .microphone:
            if #available(macOS 12.0, *) {
                self.setMicrophoneCaptureState(.none, completionHandler: {})
            } else if self.responds(to: #selector(_stopMediaCapture)) {
                self._stopMediaCapture()
            } else {
                assertionFailure("WKWebView does not respond to _stopMediaCapture")
            }
        case .cameraAndMicrophone:
            if #available(macOS 12.0, *) {
                self.setCameraCaptureState(.none, completionHandler: {})
                self.setMicrophoneCaptureState(.none, completionHandler: {})
            } else if self.responds(to: #selector(_stopMediaCapture)) {
                self._stopMediaCapture()
            } else {
                assertionFailure("WKWebView does not respond to _stopMediaCapture")
            }
        case .geolocation:
            self.configuration.processPool.geolocationProvider?.isDisabled = true
        case .sound:
            break
        }
    }

    func load(_ url: URL) {

        // Occasionally, the web view will try to load a URL but will find itself with no cookies, even if they've been restored.
        // The consumeCookies call is finishing before this line executes, but if you're fast enough it can happen that WKWebView still hasn't
        // processed the cookies that have been set. Pushing the load to the next iteration of the run loops seems to fix this most of the time.
        DispatchQueue.main.async {
            let request = URLRequest(url: url)
            self.load(request)
        }
    }

    func getMimeType(callback: @escaping (String?) -> Void) {
        self.evaluateJavaScript("document.contentType") { (result, _) in
            callback(result as? String)
        }
    }

}
