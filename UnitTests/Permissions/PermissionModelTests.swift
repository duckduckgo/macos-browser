//
//  PermissionModelTests.swift
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

import AVFoundation
import Combine
import Foundation
import WebKit
import XCTest
@testable import PixelKit

@testable import DuckDuckGo_Privacy_Browser

final class PermissionModelTests: XCTestCase {

    let permissionManagerMock = PermissionManagerMock()
    let geolocationServiceMock = GeolocationServiceMock()
    var geolocationProviderMock: GeolocationProviderMock!
    let webView = WebViewMock()
    var model: PermissionModel!
    let pixelKit = PixelKit(dryRun: true,
                            appVersion: "1.0.0",
                            defaultHeaders: [:],
                            defaults: UserDefaults(),
                            fireRequest: { _, _, _, _, _, _ in })

    var securityOrigin: WKSecurityOrigin {
        WKSecurityOriginMock.new(url: .duckDuckGo)
    }

    var frameInfo: WKFrameInfo {
        let request = URLRequest(url: .duckDuckGo)
        return WKFrameInfoMock(webView: webView, securityOrigin: securityOrigin, request: request, isMainFrame: true)
    }

    override func setUp() {
        PixelKit.setSharedForTesting(pixelKit: pixelKit)

        webView.uiDelegate = self

        geolocationProviderMock = GeolocationProviderMock(geolocationService: geolocationServiceMock)
        webView.configuration.processPool.geolocationProvider = geolocationProviderMock
        model = PermissionModel(webView: webView,
                                permissionManager: permissionManagerMock,
                                geolocationService: geolocationServiceMock)

        AVCaptureDeviceMock.authorizationStatuses = nil
    }

    override func tearDown() {
        AVCaptureDevice.restoreAuthorizationStatusForMediaType()
    }

