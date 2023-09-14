//
//  GeolocationProviderTests.swift
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
import XCTest
import Combine
import CoreLocation
import WebKit
@testable import DuckDuckGo_Privacy_Browser

final class GeolocationProviderTests: XCTestCase {

    let geolocationServiceMock = GeolocationServiceMock()
    let appIsActive = CurrentValueSubject<Bool, Never>(true)
    var windows = [NSWindow]()
    var webViews = [WKWebView]()
    var webView: WKWebView!
    var shouldGrant = true
    var geolocationHandler: ((WKWebView, Any) throws -> Void)?

    static let coordinatesCallback = """
        function(e) {
            webkit.messageHandlers.testHandler.postMessage({
                coordinates: {
                    latitude: e.coords.latitude,
                    longitude: e.coords.longitude,
                    altitude: e.coords.altitude,
                    accuracy: e.coords.accuracy,
                    altitudeAccuracy: e.coords.altitudeAccuracy,
                    heading: e.coords.heading,
                    speed: e.coords.speed
                },
                timestamp: e.timestamp
            })
        }
    """
    static let errorCallback = """
        function(e) {
            webkit.messageHandlers.testHandler.postMessage({ code: e.code, message: e.message });
        }
    """

    static let getCurrentPosition = """
        <script>
            navigator.geolocation.getCurrentPosition(\(coordinatesCallback), \(errorCallback));
        </script>
    """
    class func watchPosition(enableHighAccuracy: Bool = false, maxAge: TimeInterval = 0) -> String {
        """
            <script>
                var watchId = navigator.geolocation.watchPosition(\(coordinatesCallback), \(errorCallback), {
                    enableHighAccuracy: \(enableHighAccuracy),
                    maximumAge: \(Int(maxAge * 1000))
                });

                function clearWatch() {
                    navigator.geolocation.clearWatch(watchId);
                }
            </script>
        """
    }

    override func setUp() {
        webView = makeWebView()
    }

