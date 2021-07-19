//
//  PermissionModel.swift
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
import Combine
import WebKit
import AVFoundation

final class PermissionModel {

    @PublishedAfter var permissions = Permissions()
    @PublishedAfter var authorizationQuery: PermissionAuthorizationQuery?

    private var authorizationQueries = [PermissionAuthorizationQuery]() {
        didSet {
            authorizationQuery = authorizationQueries.first
        }
    }

    private let permissionManager: PermissionManagerProtocol
    private weak var webView: WKWebView?
    private var cancellables = Set<AnyCancellable>()

    private let systemLocationServicesEnabled: () -> Bool

    init(webView: WKWebView,
         permissionManager: PermissionManagerProtocol = PermissionManager.shared,
         systemLocationServicesEnabled: @escaping () -> Bool = CLLocationManager.locationServicesEnabled) {
        self.permissionManager = permissionManager
        self.webView = webView
        self.systemLocationServicesEnabled = systemLocationServicesEnabled

        self.subscribe(to: webView)
        self.subscribe(to: permissionManager)
    }

    private func subscribe(to webView: WKWebView) {
        if #available(macOS 12, *) {
            webView.publisher(for: \.cameraCaptureState).sink { [weak self] _ in
                self?.updatePermissions()
            }.store(in: &cancellables)
            webView.publisher(for: \.microphoneCaptureState).sink { [weak self] _ in
                self?.updatePermissions()
            }.store(in: &cancellables)
        } // else: will receive mediaCaptureStateDidChange()

        let geolocationProvider = webView.configuration.processPool.geolocationProvider
        geolocationProvider?.$isActive.sink { [weak self] _ in
            self?.updatePermissions()
        }.store(in: &cancellables)
        geolocationProvider?.$isPaused.sink { [weak self] _ in
            self?.updatePermissions()
        }.store(in: &cancellables)
        geolocationProvider?.$authorizationStatus.sink { [weak self] authorizationStatus in
            self?.geolocationAuthorizationStatusDidChange(to: authorizationStatus)
        }.store(in: &cancellables)
    }

    private func subscribe(to permissionManager: PermissionManagerProtocol) {
        permissionManager.permissionPublisher.sink { [weak self] value in
            self?.permission(value.permissionType, forDomain: value.domain, didChangeStoredDecisionTo: value.grant)
        }.store(in: &cancellables)
    }

    private func resetPermissions() {
        webView?.configuration.processPool.geolocationProvider?.reset()
        permissions = Permissions()
        authorizationQueries = []
        updatePermissions()
    }

    private func updatePermissions() {
        guard let webView = webView else { return }
        for permissionType in PermissionType.allCases {
            switch permissionType {
            case .microphone:
                permissions.microphone.update(with: webView.microphoneState)
            case .camera:
                permissions.camera.update(with: webView.cameraState)
            case .geolocation:
                let authorizationStatus = webView.configuration.processPool.geolocationProvider?.authorizationStatus
                if [.denied, .restricted].contains(authorizationStatus) {
                    permissions.geolocation
                        .systemMediaAuthorizationDenied(systemWide: !self.systemLocationServicesEnabled())
                } else {
                    permissions.geolocation.update(with: webView.geolocationState)
                }
            case .sound:
                permissions.sound.update(with: webView.soundState)

            case .display: continue
            }
        }
    }

    private func queryAuthorization(for permissions: [PermissionType], domain: String, decisionHandler: @escaping (Bool) -> Void) {
        let query = PermissionAuthorizationQuery(domain: domain, permissions: permissions) { [weak self] query, granted in
            defer {
                decisionHandler(granted)
            }
            guard let self = self,
                  let query = query, // otherwise handling decision on Query deallocation
                  let idx = self.authorizationQueries.firstIndex(where: { $0 === query })
            else {
                return
            }
            self.authorizationQueries.remove(at: idx)

            if !granted { // granted handled through activation of the permission usage
                permissions.forEach { self.permissions[$0].userDenied() }
            }
        }

        permissions.forEach { self.permissions[$0].authorizationQueried(query) }
        authorizationQueries.append(query)
    }

    private func permission(_ permissionType: PermissionType,
                            forDomain domain: String,
                            didChangeStoredDecisionTo decision: Bool?) {

        guard webView?.url?.host?.dropWWW() == domain,
           // Always Deny
           decision == false,
           self.permissions[permissionType] != nil
        else {
            return
        }

        self.permissions[permissionType].revoke()
        self.webView?.revokePermissions([permissionType])
    }

    // MARK: API

    func set(_ permissions: [PermissionType], muted: Bool) {
        webView?.setPermissions(permissions, muted: muted)
    }

    func set(_ permission: PermissionType, muted: Bool) {
        webView?.setPermissions([permission], muted: muted)
    }

    func revoke(_ permission: PermissionType) {
        self.permissions[permission].revoke()
        webView?.revokePermissions([permission])
    }

    // MARK: - WebView delegated methods

    // Called before requestMediaCapturePermissionFor: to validate System Permissions
    func checkUserMediaPermission(for url: URL, mainFrameURL: URL, decisionHandler: @escaping (String, Bool) -> Void) {
        // If media capture is denied in System Preferences, reflect it in current permissions
        AVCaptureDevice.swizzleAuthorizationStatusForMediaType { mediaType, authorizationStatus in
            if case .denied = authorizationStatus {
                switch mediaType {
                case .audio:
                    self.permissions.microphone.systemMediaAuthorizationDenied(systemWide: false)
                case .video:
                    self.permissions.camera.systemMediaAuthorizationDenied(systemWide: false)
                default: break
                }
            }
        }
        decisionHandler("", false)
        AVCaptureDevice.restoreAuthorizationStatusForMediaType()
    }

    func permissions(_ permissions: [PermissionType], requestedForDomain domain: String?, decisionHandler: @escaping (Bool) -> Void) {
        guard let domain = domain,
              !permissions.isEmpty
        else {
            assertionFailure("Unexpected permissions/domain")
            decisionHandler(false)
            return
        }
        var shouldGrant = true
        for permission in permissions {
            var grant: Bool?
            if let stored = permissionManager.permission(forDomain: domain, permissionType: permission) {
                grant = stored
            } else if let state = self.permissions[permission] {
                switch state {
                case .active, .inactive, .paused:
                    grant = true
                case .denied, .revoking:
                    grant = false
                case .disabled, .requested:
                    break
                }
            }

            if let grant = grant {
                if grant == false {
                    // deny if at least one permission permanently or prior denied
                    decisionHandler(false)
                    return
                }
                // else if grant == true: allow if all permissions permanently or prior allowed
            } else {
                // if at least one permission is not set: ask
                shouldGrant = false
            }
        }
        if shouldGrant {
            decisionHandler(true)
            return
        }

        queryAuthorization(for: permissions, domain: domain, decisionHandler: decisionHandler)
    }

    func mediaCaptureStateDidChange() {
        updatePermissions()
    }

    func tabDidStartNavigation() {
        resetPermissions()
    }

    func geolocationAuthorizationStatusDidChange(to authorizationStatus: CLAuthorizationStatus) {
        switch authorizationStatus {
        case .authorized, .authorizedAlways:
            self.permissions.geolocation
                .systemMediaAuthorizationGranted(pendingQuery:
                                                    self.authorizationQueries.first(where: {
                                                            $0.permissions.contains(.geolocation)
                                                    }))
            self.updatePermissions()
            
        case .denied, .restricted:
            self.permissions.geolocation
                .systemMediaAuthorizationDenied(systemWide: !self.systemLocationServicesEnabled())

        case .notDetermined: break
        @unknown default: break
        }
    }

}

