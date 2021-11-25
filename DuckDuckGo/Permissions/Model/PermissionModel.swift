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
import CoreLocation

// swiftlint:disable:next type_body_length
final class PermissionModel {

    @PublishedAfter var permissions = Permissions()
    @PublishedAfter var authorizationQuery: PermissionAuthorizationQuery?

    private(set) var authorizationQueries = [PermissionAuthorizationQuery]() {
        didSet {
            authorizationQuery = authorizationQueries.first
        }
    }

    private let permissionManager: PermissionManagerProtocol
    private let geolocationService: GeolocationServiceProtocol
    private weak var webView: WKWebView?
    private var cancellables = Set<AnyCancellable>()

    init(webView: WKWebView,
         permissionManager: PermissionManagerProtocol = PermissionManager.shared,
         geolocationService: GeolocationServiceProtocol = GeolocationService.shared) {
        self.permissionManager = permissionManager
        self.webView = webView
        self.geolocationService = geolocationService

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
        geolocationProvider?.isActivePublisher.sink { [weak self] _ in
            self?.updatePermissions()
        }.store(in: &cancellables)
        geolocationProvider?.isPausedPublisher.sink { [weak self] _ in
            self?.updatePermissions()
        }.store(in: &cancellables)
        geolocationProvider?.authorizationStatusPublisher.sink { [weak self] authorizationStatus in
            self?.geolocationAuthorizationStatusDidChange(to: authorizationStatus)
        }.store(in: &cancellables)
    }

    private func subscribe(to permissionManager: PermissionManagerProtocol) {
        permissionManager.permissionPublisher.sink { [weak self] value in
            self?.permissionManager(permissionManager,
                                    didChangePermanentDecisionFor: value.permissionType,
                                    forDomain: value.domain,
                                    to: value.grant)
        }.store(in: &cancellables)
    }