    func testWhenCameraIsActivatedThenCameraPermissionChangesToActive() {
        if #available(macOS 12, *) {
            webView.cameraCaptureState = .active
        } else {
            webView.mediaCaptureState = .activeCamera
        }
        XCTAssertEqual(model.permissions, [.camera: .active])
    }

    func testWhenMicIsActivatedThenMicPermissionChangesToActive() {
        if #available(macOS 12, *) {
            webView.microphoneCaptureState = .active
        } else {
            webView.mediaCaptureState = .activeMicrophone
        }
        XCTAssertEqual(model.permissions, [.microphone: .active])
    }

    func testWhenCameraAndMicIsActivatedThenCameraAndMicPermissionChangesToActive() {
        if #available(macOS 12, *) {
            webView.cameraCaptureState = .active
            webView.microphoneCaptureState = .active
        } else {
            webView.mediaCaptureState = [.activeCamera, .activeMicrophone]
        }
        XCTAssertEqual(model.permissions, [.microphone: .active,
                                           .camera: .active])
    }

    func testWhenLocationIsActivatedThenLocationPermissionChangesToActive() {
        geolocationServiceMock.authorizationStatus = .notDetermined
        geolocationProviderMock.isActive = true
        geolocationServiceMock.authorizationStatus = .authorized
        XCTAssertEqual(model.permissions, [.geolocation: .active])
    }

    func testWhenPermissionIsDeactivatedThenStateChangesToInactive() {
        if #available(macOS 12, *) {
            webView.cameraCaptureState = .active
            webView.microphoneCaptureState = .active
            webView.cameraCaptureState = .none
            webView.microphoneCaptureState = .none
        } else {
            webView.mediaCaptureState = [.activeCamera, .activeMicrophone]
            webView.mediaCaptureState = []
        }

        XCTAssertEqual(model.permissions, [.microphone: .inactive,
                                           .camera: .inactive])
    }

    func testWhenLocationIsDeactivatedThenStateChangesToInactive() {
        geolocationServiceMock.authorizationStatus = .authorized
        geolocationProviderMock.isActive = true
        geolocationProviderMock.isActive = false

        XCTAssertEqual(model.permissions, [.geolocation: .inactive])
    }

    func testWhenPermissionIsQueriedThenQueryIsPublished() {
        let e = expectation(description: "Query received")
        let c = model.$authorizationQuery.sink { query in
            guard let query = query else { return }

            XCTAssertEqual(query.domain, URL.duckDuckGo.host)
            XCTAssertEqual(query.permissions, [.camera, .microphone])
            e.fulfill()
        }

        self.webView(webView, requestUserMediaAuthorizationFor: [.microphone, .camera],
                     url: .duckDuckGo,
                     mainFrameURL: .duckDuckGo) { _ in }

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
            XCTAssertEqual(model.permissions, [.camera: .requested(model.authorizationQuery!),
                                               .microphone: .requested(model.authorizationQuery!)])
        }
    }

    func testWhenMicPermissionIsQueriedThenQueryIsPublished_macOS12() {
        guard #available(macOS 12, *) else { return }

        let e = expectation(description: "Query received")
        let c = model.$authorizationQuery.sink { query in
            guard let query = query else { return }

            XCTAssertEqual(query.domain, URL.duckDuckGo.host)
            XCTAssertEqual(query.permissions, [.microphone])
            e.fulfill()
        }

        self.webView(webView,
                     requestMediaCapturePermissionFor: securityOrigin,
                     initiatedByFrame: frameInfo,
                     type: .microphone) { _ in }

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
            XCTAssertEqual(model.permissions, [.microphone: .requested(model.authorizationQuery!)])
        }
    }

    func testWhenCameraAndMicPermissionIsGrantedThenItIsProvidedToDecisionHandler() {
        let c = model.$authorizationQuery.sink {
            guard let query = $0 else { return }
            self.model.allow(query)
        }

        let e = expectation(description: "Permission granted")
        self.webView(webView, requestUserMediaAuthorizationFor: [.microphone, .camera],
                     url: .duckDuckGo,
                     mainFrameURL: .duckDuckGo) { granted in
            XCTAssertTrue(granted)
            e.fulfill()
            if #available(macOS 12, *) {
                self.webView.cameraCaptureState = .active
                self.webView.microphoneCaptureState = .active
            } else {
                self.webView.mediaCaptureState = [.activeCamera, .activeMicrophone]
            }
        }

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
        XCTAssertEqual(model.permissions, [.camera: .active,
                                           .microphone: .active])
        XCTAssertEqual(permissionManagerMock.permission(forDomain: URL.duckDuckGo.host!, permissionType: .camera), .ask)
        XCTAssertEqual(permissionManagerMock.permission(forDomain: URL.duckDuckGo.host!, permissionType: .microphone), .ask)
    }

    func testWhenPermissionIsGrantedAndStoredThenItIsStored() {
        let c = model.$authorizationQuery.sink {
            guard let query = $0 else { return }
            query.shouldShowAlwaysAllowCheckbox = true
            query.handleDecision(grant: true, remember: true)
        }

        let e = expectation(description: "Permission granted")
        self.webView(webView, requestUserMediaAuthorizationFor: [.microphone, .camera],
                     url: .duckDuckGo,
                     mainFrameURL: .duckDuckGo) { granted in
            XCTAssertTrue(granted)
            e.fulfill()
            if #available(macOS 12, *) {
                self.webView.cameraCaptureState = .active
                self.webView.microphoneCaptureState = .active
            } else {
                self.webView.mediaCaptureState = [.activeCamera, .activeMicrophone]
            }
        }

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
        XCTAssertEqual(model.permissions, [.camera: .active,
                                           .microphone: .active])
        XCTAssertEqual(permissionManagerMock.permission(forDomain: URL.duckDuckGo.host!, permissionType: .camera), .allow)
        XCTAssertEqual(permissionManagerMock.permission(forDomain: URL.duckDuckGo.host!, permissionType: .microphone), .allow)
    }

    func testWhenPermissionIsDeniedAndStoredThenItIsStored() {
        let c = model.$authorizationQuery.sink {
            guard let query = $0 else { return }
            query.shouldShowAlwaysAllowCheckbox = true
            query.handleDecision(grant: false, remember: true)
        }

        let e = expectation(description: "Permission granted")
        self.webView(webView, requestUserMediaAuthorizationFor: [.microphone, .camera],
                     url: .duckDuckGo,
                     mainFrameURL: .duckDuckGo) { granted in
            XCTAssertFalse(granted)
            e.fulfill()
        }

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
        XCTAssertEqual(permissionManagerMock.permission(forDomain: URL.duckDuckGo.host!, permissionType: .camera), .deny)
        XCTAssertEqual(permissionManagerMock.permission(forDomain: URL.duckDuckGo.host!, permissionType: .microphone), .deny)
    }

    func testWhenLocationPermissionIsGrantedThenItIsProvidedToDecisionHandler() {
        self.geolocationServiceMock.authorizationStatus = .authorized
        let c = model.$authorizationQuery.sink {
            $0?.handleDecision(grant: true)
        }

        let e = expectation(description: "Permission granted")
        self.webView(webView, requestGeolocationPermissionFor: frameInfo) { granted in
            XCTAssertTrue(granted)
            e.fulfill()
            self.geolocationProviderMock.isActive = true
        }

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
        XCTAssertEqual(model.permissions, [.geolocation: .active])
    }

    func testWhenCameraAndMicPermissionQueryIsResetThenItIsDenied() {
        let c = model.$authorizationQuery.sink {
            if $0 != nil {
                self.model!.tabDidStartNavigation()
            }
        }

        let e = expectation(description: "Permission granted")
        self.webView(webView, requestUserMediaAuthorizationFor: [.microphone, .camera],
                     url: .duckDuckGo,
                     mainFrameURL: .duckDuckGo) { granted in
            XCTAssertFalse(granted)
            e.fulfill()
        }

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
        XCTAssertEqual(model.permissions, [:])
    }

    func testWhenLocationPermissionQueryIsResetThenItIsDenied() {
        let c = model.$authorizationQuery.sink {
            if $0 != nil {
                self.model!.tabDidStartNavigation()
            }
        }

        let e = expectation(description: "Permission granted")
        self.webView(webView, requestGeolocationPermissionFor: frameInfo) { granted in
            XCTAssertFalse(granted)
            e.fulfill()
        }

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
        XCTAssertEqual(model.permissions, [:])
    }

    func testWhenExternalSchemePermissionQueryIsResetThenItTriggersDecisionHandler() {
        let c = model.$authorizationQuery.sink {
            if $0 != nil {
                self.model!.tabDidStartNavigation()
            }
        }

        let e = expectation(description: "Permission granted")
        model.permissions([.externalScheme(scheme: "mailto")], requestedForDomain: "test@example.com") { (_: Bool) in
            e.fulfill()
        }

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 0.1)
        }
        XCTAssertEqual(model.permissions, [:])
    }

    func testWhenAllowPermissionIsPersistedThenPermissionQueryIsGranted() {
        let e = expectation(description: "Permission granted")
        self.webView.urlValue = URL.duckDuckGo
        self.webView(webView, requestGeolocationPermissionFor: frameInfo) { granted in
            XCTAssertTrue(granted)
            e.fulfill()
        }

        self.permissionManagerMock.setPermission(.allow, forDomain: URL.duckDuckGo.host!, permissionType: .geolocation)
        permissionManagerMock.permissionSubject.send( (URL.duckDuckGo.host!, .geolocation, .allow) )
        waitForExpectations(timeout: 1)
    }

    func testWhenDenyPermissionIsPersistedThenPermissionQueryIsDenied() {
        let e = expectation(description: "Permission granted")
        self.webView.urlValue = URL.duckDuckGo
        self.webView(webView, requestGeolocationPermissionFor: frameInfo) { granted in
            XCTAssertFalse(granted)
            e.fulfill()
        }

        self.permissionManagerMock.setPermission(.deny, forDomain: URL.duckDuckGo.host!, permissionType: .geolocation)
        permissionManagerMock.permissionSubject.send( (URL.duckDuckGo.host!, .geolocation, .deny) )
        waitForExpectations(timeout: 1)
    }

    func testWhenSystemMediaPermissionIsDeniedThenStateIsDisabled() {
        let e = expectation(description: "decisionHandler called")
        AVCaptureDeviceMock.authorizationStatuses = [.audio: .denied]
        self.webView(webView, checkUserMediaPermissionFor: .duckDuckGo, mainFrameURL: .duckDuckGo, frameIdentifier: 0) { _, flag in
            XCTAssertFalse(flag)
            e.fulfill()

            _=AVCaptureDeviceMock.authorizationStatus(for: .audio)
        }

        waitForExpectations(timeout: 0)
        XCTAssertEqual(model.permissions, [.microphone: .disabled(systemWide: false)])
    }

    func testWhenSystemMediaPermissionIsRestrictedThenStateIsDisabled() {
        let e = expectation(description: "decisionHandler called")
        AVCaptureDeviceMock.authorizationStatuses = [.video: .restricted]
        self.webView(webView, checkUserMediaPermissionFor: .duckDuckGo, mainFrameURL: .duckDuckGo, frameIdentifier: 0) { _, flag in
            XCTAssertFalse(flag)
            e.fulfill()

            _=AVCaptureDeviceMock.authorizationStatus(for: .video)
        }

        waitForExpectations(timeout: 0)
        XCTAssertEqual(model.permissions, [.camera: .disabled(systemWide: false)])
    }

    func testWhenSystemMediaPermissionIsNotDeterminedThenStateIsNotUpdated() {
        let e = expectation(description: "decisionHandler called")
        AVCaptureDeviceMock.authorizationStatuses = [.audio: .notDetermined]
        self.webView(webView, checkUserMediaPermissionFor: .duckDuckGo, mainFrameURL: .duckDuckGo, frameIdentifier: 0) { _, flag in
            XCTAssertFalse(flag)
            e.fulfill()

            _=AVCaptureDeviceMock.authorizationStatus(for: .audio)
        }

        waitForExpectations(timeout: 0)
        XCTAssertEqual(model.permissions, [:])
    }

    func testWhenSystemMediaPermissionIsAuthorizedThenStateIsNotUpdated() {
        let e = expectation(description: "decisionHandler called")
        AVCaptureDeviceMock.authorizationStatuses = [.audio: .authorized]
        self.webView(webView, checkUserMediaPermissionFor: .duckDuckGo, mainFrameURL: .duckDuckGo, frameIdentifier: 0) { _, flag in
            XCTAssertFalse(flag)
            e.fulfill()

            _=AVCaptureDeviceMock.authorizationStatus(for: .video)
        }

        waitForExpectations(timeout: 0)
        XCTAssertEqual(model.permissions, [:])
    }

    func testWhenSystemLocationIsDisabledAndLocationQueriedThenStateIsDisabled() {
        geolocationServiceMock.authorizationStatus = .denied
        var e: XCTestExpectation!
        if #available(macOS 12, *) {
            self.webView(webView, requestGeolocationPermissionFor: securityOrigin, initiatedBy: frameInfo) { decision in
                XCTAssertEqual(decision, .grant)
                e.fulfill()
            }
        } else {
            self.webView(webView, requestGeolocationPermissionFor: frameInfo) { granted in
                XCTAssertTrue(granted)
                e.fulfill()
            }
        }
        XCTAssertEqual(model.permissions, [.geolocation: .disabled(systemWide: false)])

        e = expectation(description: "permission granted")
        geolocationServiceMock.authorizationStatus = .authorizedAlways
        XCTAssertEqual(model.permissions, [.geolocation: .requested(model.authorizationQuery!)])
        model.authorizationQuery!.handleDecision(grant: true)
        waitForExpectations(timeout: 1)

        geolocationProviderMock.isActive = true
        XCTAssertEqual(model.permissions, [.geolocation: .active])
    }

    func testWhenSystemLocationIsNotDeterminedAndLocationQueriedThenQueryIsMade() {
        geolocationServiceMock.authorizationStatus = .notDetermined
        var e: XCTestExpectation!
        if #available(macOS 12, *) {
            self.webView(webView, requestGeolocationPermissionFor: securityOrigin, initiatedBy: frameInfo) { decision in
                XCTAssertEqual(decision, .grant)
                e.fulfill()
            }
        } else {
            self.webView(webView, requestGeolocationPermissionFor: frameInfo) { granted in
                XCTAssertTrue(granted)
                e.fulfill()
            }
        }
        XCTAssertEqual(model.permissions, [.geolocation: .requested(model.authorizationQuery!)])
        e = expectation(description: "permission granted")
        model.authorizationQuery!.handleDecision(grant: true)
        waitForExpectations(timeout: 1)

        geolocationProviderMock.isActive = true
        geolocationServiceMock.authorizationStatus = .authorized
        XCTAssertEqual(model.permissions, [.geolocation: .active])
    }

    func testWhenSystemLocationIsNotDeterminedAndDisabledByUserThenStateIsDisabled() {
        geolocationServiceMock.authorizationStatus = .notDetermined
        var e: XCTestExpectation!
        if #available(macOS 12, *) {
            self.webView(webView, requestGeolocationPermissionFor: securityOrigin, initiatedBy: frameInfo) { decision in
                XCTAssertEqual(decision, .grant)
                e.fulfill()
            }
        } else {
            self.webView(webView, requestGeolocationPermissionFor: frameInfo) { granted in
                XCTAssertTrue(granted)
                e.fulfill()
            }
        }
        XCTAssertEqual(model.permissions, [.geolocation: .requested(model.authorizationQuery!)])
        e = expectation(description: "permission granted")
        model.authorizationQuery!.handleDecision(grant: true)
        waitForExpectations(timeout: 1)

        geolocationProviderMock.isActive = true
        geolocationServiceMock.authorizationStatus = .restricted
        XCTAssertEqual(model.permissions, [.geolocation: .disabled(systemWide: false)])
    }

    func testWhenSystemLocationIsDisabledThenStateIsDisabled() {
        geolocationServiceMock.authorizationStatus = .authorized
        geolocationProviderMock.isActive = true
        geolocationServiceMock.authorizationStatus = .denied
        XCTAssertEqual(model.permissions, [.geolocation: .disabled(systemWide: false)])
    }

    func testWhenSystemLocationIsDisabledSystemWideThenStateIsDisabled() {
        geolocationServiceMock.authorizationStatus = .authorized
        geolocationProviderMock.isActive = true
        geolocationServiceMock.locationServicesEnabledValue = false
        XCTAssertEqual(model.permissions, [.geolocation: .disabled(systemWide: true)])
    }

    func testWhenSystemLocationIsDisabledSystemWideButLocationIsNotActiveThenStateIsNotUpdated() {
        geolocationServiceMock.authorizationStatus = .notDetermined
        geolocationServiceMock.locationServicesEnabledValue = false
        XCTAssertEqual(model.permissions, [:])
    }

    func testWhenSystemLocationServicesDisabledButLocationIsNotActiveThenStateIsNotUpdated() {
        geolocationServiceMock.authorizationStatus = .notDetermined
        geolocationServiceMock.locationServicesEnabledValue = false
        XCTAssertEqual(model.permissions, [:])
    }

    func testWhenSystemLocationIsActivatedThenStateIsActive() {
        geolocationServiceMock.authorizationStatus = .denied
        geolocationServiceMock.locationServicesEnabledValue = false
        geolocationProviderMock.isActive = true
        geolocationServiceMock.authorizationStatus = .authorized
        geolocationServiceMock.locationServicesEnabledValue = true
        XCTAssertEqual(model.permissions, [.geolocation: .active])
    }

    func testWhenLocationRequeriedAfterSystemLocationIsDisabledThenStateIsDisabled() {
        geolocationServiceMock.authorizationStatus = .denied
        geolocationServiceMock.locationServicesEnabledValue = true
        geolocationServiceMock.authorizationStatus = .denied
        geolocationProviderMock.isActive = true

        var e: XCTestExpectation!
        if #available(macOS 12, *) {
            self.webView(webView, requestGeolocationPermissionFor: securityOrigin, initiatedBy: frameInfo) { decision in
                XCTAssertEqual(decision, .grant)
                e.fulfill()
            }
        } else {
            self.webView(webView, requestGeolocationPermissionFor: frameInfo) { granted in
                XCTAssertTrue(granted)
                e.fulfill()
            }
        }
        e = expectation(description: "permission granted")
        model.authorizationQuery!.handleDecision(grant: true)
        waitForExpectations(timeout: 1)
        geolocationProviderMock.isActive = true

        XCTAssertEqual(model.permissions, [.geolocation: .disabled(systemWide: false)])
    }

    func testWhenLocationRequeriedAfterSystemLocationIsDisabledSystemWideThenStateIsDisabledSystemWide() {
        geolocationServiceMock.authorizationStatus = .denied
        geolocationServiceMock.locationServicesEnabledValue = false
        geolocationServiceMock.authorizationStatus = .denied
        geolocationProviderMock.isActive = true

        var e: XCTestExpectation!
        if #available(macOS 12, *) {
            self.webView(webView, requestGeolocationPermissionFor: securityOrigin, initiatedBy: frameInfo) { decision in
                XCTAssertEqual(decision, .grant)
                e.fulfill()
            }
        } else {
            self.webView(webView, requestGeolocationPermissionFor: frameInfo) { granted in
                XCTAssertTrue(granted)
                e.fulfill()
            }
        }
        e = expectation(description: "permission granted")
        model.authorizationQuery!.handleDecision(grant: true)
        waitForExpectations(timeout: 1)
        geolocationProviderMock.isActive = true

        XCTAssertEqual(model.permissions, [.geolocation: .disabled(systemWide: true)])
    }

    func testWhenPageIsReloadedThenInactivePermissionStateIsReset() {
        webView.mediaCaptureState = [.activeCamera, .activeMicrophone]
        webView.mediaCaptureState = []

        model.tabDidStartNavigation()
        XCTAssertEqual(model.permissions, [:])
    }

    func testWhenPageIsReloadedThenActivePermissionStateIsReset() {
        webView.mediaCaptureState = [.activeCamera, .activeMicrophone]

        model.tabDidStartNavigation()
        webView.mediaCaptureState = []

        XCTAssertEqual(model.permissions, [:])
    }

    func testWhenPageIsReloadedThenPausedPermissionStateIsReset() {
        webView.mediaCaptureState = [.activeCamera, .activeMicrophone]
        webView.mediaCaptureState = [.mutedCamera, .mutedMicrophone]

        model.tabDidStartNavigation()
        webView.mediaCaptureState = []

        XCTAssertEqual(model.permissions, [:])
    }

    func testWhenPermissionIsGrantedThenItsRepeatedQueryIsQueried() {
        let e = expectation(description: "Permission queried")
        var c = model.$authorizationQuery.sink { query in
            guard let query = query else { return }
            query.handleDecision(grant: true)
            e.fulfill()
        }

        let e2 = expectation(description: "Permission granted")
        self.webView(webView, requestUserMediaAuthorizationFor: [.microphone, .camera],
                     url: .duckDuckGo,
                     mainFrameURL: .duckDuckGo) { granted in
            XCTAssertTrue(granted)
            e2.fulfill()

            self.webView.mediaCaptureState = [.activeCamera, .activeMicrophone]
            self.webView.mediaCaptureState = []
        }

        waitForExpectations(timeout: 1)

        let e3 = expectation(description: "Permission queried again")
        c = model.$authorizationQuery.sink { query in
            guard let query = query else { return }
            query.handleDecision(grant: false)
            e3.fulfill()
        }
        let e4 = expectation(description: "Permission granted again")
        self.webView(webView, requestUserMediaAuthorizationFor: [.microphone, .camera],
                     url: .duckDuckGo,
                     mainFrameURL: .duckDuckGo) { granted in
            XCTAssertFalse(granted)
            e4.fulfill()
        }

        withExtendedLifetime(c) { waitForExpectations(timeout: 1) }
    }

    func testWhenPermissionIsDeniedThenItsRepeatedQueryIsDenied() {
        let e = expectation(description: "Permission queried")
        let c = model.$authorizationQuery.sink { query in
            guard let query = query else { return }
            query.handleDecision(grant: false)
            e.fulfill()
        }

        let e2 = expectation(description: "Permission granted")
        self.webView(webView, requestUserMediaAuthorizationFor: .camera,
                     url: .duckDuckGo,
                     mainFrameURL: .duckDuckGo) { granted in
            XCTAssertFalse(granted)
            e2.fulfill()
        }

        waitForExpectations(timeout: 1)

        let e3 = expectation(description: "Permission granted again")
        self.webView(webView, requestUserMediaAuthorizationFor: [.microphone, .camera],
                     url: .duckDuckGo,
                     mainFrameURL: .duckDuckGo) { granted in
            XCTAssertFalse(granted)
            e3.fulfill()
        }

        withExtendedLifetime(c) { waitForExpectations(timeout: 1) }
    }

    func testWhenDeniedPermissionIsStoredThenQueryIsDenied() {
        permissionManagerMock.setPermission(.allow, forDomain: URL.duckDuckGo.host!, permissionType: .camera)
        permissionManagerMock.setPermission(.deny, forDomain: URL.duckDuckGo.host!, permissionType: .microphone)

        let c = model.$authorizationQuery.sink { query in
            guard query != nil else { return }
            XCTFail("Unexpected query")
        }
        let e = expectation(description: "Permission denied")
        self.webView(webView, requestUserMediaAuthorizationFor: [.microphone, .camera],
                     url: .duckDuckGo,
                     mainFrameURL: .duckDuckGo) { granted in
            XCTAssertFalse(granted)
            e.fulfill()
        }
        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenGrantedPermissionIsStoredThenQueryIsGranted() {
        permissionManagerMock.setPermission(.allow, forDomain: URL.duckDuckGo.host!, permissionType: .camera)
        permissionManagerMock.setPermission(.allow, forDomain: URL.duckDuckGo.host!, permissionType: .microphone)

        let c = model.$authorizationQuery.sink { query in
            guard query != nil else { return }
            XCTFail("Unexpected query")
        }
        let e = expectation(description: "Permission granted")
        self.webView(webView, requestUserMediaAuthorizationFor: [.microphone, .camera],
                     url: .duckDuckGo,
                     mainFrameURL: .duckDuckGo) { granted in
            XCTAssertTrue(granted)
            e.fulfill()
        }
        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenPartialGrantedPermissionIsStoredThenQueryIsQueried() {
        permissionManagerMock.setPermission(.allow, forDomain: URL.duckDuckGo.host!, permissionType: .camera)

        let e = expectation(description: "Permission asked")
        let c = model.$authorizationQuery.sink { query in
            guard query != nil else { return }
            e.fulfill()
        }

        self.webView(webView, requestUserMediaAuthorizationFor: [.microphone, .camera],
                     url: .duckDuckGo,
                     mainFrameURL: .duckDuckGo) { _ in
        }
        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenDeniedPermissionIsStoredThenActivePermissionIsRevoked() {
        webView.urlValue = URL(string: "http://www.duckduckgo.com")!
        if #available(macOS 12, *) {
            webView.cameraCaptureState = .active
            webView.microphoneCaptureState = .active
        } else {
            webView.mediaCaptureState = [.activeCamera, .activeMicrophone]
        }
        permissionManagerMock.setPermission(.allow, forDomain: URL.duckDuckGo.host!, permissionType: .camera)

        let e = expectation(description: "camera stopped")
        if #available(macOS 12, *) {
            webView.setMicCaptureStateHandler = { _ in
                XCTFail("unexpected call")
            }
            webView.setCameraCaptureStateHandler = {
                XCTAssertEqual($0, .none)
                e.fulfill()
            }
        } else {
            webView.stopMediaCaptureHandler = {
                e.fulfill()
            }
        }

        permissionManagerMock.setPermission(.deny, forDomain: URL.duckDuckGo.host!, permissionType: .camera)
        permissionManagerMock.permissionSubject.send( (URL.duckDuckGo.host!, .camera, .deny) )

        waitForExpectations(timeout: 1)
    }

    func testWhenPopupsGrantedPermissionIsStoredAndRevokedThenStoredPermissionIsRemoved() {
        permissionManagerMock.setPermission(.allow, forDomain: URL.duckDuckGo.host!, permissionType: .popups)
        permissionManagerMock.setPermission(.allow, forDomain: URL.duckDuckGo.host!, permissionType: .externalScheme(scheme: "asdf"))

        webView.urlValue = URL.duckDuckGo
        model.revoke(.popups)

        XCTAssertEqual(permissionManagerMock.permission(forDomain: URL.duckDuckGo.host!, permissionType: .popups),
                       .ask)
        XCTAssertEqual(permissionManagerMock.permission(forDomain: URL.duckDuckGo.host!, permissionType: .externalScheme(scheme: "asdf")),
                       .allow)
        XCTAssertEqual(model.permissions.popups, .denied)
    }

    func testWhenExternalAppGrantedPermissionIsStoredAndRevokedThenStoredPermissionIsRemoved() {
        permissionManagerMock.setPermission(.allow, forDomain: URL.duckDuckGo.host!, permissionType: .popups)
        permissionManagerMock.setPermission(.allow, forDomain: URL.duckDuckGo.host!, permissionType: .externalScheme(scheme: "asdf"))
        permissionManagerMock.setPermission(.allow, forDomain: URL.duckDuckGo.host!, permissionType: .externalScheme(scheme: "sdfg"))

        webView.urlValue = URL.duckDuckGo

        model.revoke(.externalScheme(scheme: "asdf"))

        XCTAssertEqual(permissionManagerMock.permission(forDomain: URL.duckDuckGo.host!, permissionType: .popups),
                       .allow)
        XCTAssertEqual(permissionManagerMock.permission(forDomain: URL.duckDuckGo.host!, permissionType: .externalScheme(scheme: "asdf")),
                       .ask)
        XCTAssertEqual(permissionManagerMock.permission(forDomain: URL.duckDuckGo.host!, permissionType: .externalScheme(scheme: "sdfg")),
                       .allow)
    }

    func testWhenGrantedPermissionIsRemovedThenActivePermissionStaysActive() {
        webView.urlValue = URL(string: "http://www.duckduckgo.com")!
        if #available(macOS 12, *) {
            self.webView.cameraCaptureState = .active
            self.webView.microphoneCaptureState = .active
        } else {
            self.webView.mediaCaptureState = [.activeCamera, .activeMicrophone]
        }
        permissionManagerMock.setPermission(.allow, forDomain: URL.duckDuckGo.host!, permissionType: .camera)

        if #available(macOS 12, *) {
            webView.setMicCaptureStateHandler = { _ in
                XCTFail("unexpected call")
            }
            webView.setCameraCaptureStateHandler = { _ in
                XCTFail("unexpected call")
            }
        } else {
            webView.stopMediaCaptureHandler = {
                XCTFail("unexpected call")
            }
        }

        permissionManagerMock.removePermission(forDomain: URL.duckDuckGo.host!, permissionType: .camera)
        permissionManagerMock.permissionSubject.send( (URL.duckDuckGo.host!, .camera, .ask) )
    }

    func testWhenMicrophoneIsMutedThenSetMediaCaptureMutedIsCalled() {
        if #available(macOS 12, *) {
            self.webView.cameraCaptureState = .active
            self.webView.microphoneCaptureState = .active
        } else {
            self.webView.mediaCaptureState = [.activeCamera, .activeMicrophone]
        }

        let e = expectation(description: "mic muted")
        if #available(macOS 12, *) {
            webView.setMicCaptureStateHandler = {
                e.fulfill()
                XCTAssertEqual($0, false)
            }
            webView.setCameraCaptureStateHandler = { _ in
                XCTFail("Unexpected call")
            }
        } else {
            webView.setPageMutedHandler = {
                XCTAssertEqual($0, [.captureDevicesMuted])
                e.fulfill()
            }
        }

        model.set(.microphone, muted: true)
        waitForExpectations(timeout: 0)
        if #available(macOS 12, *) {
            self.webView.cameraCaptureState = .muted
            self.webView.microphoneCaptureState = .muted
        } else {
            webView.mediaCaptureState = [.mutedCamera, .mutedMicrophone]
        }

        XCTAssertEqual(model.permissions, [.camera: .paused, .microphone: .paused])
    }

    func testWhenCameraIsMutedThenSetMediaCaptureMutedIsCalled() {
        if #available(macOS 12, *) {
            self.webView.cameraCaptureState = .active
            self.webView.microphoneCaptureState = .active
        } else {
            self.webView.mediaCaptureState = [.activeCamera, .activeMicrophone]
        }

        let e = expectation(description: "camera muted")
        if #available(macOS 12, *) {
            webView.setMicCaptureStateHandler = { _ in
                XCTFail("Unexpected call")
            }
            webView.setCameraCaptureStateHandler = {
                e.fulfill()
                XCTAssertEqual($0, false)
            }
        } else {
            webView.setPageMutedHandler = {
                XCTAssertEqual($0, [.captureDevicesMuted])
                e.fulfill()
            }
        }

        model.set(.camera, muted: true)
        waitForExpectations(timeout: 0)
    }

    func testWhenLocationIsMutedThenPauseIsCalled() {
        geolocationServiceMock.authorizationStatus = .authorized
        geolocationProviderMock.isActive = true

        model.set(.geolocation, muted: true)
        XCTAssertTrue(geolocationProviderMock.isPaused)
        XCTAssertEqual(model.permissions, [.geolocation: .paused])
    }

    func testWhenCameraIsUnmutedThenSetMediaCaptureMutedIsCalled() {
        webView.mediaCaptureState = [.activeCamera, .activeMicrophone]
        webView.mediaCaptureState = [.mutedCamera, .mutedMicrophone]

        let e = expectation(description: "camera resumed")
        if #available(macOS 12, *) {
            webView.cameraCaptureState = .muted
            webView.microphoneCaptureState = .muted
            webView.setMicCaptureStateHandler = { _ in
                XCTFail("Unexpected call")
            }
            webView.setCameraCaptureStateHandler = {
                e.fulfill()
                XCTAssertEqual($0, true)
            }
        } else {
            webView.mediaMutedStateValue = .captureDevicesMuted
            webView.setPageMutedHandler = {
                XCTAssertEqual($0, [])
                e.fulfill()
            }
        }

        model.set(.camera, muted: false)
        waitForExpectations(timeout: 0)
    }

    func testWhenLocationIsUnmutedThenResumeIsCalled() {
        geolocationServiceMock.authorizationStatus = .authorized
        geolocationProviderMock.isActive = true
        geolocationProviderMock.isPaused = true

        model.set(.geolocation, muted: false)
        XCTAssertFalse(geolocationProviderMock.isPaused)
        XCTAssertEqual(model.permissions, [.geolocation: .active])
    }

    func testWhenCameraAndMicAreMutedThenSetMediaCaptureMutedIsCalled() {
        webView.mediaCaptureState = [.activeCamera, .activeMicrophone]

        let e1 = expectation(description: "mic muted")
        let e2 = expectation(description: "camera muted")
        if #available(macOS 12, *) {
            webView.setMicCaptureStateHandler = {
                e1.fulfill()
                XCTAssertEqual($0, false)
            }
            webView.setCameraCaptureStateHandler = {
                e2.fulfill()
                XCTAssertEqual($0, false)
            }
        } else {
            webView.setPageMutedHandler = {
                XCTAssertEqual($0, [.captureDevicesMuted])
                e1.fulfill()
                e2.fulfill()
            }
        }

        model.set([.camera, .microphone], muted: true)
        waitForExpectations(timeout: 0)
        webView.mediaCaptureState = [.mutedCamera, .mutedMicrophone]

        XCTAssertEqual(model.permissions, [.camera: .paused, .microphone: .paused])
    }

    func testWhenCameraAndMicAreUnmutedThenSetMediaCaptureMutedIsCalled() {
        webView.mediaCaptureState = [.activeCamera, .activeMicrophone]
        webView.mediaCaptureState = [.mutedCamera, .mutedMicrophone]

        let e1 = expectation(description: "mic resumed")
        let e2 = expectation(description: "camera resumed")
        if #available(macOS 12, *) {
            webView.cameraCaptureState = .muted
            webView.microphoneCaptureState = .muted
            webView.setMicCaptureStateHandler = {
                e1.fulfill()
                XCTAssertEqual($0, true)
            }
            webView.setCameraCaptureStateHandler = {
                e2.fulfill()
                XCTAssertEqual($0, true)
            }
        } else {
            webView.mediaMutedStateValue = .captureDevicesMuted
            webView.setPageMutedHandler = {
                XCTAssertEqual($0, [])
                e1.fulfill()
                e2.fulfill()
            }
        }

        model.set([.camera, .microphone], muted: false)
        waitForExpectations(timeout: 0)
        webView.mediaCaptureState = [.activeCamera, .activeMicrophone]

        XCTAssertEqual(model.permissions, [.camera: .active, .microphone: .active])
    }

    func testWhenMicrophoneIsRevokedThenStopMediaCaptureIsCalled() {
        if #available(macOS 12, *) {
            self.webView.cameraCaptureState = .active
            self.webView.microphoneCaptureState = .active
        } else {
            self.webView.mediaCaptureState = [.activeCamera, .activeMicrophone]
        }

        let e = expectation(description: "mic stopped")
        if #available(macOS 12, *) {
            webView.setMicCaptureStateHandler = {
                XCTAssertEqual($0, .none)
                e.fulfill()
            }
            webView.setCameraCaptureStateHandler = { _ in
                XCTFail("unexpected call")
            }
        } else {
            webView.stopMediaCaptureHandler = {
                e.fulfill()
            }
        }

        model.revoke(.microphone)
        waitForExpectations(timeout: 0)
        if #available(macOS 12, *) {
            XCTAssertEqual(model.permissions, [.camera: .active, .microphone: .denied])
        } else {
            XCTAssertEqual(model.permissions, [.camera: .inactive, .microphone: .denied])
        }
    }

    func testWhenCameraIsRevokedThenStopMediaCaptureIsCalled() {
        if #available(macOS 12, *) {
            self.webView.cameraCaptureState = .active
            self.webView.microphoneCaptureState = .active
        } else {
            self.webView.mediaCaptureState = [.activeCamera, .activeMicrophone]
        }

        let e = expectation(description: "camera stopped")
        if #available(macOS 12, *) {
            webView.setMicCaptureStateHandler = { _ in
                XCTFail("unexpected call")
            }
            webView.setCameraCaptureStateHandler = {
                XCTAssertEqual($0, .none)
                e.fulfill()
            }
        } else {
            webView.stopMediaCaptureHandler = {
                e.fulfill()
            }
        }

        model.revoke(.camera)
        waitForExpectations(timeout: 0)

        if #available(macOS 12, *) {
            XCTAssertEqual(model.permissions, [.camera: .denied, .microphone: .active])
        } else {
            XCTAssertEqual(model.permissions, [.camera: .denied, .microphone: .inactive])
        }
    }

    func testWhenCameraAndMicAreRevokedThenStopMediaCaptureIsCalled() {
        if #available(macOS 12, *) {
            self.webView.cameraCaptureState = .active
            self.webView.microphoneCaptureState = .active
        } else {
            self.webView.mediaCaptureState = [.activeCamera, .activeMicrophone]
        }

        let e1 = expectation(description: "camera stopped")
        let e2 = expectation(description: "mic stopped")
        if #available(macOS 12, *) {
            webView.setCameraCaptureStateHandler = {
                XCTAssertEqual($0, .none)
                e1.fulfill()
            }
            webView.setMicCaptureStateHandler = {
                XCTAssertEqual($0, .none)
                e2.fulfill()
            }
        } else {
            webView.stopMediaCaptureHandler = { [unowned webView] in
                e1.fulfill()
                webView.stopMediaCaptureHandler = {
                    e2.fulfill()
                }
            }
        }

        model.revoke(.camera)
        model.revoke(.microphone)
        waitForExpectations(timeout: 0)

        XCTAssertEqual(model.permissions, [.camera: .denied, .microphone: .denied])
    }

    func testWhenGeolocationIsRevokedThenRevokeGeolocationIsCalled() {
        geolocationServiceMock.authorizationStatus = .authorized
        geolocationProviderMock.isActive = true

        model.revoke(.geolocation)
        XCTAssertEqual(model.permissions, [.geolocation: .denied])
    }

}

