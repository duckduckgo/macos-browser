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

import Combine
import Common
import Navigation
import WebKit
import os.log

extension WKWebView {

    static var canMuteCameraAndMicrophoneSeparately: Bool {
        if #available(macOS 12.0, *) {
            return true
        }
        return false
    }

    enum AudioState {
        case muted(isPlayingAudio: Bool)
        case unmuted(isPlayingAudio: Bool)

        init(wkMediaMutedState: _WKMediaMutedState, isPlayingAudio: Bool) {
            self = wkMediaMutedState.contains(.audioMuted) ? .muted(isPlayingAudio: isPlayingAudio) : .unmuted(isPlayingAudio: isPlayingAudio)
        }

        var isMuted: Bool {
            if case .muted = self {
                return true
            }
            return false
        }

        mutating func toggle() {
            self = switch self {
            case let .muted(isPlayingAudio): .unmuted(isPlayingAudio: isPlayingAudio)
            case let .unmuted(isPlayingAudio): .muted(isPlayingAudio: isPlayingAudio)
            }
        }
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
        }
#if !APPSTORE
        guard self.responds(to: #selector(getter: WKWebView._mediaCaptureState)) else {
            assertionFailure("WKWebView does not respond to selector _mediaCaptureState")
            return .none
        }
        return CaptureState(permissionType: .microphone, mediaCaptureState: self._mediaCaptureState)
#endif
    }

    var cameraState: CaptureState {
        if #available(macOS 12.0, *) {
            return CaptureState(self.cameraCaptureState)
        }
#if !APPSTORE
        guard self.responds(to: #selector(getter: WKWebView._mediaCaptureState)) else {
            assertionFailure("WKWebView does not respond to selector _mediaCaptureState")
            return .none
        }
        return CaptureState(permissionType: .camera, mediaCaptureState: self._mediaCaptureState)
#endif
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

    @objc dynamic var mediaMutedState: _WKMediaMutedState {
        get {
            // swizzle the method to call `_mediaMutedState` without performSelector: usage
            guard Self.swizzleMediaMutedStateOnce else { return [] }
            return self.mediaMutedState // call the original
        }
        set {
            // swizzle the method to call `_setPageMuted:` without performSelector: usage (as there‘s a non-object argument to pass)
            guard Self.swizzleSetPageMutedOnce else { return }
            self.mediaMutedState = newValue // call the original
        }
    }

    static private let swizzleMediaMutedStateOnce: Bool = {
        guard let originalMethod = class_getInstanceMethod(WKWebView.self, Selector.mediaMutedState),
              let swizzledMethod = class_getInstanceMethod(WKWebView.self, #selector(getter: mediaMutedState)) else {
            assertionFailure("WKWebView does not respond to selector _mediaMutedState")
            return false
        }
        method_exchangeImplementations(originalMethod, swizzledMethod)
        return true
    }()

    static private let swizzleSetPageMutedOnce: Bool = {
        guard let originalMethod = class_getInstanceMethod(WKWebView.self, Selector.setPageMuted),
              let swizzledMethod = class_getInstanceMethod(WKWebView.self, #selector(setter: mediaMutedState)) else {
            assertionFailure("WKWebView does not respond to selector _setPageMuted:")
            return false
        }
        method_exchangeImplementations(originalMethod, swizzledMethod)
        return true
    }()

    /// Returns the audio state of the WKWebView.
    ///
    /// - Returns: `muted` if the web view is muted
    ///            `unmuted` if the web view is unmuted
    var audioState: AudioState {
        get {
            AudioState(wkMediaMutedState: mediaMutedState, isPlayingAudio: isPlayingAudio)
        }
        set {
            switch newValue {
            case .muted:
                self.mediaMutedState.insert(.audioMuted)
            case .unmuted:
                self.mediaMutedState.remove(.audioMuted)
            }
        }
    }

    var audioStatePublisher: AnyPublisher<AudioState, Never> {
        publisher(for: \.mediaMutedState)
            .combineLatest(publisher(for: \.isPlayingAudio))
            .map { AudioState(wkMediaMutedState: $0, isPlayingAudio: $1) }
            .eraseToAnyPublisher()
    }

    @objc(webViewIsPlayingAudio) // named this way to avoid clashing with a real method when (in case) it becomes public
    var isPlayingAudio: Bool {
        return self.value(forKey: Selector.isPlayingAudio) as? Bool ?? false
    }

    @objc(keyPathsForValuesAffectingWebViewIsPlayingAudio)
    static func keyPathsForValuesAffectingIsPlayingAudio() -> Set<String> {
        return [NSStringFromSelector(Selector.mediaMutedState), Selector.isPlayingAudio]
    }

    func stopMediaCapture() {
#if !APPSTORE
        guard #available(macOS 12.0, *) else {
            guard self.responds(to: #selector(_stopMediaCapture)) else {
                assertionFailure("WKWebView does not respond to _stopMediaCapture")
                return
            }
            self._stopMediaCapture()
            return
        }
#endif

        setCameraCaptureState(.none)
        setMicrophoneCaptureState(.none)
    }

    func stopAllMediaPlayback() {
#if !APPSTORE
        guard #available(macOS 12.0, *) else {
            guard self.responds(to: #selector(_stopAllMediaPlayback)) else {
                assertionFailure("WKWebView does not respond to _stopAllMediaPlayback")
                return
            }
            self._stopAllMediaPlayback()
            return
        }