    func makeWebView() -> WKWebView {
        let window = NSWindow(contentRect: NSRect(x: 300, y: 300, width: 50, height: 50), styleMask: .titled, backing: .buffered, defer: false)
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 50, height: 50))
        let webView = WKWebView(frame: view.bounds)
        view.addSubview(webView)
        webViews.append(webView)

        let geolocationProvider = GeolocationProvider(processPool: webView.configuration.processPool,
                                                      geolocationService: geolocationServiceMock,
                                                      appIsActivePublisher: appIsActive)
        webView.configuration.processPool.geolocationProvider = geolocationProvider
        webView.configuration.userContentController.add(self, name: "testHandler")

        webView.uiDelegate = self

        window.contentView = view
        window.orderFront(nil)
        windows.append(window)

        return webView
    }

    override func tearDown() {
        geolocationServiceMock.onSubscriptionReceived = nil
        geolocationServiceMock.onSubscriptionCancelled = nil
        geolocationHandler = nil
        windows.forEach { $0.orderOut(nil) }
    }

    func testWhenGeolocationRequestedThenGeolocationIsProvidedOnce() {
        let subscribed = expectation(description: "subscribed")
        let geolocationReceived = expectation(description: "location received")
        let cancelled = expectation(description: "cancelled")
        let coordinate = CLLocation(latitude: 11, longitude: 13.3)

        var e2: XCTestExpectation!
        var e3: XCTestExpectation!
        geolocationServiceMock.onSubscriptionReceived = { [geolocationServiceMock] _ in
            subscribed.fulfill()
            e2 = geolocationReceived
            e3 = cancelled

            geolocationServiceMock.currentLocationPublished = .success(coordinate)
        }
        geolocationHandler = { _, body in
            try XCTAssertEqual(Response(body), Response(coordinate.removingAltitude()))
            e2.fulfill()
        }
        geolocationServiceMock.onSubscriptionCancelled = {
            e3.fulfill()
        }

        webView.loadHTMLString(Self.getCurrentPosition, baseURL: .duckDuckGo)
        NSApp.activate(ignoringOtherApps: true)
        webView.window?.orderFrontRegardless()

        waitForExpectations(timeout: 10.0)
        XCTAssertEqual(geolocationServiceMock.history, [.subscribed,
                                                        .locationPublished,
                                                        .cancelled])
    }

    func testWhenGeolocationContainsOptionalFieldsThenTheyAreAvailableInCallback() {
        let coordinate = CLLocation(coordinate: CLLocationCoordinate2D(latitude: -26.8, longitude: -54.1),
                                    altitude: 12.8,
                                    horizontalAccuracy: 0.8,
                                    verticalAccuracy: 0.9,
                                    course: 0.15,
                                    courseAccuracy: 0.5,
                                    speed: 123,
                                    speedAccuracy: 0.9,
                                    timestamp: Date())
        geolocationServiceMock.currentLocationPublished = .success(coordinate)

        let e = expectation(description: "location received")
        geolocationHandler = { _, body in
            try XCTAssertEqual(Response(body), Response(coordinate.removingAltitude()))
            e.fulfill()
        }

        webView.loadHTMLString(Self.getCurrentPosition, baseURL: .duckDuckGo)

        NSApp.activate(ignoringOtherApps: true)
        webView.window?.orderFrontRegardless()
        waitForExpectations(timeout: 10.0)
    }

    func testWhenGeolocationFailsThenErrorIsReceived() {
        struct TestError: Error {}
        geolocationServiceMock.currentLocationPublished = .failure(TestError())

        let e = expectation(description: "location received")
        geolocationHandler = { _, body in
            XCTAssertThrowsError(try Response(body))
            e.fulfill()
        }

        webView.loadHTMLString(Self.getCurrentPosition, baseURL: .duckDuckGo)
        NSApp.activate(ignoringOtherApps: true)
        webView.window?.orderFrontRegardless()

        waitForExpectations(timeout: 10.0)

    }

    func testWhenWatchGeolocationRequestedThenGeolocationIsContinuouslyProvided() {
        let location1 = CLLocation(latitude: 12.3, longitude: 0.1)
        let location2 = CLLocation(latitude: 10.1, longitude: -13.5)

        geolocationServiceMock.onSubscriptionReceived = { [geolocationServiceMock] _ in
            geolocationServiceMock.currentLocationPublished = .success(location1)
        }
        let e1 = expectation(description: "location1 received")
        let e2 = expectation(description: "location2 received")
        geolocationHandler = { [geolocationServiceMock, webView] _, body in
            if geolocationServiceMock.history == [.subscribed, .locationPublished] {
                geolocationServiceMock.currentLocationPublished = .success(location2)
                try XCTAssertEqual(Response(body), Response(location1.removingAltitude()))
                e1.fulfill()
            } else {
                try XCTAssertEqual(Response(body), Response(location2.removingAltitude()))
                webView!.evaluateJavaScript("clearWatch()") { _, error in
                    XCTAssertNil(error)
                    e2.fulfill()
                }
            }
        }

        webView.loadHTMLString(Self.watchPosition(), baseURL: .duckDuckGo)
        NSApp.activate(ignoringOtherApps: true)
        webView.window?.orderFrontRegardless()

        waitForExpectations(timeout: 10.0)

        XCTAssertEqual(geolocationServiceMock.history, [.subscribed,
                                                        .locationPublished,
                                                        .locationPublished,
                                                        .cancelled])
    }

    func testWhenHighAccuracyIsRequestedThenHighAccuracyIsActivated() {
        let e = expectation(description: "high accuracy requested")
        geolocationServiceMock.onHighAccuracyRequested = { _ in
            e.fulfill()
        }

        webView.loadHTMLString(Self.watchPosition(enableHighAccuracy: true), baseURL: .duckDuckGo)
        NSApp.activate(ignoringOtherApps: true)
        webView.window?.orderFrontRegardless()

        waitForExpectations(timeout: 5.0)

        XCTAssertEqual(geolocationServiceMock.history, [.highAccuracyRequested,
                                                        .subscribed])
    }

    func testWhenGeolocationWatchIsCancelledThenHighAccuracyIsReset() {
        geolocationServiceMock.onSubscriptionReceived = { [webView] _ in
            DispatchQueue.main.async {
                webView!.evaluateJavaScript("clearWatch()") { _, _ in }
            }
        }
        let e = expectation(description: "high accuracy cancelled")
        geolocationServiceMock.onHighAccuracyCancelled = {
            e.fulfill()
        }

        webView.loadHTMLString(Self.watchPosition(enableHighAccuracy: true), baseURL: .duckDuckGo)
        NSApp.activate(ignoringOtherApps: true)
        webView.window?.orderFrontRegardless()

        waitForExpectations(timeout: 5.0)

        XCTAssertEqual(geolocationServiceMock.history, [.highAccuracyRequested,
                                                        .subscribed,
                                                        .cancelled,
                                                        .highAccuracyCancelled])
    }

    func testWhenMultipleWebViewsRequestLocationThenItIsSubscribedAndCancelledCorrectly() {
        let webView2 = makeWebView()

        let location1 = CLLocation(latitude: 12.3, longitude: 0.1)
        let location2 = CLLocation(latitude: 10.1, longitude: -13.5)

        geolocationServiceMock.currentLocationPublished = .success(location1)
        geolocationServiceMock.onSubscriptionReceived = { [geolocationServiceMock] _ in
            if geolocationServiceMock.history == [.locationPublished, .subscribed, .subscribed] {
                DispatchQueue.main.async {
                    geolocationServiceMock.currentLocationPublished = .success(location2)
                }
            }
        }

        let e1_1 = expectation(description: "location1 received in webView1")
        let e1_2 = expectation(description: "location1 received in webView2")
        let e2_1 = expectation(description: "location2 received in webView1")
        let e2_2 = expectation(description: "location2 received in webView2")

        geolocationHandler = { [webView1=webView!] webView, body in
            switch (webView, try Response(body)) {
            case (webView1, Response(location1.removingAltitude())):
                e1_1.fulfill()
            case (webView2, Response(location1.removingAltitude())):
                e1_2.fulfill()
            case (webView1, Response(location2.removingAltitude())):
                e2_1.fulfill()
            case (webView2, Response(location2.removingAltitude())):
                e2_2.fulfill()
            default:
                XCTFail("Unexpected result")
            }
        }

        webView.loadHTMLString(Self.watchPosition(), baseURL: .duckDuckGo)
        webView2.loadHTMLString(Self.watchPosition(), baseURL: .duckDuckGo)
        NSApp.activate(ignoringOtherApps: true)
        webView.window?.orderFrontRegardless()
        webView2.window?.orderFrontRegardless()

        waitForExpectations(timeout: 10.0)

        let ec1 = expectation(description: "watch 1 cancelled")
        let ec2 = expectation(description: "watch 2 cancelled")
        webView.evaluateJavaScript("clearWatch()") { _, _ in
            ec1.fulfill()
        }
        webView2.evaluateJavaScript("clearWatch()") { _, _ in
            ec2.fulfill()
        }
        waitForExpectations(timeout: 3.0)

        XCTAssertEqual(geolocationServiceMock.history, [.locationPublished,
                                                        .subscribed,
                                                        .subscribed,
                                                        .locationPublished,
                                                        .cancelled,
                                                        .cancelled])
    }

    func testWhenGeolocationProviderIsPausedThenLocationSubscriptionIsCancelled() {
        let location1 = CLLocation(latitude: 12.3, longitude: 0.1)

        geolocationServiceMock.currentLocationPublished = .success(location1)

        geolocationServiceMock.onSubscriptionReceived = { [webView] _ in
            DispatchQueue.main.async {
                webView!.configuration.processPool.geolocationProvider!.isPaused = true
            }
        }
        let e = expectation(description: "subscription cancelled")
        geolocationServiceMock.onSubscriptionCancelled = {
            e.fulfill()
        }

        webView.loadHTMLString(Self.watchPosition(), baseURL: .duckDuckGo)
        NSApp.activate(ignoringOtherApps: true)
        webView.window?.orderFrontRegardless()

        waitForExpectations(timeout: 10.0)

        XCTAssertEqual(geolocationServiceMock.history, [.locationPublished,
                                                        .subscribed,
                                                        .cancelled])
    }

    func testWhenAppIsDeactivatedThenLocationSubscriptionIsCancelled() {
        let location1 = CLLocation(latitude: 12.3, longitude: 0.1)

        geolocationServiceMock.currentLocationPublished = .success(location1)
        let e = expectation(description: "re-subscribed")
        geolocationServiceMock.onSubscriptionReceived = { [geolocationServiceMock] _ in
            if geolocationServiceMock.history == [.locationPublished, .subscribed] {
                DispatchQueue.main.async {
                    self.appIsActive.send(false)
                }
            } else if geolocationServiceMock.history == [.locationPublished, .subscribed, .cancelled, .subscribed] {
                e.fulfill()
            } else {
                XCTFail("Unexpected call sequence")
            }
        }
        geolocationServiceMock.onSubscriptionCancelled = {
            DispatchQueue.main.async {
                self.appIsActive.send(true)
            }
        }

        webView.loadHTMLString(Self.watchPosition(), baseURL: .duckDuckGo)
        NSApp.activate(ignoringOtherApps: true)
        webView.window?.orderFrontRegardless()

        waitForExpectations(timeout: 10.0)

        XCTAssertEqual(geolocationServiceMock.history, [.locationPublished,
                                                        .subscribed,
                                                        .cancelled,
                                                        .subscribed])
    }

    func testWhenOneWebViewGeolocationIsPausedThenAnotherWebViewContinuesReceivingLocationUpdates() {
        let webView2 = makeWebView()

        let location1 = CLLocation(latitude: 12.3, longitude: 0.1)
        let location2 = CLLocation(latitude: 10.1, longitude: -13.5)

        geolocationServiceMock.currentLocationPublished = .success(location1)
        geolocationServiceMock.onSubscriptionReceived = { [geolocationServiceMock] _ in
            if geolocationServiceMock.history == [.locationPublished, .subscribed, .subscribed] {
                DispatchQueue.main.async {
                    webView2.configuration.processPool.geolocationProvider!.isPaused = true
                    geolocationServiceMock.currentLocationPublished = .success(location2)
                }
            }
        }

        let e1_1 = expectation(description: "location1 received in webView1")
        let e1_2 = expectation(description: "location1 received in webView2")
        let e2_1 = expectation(description: "location2 received in webView1")

        geolocationHandler = { [webView1=webView!] webView, body in
            switch (webView, try Response(body)) {
            case (webView1, Response(location1.removingAltitude())):
                e1_1.fulfill()
            case (webView2, Response(location1.removingAltitude())):
                e1_2.fulfill()
            case (webView1, Response(location2.removingAltitude())):
                e2_1.fulfill()
            case (webView2, Response(location2.removingAltitude())):
                XCTFail("webView2 Unexpectedly received location")
            default:
                XCTFail("Unexpected result")
            }
        }

        webView.loadHTMLString(Self.watchPosition(), baseURL: .duckDuckGo)
        webView2.loadHTMLString(Self.watchPosition(), baseURL: .duckDuckGo)
        NSApp.activate(ignoringOtherApps: true)
        webView.window?.orderFrontRegardless()
        webView2.window?.orderFrontRegardless()

        waitForExpectations(timeout: 10.0)

        let ec1 = expectation(description: "watch 1 cancelled")
        let ec2 = expectation(description: "watch 2 cancelled")
        webView.evaluateJavaScript("clearWatch()") { _, _ in
            ec1.fulfill()
        }
        webView2.evaluateJavaScript("clearWatch()") { _, _ in
            ec2.fulfill()
        }
        waitForExpectations(timeout: 3.0)

        XCTAssertEqual(geolocationServiceMock.history, [.locationPublished,
                                                        .subscribed,
                                                        .subscribed,
                                                        .cancelled,
                                                        .locationPublished,
                                                        .cancelled])
    }

    func testWhenGeolocationProviderIsResumedThenItContinuesReceivingLocation() {
        let location1 = CLLocation(latitude: 12.3, longitude: 0.1)
        let location2 = CLLocation(latitude: 10.1, longitude: -13.5)
        geolocationServiceMock.currentLocationPublished = .success(location1)

        let e = expectation(description: "received location2")
        geolocationHandler = { [geolocationServiceMock] webView, body in
            XCTAssertFalse(webView.configuration.processPool.geolocationProvider!.isPaused)
            switch try Response(body) {
            case Response(location1.removingAltitude()):
                webView.configuration.processPool.geolocationProvider!.isPaused = true
                geolocationServiceMock.currentLocationPublished = .success(location2)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    webView.configuration.processPool.geolocationProvider!.isPaused = false
                }
            case Response(location2.removingAltitude()):
                e.fulfill()
            default:
                XCTFail("Unexpected result")
            }
        }

        webView.loadHTMLString(Self.watchPosition(), baseURL: .duckDuckGo)
        NSApp.activate(ignoringOtherApps: true)
        webView.window?.orderFrontRegardless()

        waitForExpectations(timeout: 10.0)

        XCTAssertEqual(geolocationServiceMock.history, [.locationPublished,
                                                        .subscribed,
                                                        .cancelled,
                                                        .locationPublished,
                                                        .subscribed])
    }

    func testWhenWebViewIsHiddenThenItStopsGeolocationProvider() {
        let location1 = CLLocation(latitude: 12.3, longitude: 0.1)
        let location2 = CLLocation(latitude: 10.1, longitude: -13.5)
        geolocationServiceMock.currentLocationPublished = .success(location1)

        geolocationHandler = { webView, body in
            XCTAssertFalse(webView.configuration.processPool.geolocationProvider!.isPaused)
            switch try Response(body) {
            case Response(location1.removingAltitude()):
                webView.removeFromSuperview()
            default:
                XCTFail("Unexpected result")
            }
        }
        let e = expectation(description: "subscription cancelled")
        geolocationServiceMock.onSubscriptionCancelled = { [geolocationServiceMock] in
            geolocationServiceMock.currentLocationPublished = .success(location2)
            e.fulfill()
        }

        webView.loadHTMLString(Self.watchPosition(), baseURL: .duckDuckGo)
        NSApp.activate(ignoringOtherApps: true)
        webView.window?.orderFrontRegardless()

        waitForExpectations(timeout: 5)

        let e2 = expectation(description: "subscription received again")
        let e3 = expectation(description: "location2 received")
        geolocationServiceMock.onSubscriptionReceived = { _ in
            e2.fulfill()
        }
        geolocationHandler = { webView, body in
            XCTAssertFalse(webView.configuration.processPool.geolocationProvider!.isPaused)
            switch try Response(body) {
            case Response(location2.removingAltitude()):
                e3.fulfill()
            default:
                XCTFail("Unexpected result")
            }
        }
        windows[0].contentView!.addSubview(webView)
        waitForExpectations(timeout: 5)

        XCTAssertEqual(geolocationServiceMock.history, [.locationPublished,
                                                        .subscribed,
                                                        .cancelled,
                                                        .locationPublished,
                                                        .subscribed])
    }

    func testWhenPermissionIsDeniedThenGeolocationProviderIsNotStarted() {
        shouldGrant = false
        geolocationServiceMock.onSubscriptionReceived = { _ in
            XCTFail("Unexpected subscription received")
        }
        let e = expectation(description: "provider receives error")
        geolocationHandler = { _, body in
            XCTAssertThrowsError(try Response(body))
            e.fulfill()
        }

        webView.loadHTMLString(Self.getCurrentPosition, baseURL: .duckDuckGo)
        NSApp.activate(ignoringOtherApps: true)
        webView.window?.orderFrontRegardless()

        waitForExpectations(timeout: 5)
    }

    func testWhenGeolocationPermissionRevokedThenErrorIsReceived() {
        let location1 = CLLocation(latitude: 12.3, longitude: 0.1)
        let location2 = CLLocation(latitude: 10.1, longitude: -13.5)
        geolocationServiceMock.currentLocationPublished = .success(location1)

        let e1 = expectation(description: "location received")
        geolocationHandler = { webView, body in
            XCTAssertEqual(try Response(body), Response(location1.removingAltitude()))
            webView.revokePermissions(.geolocation)
            e1.fulfill()
        }
        let e2 = expectation(description: "subscription cancelled")
        geolocationServiceMock.onSubscriptionCancelled = { [geolocationServiceMock] in
            geolocationServiceMock.currentLocationPublished = .success(location2)
            e2.fulfill()
        }

        webView.loadHTMLString(Self.watchPosition(), baseURL: .duckDuckGo)
        NSApp.activate(ignoringOtherApps: true)
        webView.window?.orderFrontRegardless()

        waitForExpectations(timeout: 5)

        let e3 = expectation(description: "provider received error")
        geolocationHandler = { _, body in
            XCTAssertThrowsError(try Response(body))
            e3.fulfill()
        }
        webView.loadHTMLString(Self.watchPosition(), baseURL: .duckDuckGo)
        NSApp.activate(ignoringOtherApps: true)
        webView.window?.orderFrontRegardless()

        waitForExpectations(timeout: 5)

        XCTAssertEqual(geolocationServiceMock.history, [.locationPublished,
                                                        .subscribed,
                                                        .cancelled,
                                                        .locationPublished])
    }

    func testWhenGeolocationPermissionRevokedBeforeLocationRequestThenErrorIsReceivedAfterRequest() {
        let location = CLLocation(latitude: 12.3, longitude: 0.1)
        geolocationServiceMock.currentLocationPublished = .success(location)

        geolocationServiceMock.onSubscriptionReceived = { _ in
            XCTFail("Unexpected subscription received")
        }
        let e = expectation(description: "provider receives error")
        geolocationHandler = { _, body in
            XCTAssertThrowsError(try Response(body))
            e.fulfill()
        }
        webView.configuration.processPool.geolocationProvider!.revoke()

        webView.loadHTMLString(Self.getCurrentPosition, baseURL: .duckDuckGo)
        NSApp.activate(ignoringOtherApps: true)
        webView.window?.orderFrontRegardless()

        waitForExpectations(timeout: 5)

        XCTAssertEqual(geolocationServiceMock.history, [.locationPublished])
    }

    func testWhenGeolocationProviderIsResetThenItCanReceiveLocation() {
        let location = CLLocation(latitude: 12.3, longitude: 0.1)
        geolocationServiceMock.currentLocationPublished = .success(location)

        let e = expectation(description: "provider received error")
        geolocationHandler = { _, body in
            XCTAssertThrowsError(try Response(body))
            e.fulfill()
        }
        webView.configuration.processPool.geolocationProvider!.revoke()

        webView.loadHTMLString(Self.getCurrentPosition, baseURL: .duckDuckGo)
        NSApp.activate(ignoringOtherApps: true)
        webView.window?.orderFrontRegardless()

        waitForExpectations(timeout: 5)

        let e2 = expectation(description: "received location")
        let e3 = expectation(description: "received cancel")
        geolocationHandler = { webView, body in
            XCTAssertEqual(try Response(body), Response(location.removingAltitude()))
            e2.fulfill()
            webView.removeFromSuperview()
        }
        geolocationServiceMock.onSubscriptionCancelled = {
            e3.fulfill()
        }
        webView.configuration.processPool.geolocationProvider!.reset()
        webView.loadHTMLString(Self.getCurrentPosition, baseURL: .duckDuckGo)
        NSApp.activate(ignoringOtherApps: true)
        webView.window?.orderFrontRegardless()

        waitForExpectations(timeout: 5)
        XCTAssertEqual(geolocationServiceMock.history, [.locationPublished, .subscribed, .cancelled])
    }

}