extension PermissionModelTests: WebViewPermissionsDelegate {

    @objc(_webView:checkUserMediaPermissionForURL:mainFrameURL:frameIdentifier:decisionHandler:)
    func webView(_ webView: WKWebView,
                 checkUserMediaPermissionFor url: URL,
                 mainFrameURL: URL,
                 frameIdentifier frame: UInt,
                 decisionHandler: @escaping (String, Bool) -> Void) {
        self.model.checkUserMediaPermission(for: url, mainFrameURL: mainFrameURL, decisionHandler: decisionHandler)
    }

    @objc(webView:requestMediaCapturePermissionForOrigin:initiatedByFrame:type:decisionHandler:)
    @available(macOS 12, *)
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        guard let permissions = [PermissionType](devices: type) else {
            fatalError()
        }

        self.model.permissions(permissions, requestedForDomain: origin.host) { granted in
            decisionHandler(granted ? .grant : .deny)
        }
    }

    @objc(_webView:requestUserMediaAuthorizationForDevices:url:mainFrameURL:decisionHandler:)
    func webView(_ webView: WKWebView,
                 requestUserMediaAuthorizationFor devices: _WKCaptureDevices,
                 url: URL,
                 mainFrameURL: URL,
                 decisionHandler: @escaping (Bool) -> Void) {
        guard let permissions = [PermissionType](devices: devices) else {
            fatalError()
        }

        self.model.permissions(permissions, requestedForDomain: url.host ?? "", decisionHandler: decisionHandler)
    }

    @objc(_webView:mediaCaptureStateDidChange:)
    func webView(_ webView: WKWebView, mediaCaptureStateDidChange state: _WKMediaCaptureStateDeprecated) {
        self.model.mediaCaptureStateDidChange()
    }

    @objc(_webView:requestGeolocationPermissionForFrame:decisionHandler:)
    func webView(_ webView: WKWebView, requestGeolocationPermissionFor frame: WKFrameInfo, decisionHandler: @escaping (Bool) -> Void) {
        self.model.permissions(.geolocation, requestedForDomain: frame.safeRequest?.url?.host ?? "", decisionHandler: decisionHandler)
    }

    @objc(_webView:requestGeolocationPermissionForOrigin:initiatedByFrame:decisionHandler:)
    @available(macOS 12, *)
    func webView(_ webView: WKWebView,
                 requestGeolocationPermissionFor origin: WKSecurityOrigin,
                 initiatedBy frame: WKFrameInfo,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        self.model.permissions(.geolocation, requestedForDomain: frame.safeRequest?.url?.host ?? "") { granted in
            decisionHandler(granted ? .grant : .deny)
        }
    }

}