#endif
        pauseAllMediaPlayback()
    }

    func setPermissions(_ permissions: [PermissionType], muted: Bool) {
        for permission in permissions {
            switch permission {
            case .camera:
                guard #available(macOS 12.0, *) else {
                    if muted {
                        self.mediaMutedState.insert(.captureDevicesMuted)
                    } else {
                        self.mediaMutedState.remove(.captureDevicesMuted)
                    }
                    return
                }

                self.setCameraCaptureState(muted ? .muted : .active, completionHandler: {})

            case .microphone:
                guard #available(macOS 12.0, *) else {
                    if muted {
                        self.mediaMutedState.insert(.captureDevicesMuted)
                    } else {
                        self.mediaMutedState.remove(.captureDevicesMuted)
                    }
                    return
                }

                self.setMicrophoneCaptureState(muted ? .muted : .active, completionHandler: {})
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

    func close() {
        self.evaluateJavaScript("window.close()")
    }

    func loadInNewWindow(_ url: URL) {
        let urlEnc = "'\(url.absoluteString.escapedJavaScriptString())'"
        self.evaluateJavaScript("window.open(\(urlEnc), '_blank', 'noopener, noreferrer')")
    }

    func loadAlternateHTML(_ html: String, baseURL: URL, forUnreachableURL failingURL: URL) {
        guard responds(to: Selector.loadAlternateHTMLString) else {
            if #available(macOS 12.0, *) {
                Logger.navigation.error("WKWebView._loadAlternateHTMLString not available")
                loadSimulatedRequest(URLRequest(url: failingURL), responseHTML: html)
            }
            return
        }
        self.perform(Selector.loadAlternateHTMLString, withArguments: [html, baseURL, failingURL])
    }

    func setDocumentHtml(_ html: String) {
        self.evaluateJavaScript("document.open(); document.write('\(html.escapedJavaScriptString())'); document.close()", in: nil, in: .defaultClient)
    }

    @MainActor
    var mimeType: String? {
        get async {
            try? await self.evaluateJavaScript("document.contentType")
        }
    }

    var canPrint: Bool {
        !self.isInFullScreenMode
    }

    func printOperation(with printInfo: NSPrintInfo = .shared, for frame: FrameHandle?) -> NSPrintOperation? {
        if let frame = frame, responds(to: Selector.printOperationWithPrintInfoForFrame) {
            return self.perform(Selector.printOperationWithPrintInfoForFrame, with: printInfo, with: frame)?.takeUnretainedValue() as? NSPrintOperation
        }

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

    func hudView(at point: NSPoint? = nil) -> WKPDFHUDViewWrapper? {
        WKPDFHUDViewWrapper.getPdfHudView(in: self, at: point)
    }

    func savePDF(_ pdfHUD: WKPDFHUDViewWrapper? = nil) -> Bool {
        guard let hudView = pdfHUD ?? hudView() else { return false }
        hudView.savePDF()
        return true
    }

    var fullScreenPlaceholderView: NSView? {
        guard self.responds(to: Selector.fullScreenPlaceholderView) else { return nil }
        return self.value(forKey: NSStringFromSelector(Selector.fullScreenPlaceholderView)) as? NSView
    }

    func removeFocusFromWebView() {
        guard self.window?.firstResponder === self else { return }
        self.superview?.makeMeFirstResponder()
    }

    /// Collapses page text selection to the start of the first range in the selection.
    @MainActor
    func collapsSelectionToStart() async throws {
        try await evaluateJavaScript("window.getSelection().collapseToStart()") as Void?
    }

    @MainActor
    func deselectAll() async throws {
        try await evaluateJavaScript("window.getSelection().removeAllRanges()") as Void?
    }

    var addsVisitedLinks: Bool {
        get {
            guard self.responds(to: Selector.addsVisitedLinks) else {
                assertionFailure("WKWebView doesn‘t respond to _addsVisitedLinks")
                return false
            }
            return self.value(forKey: NSStringFromSelector(Selector.addsVisitedLinks)) as? Bool ?? false
        }
        set {
            guard self.responds(to: Selector.addsVisitedLinks) else {
                assertionFailure("WKWebView doesn‘t respond to _setAddsVisitedLinks:")
                return
            }
            self.perform(Selector.setAddsVisitedLinks, with: newValue ? true : nil)
        }
    }

    enum Selector {
        static let fullScreenPlaceholderView = NSSelectorFromString("_fullScreenPlaceholderView")
        static let printOperationWithPrintInfoForFrame = NSSelectorFromString("_printOperationWithPrintInfo:forFrame:")
        static let loadAlternateHTMLString = NSSelectorFromString("_loadAlternateHTMLString:baseURL:forUnreachableURL:")
        static let mediaMutedState = NSSelectorFromString("_mediaMutedState")
        static let setPageMuted = NSSelectorFromString("_setPageMuted:")
        static let setAddsVisitedLinks = NSSelectorFromString("_setAddsVisitedLinks:")
        static let addsVisitedLinks = NSSelectorFromString("_addsVisitedLinks")
        static let isPlayingAudio = "_isPlayingAudio"
    }

    // prevent exception if private API keys go missing
    open override func value(forUndefinedKey key: String) -> Any? {
        if key == #keyPath(serverTrust) {
            return self.serverTrust
        }
        assertionFailure("valueForUndefinedKey: \(key)")
        return nil
    }

}