extension GeolocationProviderTests: WKUIDelegate {
    @objc(_webView:requestGeolocationPermissionForFrame:decisionHandler:)
    func webView(_ webView: WKWebView, requestGeolocationPermissionFor frame: WKFrameInfo, decisionHandler: @escaping (Bool) -> Void) {
        decisionHandler(shouldGrant)
    }

    @objc(_webView:requestGeolocationPermissionForOrigin:initiatedByFrame:decisionHandler:)
    @available(macOS 12, *)
    func webView(_ webView: WKWebView,
                 requestGeolocationPermissionFor origin: WKSecurityOrigin,
                 initiatedBy frame: WKFrameInfo,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(shouldGrant ? .grant : .deny)
    }
}

extension GeolocationProviderTests: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let webView = webViews.first(where: { $0.configuration.userContentController === userContentController })!
        XCTAssertNoThrow(try geolocationHandler?(webView, message.body))

    }
}

extension GeolocationProviderTests {
    struct Response: Equatable {

        struct ResponseError: Error {
            let code: Int
            let message: String
        }

        let latitude: Double?
        let longitude: Double?
        let altitude: Double?
        let accuracy: Double?
        let altitudeAccuracy: Double?
        let heading: Double?
        let speed: Double?
        let timestamp: Int

        init(_ location: CLLocation) {
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
            self.altitude = location.verticalAccuracy >= 0 ? location.altitude : nil
            self.accuracy = location.horizontalAccuracy
            self.altitudeAccuracy = location.verticalAccuracy >= 0 ? location.verticalAccuracy : nil
            self.heading = location.course >= 0 ? location.course : nil
            self.speed = location.speed >= 0.0 ? location.speed : nil
            self.timestamp = Int(location.timestamp.timeIntervalSinceReferenceDate * 1000)
        }