    private func resetPermissions() {
        webView?.configuration.processPool.geolocationProvider?.reset()
        webView?.revokePermissions([.camera, .microphone])
        for permission in PermissionType.allCases {
            // await permission deactivation and transition to .none
            permissions[permission].willReload()
        }
        authorizationQueries = []
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
                // Geolocation Authorization is queried before checking the System Permission
                // if it is nil means there was no query made,
                // if query was made but System Permission is disabled: switch to Disabled state
                if permissions.geolocation != nil,
                   [.denied, .restricted].contains(authorizationStatus) {
                    permissions.geolocation
                        .systemAuthorizationDenied(systemWide: !geolocationService.locationServicesEnabled())
                } else {
                    permissions.geolocation.update(with: webView.geolocationState)
                }
            case .popups:
                continue
            }
        }
    }

    private func queryAuthorization(for permissions: [PermissionType],
                                    domain: String,
                                    url: URL?,
                                    decisionHandler: @escaping (Bool) -> Void) {
        let query = PermissionAuthorizationQuery(domain: domain, url: url, permissions: permissions) { [weak self] decision in
            let query: PermissionAuthorizationQuery?
            let granted: Bool
            switch decision {
            case .deinitialized:
                query = nil
                granted = false

            case .denied(let completedQuery):
                query = completedQuery
                granted = false

                for permission in permissions {
                    self?.permissions[permission].denied()
                }

            case .granted(let completedQuery):
                query = completedQuery
                granted = true

                for permission in permissions {
                    self?.permissions[permission].granted()
                }
            }

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
        }

        // When Geolocation queried by a website but System Permission is denied: switch to `disabled`
        if permissions.contains(.geolocation),
           [.denied, .restricted].contains(self.geolocationService.authorizationStatus)
            || !geolocationService.locationServicesEnabled() {
            self.permissions.geolocation
                .systemAuthorizationDenied(systemWide: !geolocationService.locationServicesEnabled())
        }

        permissions.forEach { self.permissions[$0].authorizationQueried(query) }
        authorizationQueries.append(query)
    }

    private func permissionManager(_: PermissionManagerProtocol,
                                   didChangePermanentDecisionFor permissionType: PermissionType,
                                   forDomain domain: String,
                                   to decision: Bool?) {

        // If Always Deny for the current host: revoke the permission
        guard webView?.url?.domain?.dropWWW() == domain,
           decision == false,
           self.permissions[permissionType] != nil
        else {
            return
        }

        self.revoke(permissionType)
    }

    // MARK: Pausing/Revoking

    func set(_ permissions: [PermissionType], muted: Bool) {
        webView?.setPermissions(permissions, muted: muted)
    }

    func set(_ permission: PermissionType, muted: Bool) {
        webView?.setPermissions([permission], muted: muted)
    }

    func allow(_ query: PermissionAuthorizationQuery) {
        guard self.authorizationQueries.contains(where: { $0 === query }) else {
            assertionFailure("unexpected Permission state")
            return
        }
        query.handleDecision(grant: true)
    }

    func revoke(_ permission: PermissionType) {
        if let domain = webView?.url?.domain,
           permissionManager.permission(forDomain: domain, permissionType: permission) == true {
            permissionManager.removePermission(forDomain: domain, permissionType: permission)
        }
        self.permissions[permission].revoke() // await deactivation
        webView?.revokePermissions([permission])
    }

    // MARK: - WebView delegated methods

    // Called before requestMediaCapturePermissionFor: to validate System Permissions
    func checkUserMediaPermission(for url: URL, mainFrameURL: URL, decisionHandler: @escaping (String, Bool) -> Void) {
        // If media capture is denied in the System Preferences, reflect it in the current permissions
        // AVCaptureDevice.authorizationStatus(for:mediaType) is swizzled to determine requested media type
        // otherwise WebView won't call any other delegate methods if System Permission is denied
        AVCaptureDevice.swizzleAuthorizationStatusForMediaType { mediaType, authorizationStatus in
            switch authorizationStatus {
            case .denied, .restricted:
                // media type for Camera/Microphone can be only determined separately
                switch mediaType {
                case .audio:
                    self.permissions.microphone.systemAuthorizationDenied(systemWide: false)
                case .video:
                    self.permissions.camera.systemAuthorizationDenied(systemWide: false)
                default: break
                }

            case .notDetermined, .authorized: break
            @unknown default: break
            }
        }
        decisionHandler(/*salt - seems not used anywhere:*/ "",
                        /*includeSensitiveMediaDeviceDetails:*/ false)
        AVCaptureDevice.restoreAuthorizationStatusForMediaType()
    }

    private func shouldGrantPermission(for permissions: [PermissionType], requestedForDomain domain: String) -> Bool? {
        for permission in permissions {
            var grant: Bool?
            if let stored = permissionManager.permission(forDomain: domain, permissionType: permission),
               permission.canPersistGrantedDecision || stored != true {
                grant = stored
            } else if let state = self.permissions[permission] {
                switch state {
                // deny if already denied during current page being displayed
                case .denied, .revoking:
                    grant = false
                // ask otherwise
                case .disabled, .requested, .active, .inactive, .paused, .reloading:
                    break
                }
            }

            if let grant = grant {
                if grant == false {
                    // deny if at least one permission denied permanently
                    // or during current page being displayed
                    return false
                } // else if grant == true: allow if all permissions allowed permanently
            } else {
                // if at least one permission is not set: ask
                return nil
            }
        }
        return true
    }

    func permissions(_ permissions: [PermissionType],
                     requestedForDomain domain: String?,
                     url: URL? = nil,
                     decisionHandler: @escaping (Bool) -> Void) {
        guard let domain = domain,
              !domain.isEmpty,
              !permissions.isEmpty
        else {
            assertionFailure("Unexpected permissions/domain")
            decisionHandler(false)
            return
        }

        let shouldGrant = shouldGrantPermission(for: permissions, requestedForDomain: domain)
        switch shouldGrant {
        case .none:
            queryAuthorization(for: permissions, domain: domain, url: url, decisionHandler: decisionHandler)
        case .some(true):
            decisionHandler(true)
        case .some(false):
            decisionHandler(false)
            for permission in permissions {
                self.permissions[permission].denied()
            }
        }
    }

    func mediaCaptureStateDidChange() {
        updatePermissions()
    }

    func tabDidStartNavigation() {
        resetPermissions()
    }

    func geolocationAuthorizationStatusDidChange(to authorizationStatus: CLAuthorizationStatus) {
        switch (authorizationStatus, geolocationService.locationServicesEnabled()) {
        case (.authorized, true), (.authorizedAlways, true):
            // if a website awaits a Query Authorization while System Permission is disabled
            // show the Authorization Popover
            if let query = self.authorizationQueries.first(where: { $0.permissions.contains(.geolocation) }),
               case .disabled = self.permissions.geolocation {
                // switch to `requested` state
                self.permissions.geolocation.systemAuthorizationGranted(pendingQuery: query)
            } else {
                self.updatePermissions()
            }

        case (.notDetermined, true):
            break

        case (.denied, true), (.restricted, true):
            // do not switch to `disabled` state if a website didn't ask for Location
            guard self.permissions.geolocation != nil else { break }
            self.permissions.geolocation
                .systemAuthorizationDenied(systemWide: false)

        case (_, false): // Geolocation Services disabled globally
            guard self.permissions.geolocation != nil else { break }
            self.permissions.geolocation
                .systemAuthorizationDenied(systemWide: true)

        @unknown default: break
        }
    }

}
