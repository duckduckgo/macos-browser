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

    // MARK: Permissions

    static var canMuteCameraAndMicrophoneSeparately: Bool {
        if #available(macOS 12.0, *) {
            return true
        }
        return false
    }

    enum CaptureState {
        case none
        case active
        case muted

        @available(macOS 12.0, *)
        init(_ state: WKMediaCaptureState) {
            switch state {
            case .none: self = .none
            case .active: self = .active
            case .muted: self = .muted
            @unknown default: self = .none
            }
        }

        init(permissionType: PermissionType, mediaCaptureState: _WKMediaCaptureStateDeprecated) {
            switch permissionType {
            case .microphone:
                if mediaCaptureState.contains(.activeMicrophone) {
                    self = .active
                } else if mediaCaptureState.contains(.mutedMicrophone) {
                    self = .muted
                } else {
                    self = .none
                }
            case .camera:
                if mediaCaptureState.contains(.activeCamera) {
                    self = .active
                } else if mediaCaptureState.contains(.mutedCamera) {
                    self = .muted
                } else {
                    self = .none
                }
            default:
                fatalError("Not implemented")
            }
        }
    }

    var microphoneState: CaptureState {
        if #available(macOS 12.0, *) {
            return CaptureState(self.microphoneCaptureState)
        } else if self.responds(to: #selector(getter: WKWebView._mediaCaptureState)) {
            return CaptureState(permissionType: .microphone, mediaCaptureState: self._mediaCaptureState)
        }
        assertionFailure("WKWebView does not respond to selector _mediaCaptureState")
        return .none
    }

    var cameraState: CaptureState {
        if #available(macOS 12.0, *) {
            return CaptureState(self.cameraCaptureState)
        } else if self.responds(to: #selector(getter: WKWebView._mediaCaptureState)) {
            return CaptureState(permissionType: .camera, mediaCaptureState: self._mediaCaptureState)
        }
        assertionFailure("WKWebView does not respond to selector _mediaCaptureState")
        return .none
    }

    var geolocationState: CaptureState {
        guard let geolocationProvider = self.configuration.processPool.geolocationProvider,
              [.authorizedAlways, .authorized].contains(geolocationProvider.authorizationStatus),
              !geolocationProvider.isRevoked,
              geolocationProvider.isActive
        else {
            return .none
        }
        if geolocationProvider.isPaused {
            return .muted
        }
        return .active
    }

    private func setMediaCaptureMuted(_ muted: Bool) {
        guard self.responds(to: #selector(WKWebView._setPageMuted(_:))) else {
            assertionFailure("WKWebView does not respond to selector _stopMediaCapture")
            return
        }
        let mutedState: _WKMediaMutedState = {
            guard self.responds(to: #selector(WKWebView._mediaMutedState)) else { return [] }
            return self._mediaMutedState()
        }()
        var newState = mutedState
        if muted {
            newState.insert(.captureDevicesMuted)
        } else {
            newState.remove(.captureDevicesMuted)
        }
        guard newState != mutedState else { return }
        self._setPageMuted(newState)
    }

    func stopMediaCapture() {
        guard self.responds(to: #selector(_stopMediaCapture)) else {
            assertionFailure("WKWebView does not respond to _stopMediaCapture")
            return
        }
        self._stopMediaCapture()
    }
    
    func stopAllMediaPlayback() {
        guard self.responds(to: #selector(_stopAllMediaPlayback)) else {
            assertionFailure("WKWebView does not respond to _stopAllMediaPlayback")
            return
        }
        self._stopAllMediaPlayback()
    }
    
    func setPermissions(_ permissions: [PermissionType], muted: Bool) {
        for permission in permissions {
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
            case .geolocation:
                self.configuration.processPool.geolocationProvider?.isPaused = muted
            case .popups, .externalScheme:
                assertionFailure("The permission don't support pausing")
            }
        }
    }

    func revokePermissions(_ permissions: [PermissionType], completionHandler: (() -> Void)? = nil) {
        for permission in permissions {
            switch permission {
            case .camera:
                if #available(macOS 12.0, *) {
                    self.setCameraCaptureState(.none, completionHandler: {})
                } else {
                    self.stopMediaCapture()
                }
            case .microphone:
                if #available(macOS 12.0, *) {
                    self.setMicrophoneCaptureState(.none, completionHandler: {})
                } else {
                    self.stopMediaCapture()
                }
            case .geolocation:
                self.configuration.processPool.geolocationProvider?.revoke()
            case .popups, .externalScheme:
                continue
            }
        }
    }

    // MARK: - Helper methods

    func load(_ url: URL) {

        // Occasionally, the web view will try to load a URL but will find itself with no cookies, even if they've been restored.
        // The consumeCookies call is finishing before this line executes, but if you're fast enough it can happen that WKWebView still hasn't
        // processed the cookies that have been set. Pushing the load to the next iteration of the run loops seems to fix this most of the time.
        DispatchQueue.main.async {
            let request = URLRequest(url: url)
            self.load(request)
        }
    }

    // https://developer.mozilla.org/en-US/docs/Web/API/Window/open
    @objc func load(_ url: URL, inTargetNamed target: String?, windowFeatures: String? = nil) {
        let urlEnc = "'\(url.absoluteString.escapedJavaScriptString())'"
        let targetEnc = target.map { ", '\($0.escapedJavaScriptString())'" } ?? ""
        assert(windowFeatures?.contains("'") != true)
        let windowFeaturesEnc = windowFeatures.map { ", '\($0)'" } ?? ""
        self.evaluateJavaScript("window.open(\(urlEnc)\(targetEnc)\(windowFeaturesEnc))")
    }

    @objc func load(_ url: URL, in frame: WKFrameInfo) {
        if #available(macOS 11.0, *), !frame.isMainFrame {
            self.evaluateJavaScript("location.href = '\(url.absoluteString.escapedJavaScriptString())'", in: frame, in: .defaultClient)
        } else {
            self.load(URLRequest(url: url))
        }
    }

    func replaceLocation(with url: URL, in frame: WKFrameInfo? = nil) {
        if #available(macOS 11.0, *) {
            self.evaluateJavaScript("location.replace('\(url.absoluteString.escapedJavaScriptString())')", in: frame, in: .defaultClient)
        } else {
            self.evaluateJavaScript("location.replace('\(url.absoluteString.escapedJavaScriptString())')")
        }
    }

    func getMimeType(callback: @escaping (String?) -> Void) {
        self.evaluateJavaScript("document.contentType") { (result, _) in
            callback(result as? String)
        }
    }

    func close() {
        self.evaluateJavaScript("window.close()")
    }

    // MARK: - Printing

    static var canPrint: Bool {
        if #available(macOS 11.0, *) {
            return true
        } else {
            return self.instancesRespond(to: #selector(WKWebView._printOperation(with:)))
        }
    }
    
    func printOperation(with printInfo: NSPrintInfo = .shared, for frame: Any?) -> NSPrintOperation? {
        if let frame = frame,
           self.responds(to: #selector(WKWebView._printOperation(with:forFrame:))) {
            return self._printOperation(with: printInfo, forFrame: frame)
        }

        if #available(macOS 11.0, *) {
            let printInfoDictionary = (NSPrintInfo.shared.dictionary() as? [NSPrintInfo.AttributeKey: Any]) ?? [:]
            let printInfo = NSPrintInfo(dictionary: printInfoDictionary)

            printInfo.horizontalPagination = .automatic
            printInfo.verticalPagination = .automatic
            printInfo.leftMargin = 0
            printInfo.rightMargin = 0
            printInfo.topMargin = 0
            printInfo.bottomMargin = 0
            printInfo.scalingFactor = 0.95
            
            return self.printOperation(with: printInfo)
        }

        guard self.responds(to: #selector(WKWebView._printOperation(with:))) else { return nil }

        return self._printOperation(with: printInfo)
    }

    // MARK: - Zoom

    static private let maxZoomLevel: CGFloat = 3.0
    static private let minZoomLevel: CGFloat = 0.5
    static private let zoomLevelStep: CGFloat = 0.1

    var zoomLevel: CGFloat {
        get {
            if #available(macOS 11.0, *) {
                return pageZoom
            }
            return magnification
        }
        set {
            if #available(macOS 11.0, *) {
                pageZoom = newValue
            } else {
                magnification = newValue
            }
        }
    }

    var canZoomToActualSize: Bool {
        self.window != nil && self.zoomLevel != 1.0
    }

    var canZoomIn: Bool {
        self.window != nil && self.zoomLevel < Self.maxZoomLevel
    }

    var canZoomOut: Bool {
        self.window != nil && self.zoomLevel > Self.minZoomLevel
    }

    func zoomIn() {
        guard canZoomIn else { return }
        self.zoomLevel = min(self.zoomLevel + Self.zoomLevelStep, Self.maxZoomLevel)
    }

    func zoomOut() {
        guard canZoomOut else { return }
        self.zoomLevel = max(self.zoomLevel - Self.zoomLevelStep, Self.minZoomLevel)
    }

    // MARK: - Developer Tools

    @nonobjc var mainFrame: AnyObject? {
        guard self.responds(to: NSSelectorFromString("_mainFrame")) else {
            assertionFailure("WKWebView does not respond to _mainFrame")
            return nil
        }
        return self.perform(NSSelectorFromString("_mainFrame"))?.takeUnretainedValue()
    }

    @discardableResult
    private func inspectorPerform(_ selectorName: String, with object: Any? = nil) -> Unmanaged<AnyObject>? {
        guard self.responds(to: NSSelectorFromString("_inspector")),
              let inspector = self.value(forKey: "_inspector") as? NSObject,
              inspector.responds(to: NSSelectorFromString(selectorName)) else {
            assertionFailure("_WKInspector does not respond to \(selectorName)")
            return nil
        }
        return inspector.perform(NSSelectorFromString(selectorName), with: object)
    }

    var isInspectorShown: Bool {
        return inspectorPerform("isVisible") != nil
    }

    @nonobjc func openDeveloperTools() {
        inspectorPerform("show")
    }

    @nonobjc func closeDeveloperTools() {
        inspectorPerform("close")
    }

    @nonobjc func openJavaScriptConsole() {
        inspectorPerform("showConsole")
    }

    @nonobjc func showPageSource() {
        guard let mainFrameHandle = self.mainFrame else { return }
        inspectorPerform("showMainResourceForFrame:", with: mainFrameHandle)
    }

    @nonobjc func showPageResources() {
        inspectorPerform("showResources")
    }

    // MARK: - Fullscreen

    var fullScreenPlaceholderView: NSView? {
        guard self.responds(to: #selector(WKWebView._fullScreenPlaceholderView)) else { return nil }
        return self._fullScreenPlaceholderView()
    }

    /// actual view to be displayed as a Tab content
    /// may be the WebView itself or FullScreen Placeholder view
    var tabContentView: NSView {
        return fullScreenPlaceholderView ?? self
    }

    var fullscreenWindowController: NSWindowController? {
        guard let fullscreenWindowController = self.window?.windowController,
              fullscreenWindowController.className.contains("FullScreen")
        else {
            return nil
        }
        return fullscreenWindowController
    }

}