        init(_ object: Any) throws {
            guard let dict = object as? [String: Any] else {
                fatalError("Unexpected type of \(object)")
            }

            guard let coords = dict["coordinates"] as? [String: Any],
                  let timestamp = dict["timestamp"] as? Double
            else {
                if let code = dict["code"] as? Int,
                   let message = dict["message"] as? String {
                    throw ResponseError(code: code, message: message)
                }
                fatalError("Unexpected \(dict)")
            }

            func decode(_ key: String) throws -> Double? {
                guard let value = coords[key] else { fatalError("Key not found \(key)") }
                if value is NSNull {
                    return nil
                } else if let value = value as? Double {
                    return value
                } else {
                    fatalError("Unexpected value \(value)")
                }
            }
            latitude = try decode("latitude")
            longitude = try decode("longitude")
            altitude = try decode("altitude")
            accuracy = try decode("accuracy")
            altitudeAccuracy = try decode("altitudeAccuracy")
            heading = try decode("heading")
            speed = try decode("speed")

            self.timestamp = Int(timestamp)
        }

    }
}
extension CLLocation {
    func removingAltitude() -> CLLocation {
        return CLLocation(coordinate: coordinate,
                          altitude: -1,
                          horizontalAccuracy: horizontalAccuracy,
                          verticalAccuracy: -1,
                          course: course,
                          courseAccuracy: courseAccuracy,
                          speed: speed,
                          speedAccuracy: speedAccuracy,
                          timestamp: timestamp)
    }
}