extension Optional where Wrapped == PermissionState {

    mutating func authorizationQueried(_ query: PermissionAuthorizationQuery) {
        if case .disabled = self {
            // stay in disabled state if the App is disabled to use the permission
            return
        }
        self = .requested(query)
    }

    mutating func systemMediaAuthorizationDenied(systemWide: Bool) {
        guard case .some = self else { return }
        self = .disabled(systemWide: systemWide)
    }

    mutating func systemMediaAuthorizationGranted(pendingQuery: PermissionAuthorizationQuery?) {
        guard case .disabled = self,
           let query = pendingQuery else {
            return
        }
        self = .requested(query)
    }

    mutating func userDenied() {
        self = .denied
    }

    mutating func update(with captureState: WKWebView.CaptureState) {
        switch (self, captureState) {
        // same state
        case (.active, .active), (.paused, .muted), (.none, .none), (.inactive, .none),
             // (Disabled -> not used) stays Disabled
             (.disabled, .none), (.denied, .none):
            return

        // Permission Granted
        case (.requested, .active), (.disabled, .active):
            self = .active

        case (.denied, .active), (.revoking, .active):
            assertionFailure("Unexpected change of system disabled Permission")
            fallthrough
        // Permission Activated
        case (.none, .active), (.paused, .active), (.inactive, .active):
            self = .active

        case (.disabled, .muted), (.denied, .muted), (.requested, .muted), (.revoking, .muted):
            assertionFailure("Unexpected change of system disabled Permission")
            fallthrough
        // Muted
        case (.active, .muted), (.none, .muted), (.inactive, .muted):
            self = .paused

        // Permission deactivated
        case (.active, .none), (.paused, .none), (.requested, .none):
            self = .inactive

        // Permission revoked
        case (.revoking, .none):
            self = .denied
        }
    }

    mutating func paused() {
        guard case .active = self else {
            assertionFailure("PermissionState: trying to pause from non-active state")
            return
        }
        self = .paused
    }

    mutating func resumed() {
        guard case .paused = self else {
            assertionFailure("PermissionState: trying to resume from non-paused state")
            return
        }
        self = .active
    }

    mutating func revoke() {
        guard case .some = self else { return }
        self = .revoking
    }

}
