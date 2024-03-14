//
//  GeolocationServiceTests.swift
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
@testable import DuckDuckGo_Privacy_Browser

final class GeolocationServiceTests: XCTestCase {
    var locationManagerMock: CLLocationManagerMock!
    lazy var service: GeolocationService = {
        GeolocationService(locationManager: locationManagerMock)
    }()

    override func setUp() {
        CLLocationManagerMock.authStatus = .notDetermined
        CLLocationManagerMock.systemLocationServicesEnabled = false
        locationManagerMock = CLLocationManagerMock()
    }

    func testWhenGeolocationServiceInitThenNoLocationIsSet() {
        XCTAssertNil(service.currentLocation)
        XCTAssertFalse(locationManagerMock.isUpdatingLocation)
        XCTAssertFalse(locationManagerMock.isUpdatingHeading)
    }

    func testWhenAuthorizationStatusChangedThenItIsPublished() {
        let e1 = expectation(description: "expect notDetermined")
        var e2: XCTestExpectation!
        var e3: XCTestExpectation!
        let c = service.authorizationStatusPublisher.sink { status in
            switch status {
            case .notDetermined:
                e1.fulfill()
            case .authorized:
                e2.fulfill()
            case .restricted:
                e3.fulfill()
            default:
                XCTFail("unexpected status")
            }
        }
        waitForExpectations(timeout: 0)

        e2 = expectation(description: "expect authorized")
        CLLocationManagerMock.authStatus = .authorized
        e3 = expectation(description: "expect restricted")
        CLLocationManagerMock.authStatus = .restricted

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenLocationServicesEnabledChangesThenAuthorizationStatusIsPublished() {
        let e1 = expectation(description: "expect false")
        var e2: XCTestExpectation!
        var e3: XCTestExpectation!
        let c = service.authorizationStatusPublisher.sink { [service] status in
            XCTAssertEqual(status, .notDetermined)
            switch service.locationServicesEnabled() {
            case false:
                if e3 == nil {
                    e1.fulfill()
                } else {
                    e3.fulfill()
                }
            case true:
                e2.fulfill()
            }
        }
        waitForExpectations(timeout: 0)

        e2 = expectation(description: "expect true")
        CLLocationManagerMock.systemLocationServicesEnabled = true
        e3 = expectation(description: "expect false")
        CLLocationManagerMock.systemLocationServicesEnabled = false

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenSubscribedThenLocationIsPublished() {
        let loc1 = CLLocation(latitude: 51.1, longitude: 23.4)
        let loc2 = CLLocation(latitude: 11.1, longitude: -12.2)
        struct TestError: Error {}
        let error = TestError()
        let e1 = expectation(description: "expect nil")
        var e2: XCTestExpectation!
        var e3: XCTestExpectation!
        var e4: XCTestExpectation!
        CLLocationManagerMock.authStatus = .authorized
        let c = service.locationPublisher.sink { result in
            switch result {
            case .none:
                e1.fulfill()
            case .success(loc1):
                e2.fulfill()
            case .success(loc2):
                e3.fulfill()
            case .failure(_ as TestError):
                e4.fulfill()
            default:
                XCTFail("unexpected result")
            }
        }
        waitForExpectations(timeout: 0)

        e2 = expectation(description: "expect loc1")
        locationManagerMock.currentLocation = loc1
        e3 = expectation(description: "expect false")
        locationManagerMock.currentLocation = loc2
        e4 = expectation(description: "expect error")
        locationManagerMock.error = error

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenManySubscribedThenLocationIsPublished() {
        let location = CLLocation(latitude: 51.1, longitude: 23.4)
        struct TestError: Error {}

        let enil1 = expectation(description: "expect nil 1")
        let eloc1 = expectation(description: "expect loc 1")
        let eerr1 = expectation(description: "expect err 1")
        CLLocationManagerMock.authStatus = .authorized
        let c1 = service.locationPublisher.sink { result in
            switch result {
            case .none:
                enil1.fulfill()
            case .success(location):
                eloc1.fulfill()
            case .failure(_ as TestError):
                eerr1.fulfill()
            default:
                XCTFail("Unexpected result")
            }
        }
        let enil2 = expectation(description: "expect nil 2")
        let eloc2 = expectation(description: "expect loc 2")
        let eerr2 = expectation(description: "expect err 2")
        let c2 = service.locationPublisher.sink { result in
            switch result {
            case .none:
                enil2.fulfill()
            case .success(location):
                eloc2.fulfill()
            case .failure(_ as TestError):
                eerr2.fulfill()
            default:
                XCTFail("Unexpected result")
            }
        }

        let enil3 = expectation(description: "expect nil 3")
        let eloc3 = expectation(description: "expect loc 3")
        let eerr3 = expectation(description: "expect err 3")
        let c3 = service.locationPublisher.sink { result in
            switch result {
            case .none:
                enil3.fulfill()
            case .success(location):
                eloc3.fulfill()
            case .failure(_ as TestError):
                eerr3.fulfill()
            default:
                XCTFail("Unexpected result")
            }
        }

        locationManagerMock.currentLocation = location
        locationManagerMock.error = TestError()

        withExtendedLifetime([c1, c2, c3]) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenLastSubscriberUnsubscribedThenLocationManagerStopped() {
        let eAuthRequested = expectation(description: "Authorization requested")
        locationManagerMock.whenInUseAuthorizationRequested = { eAuthRequested.fulfill() }

        let c1 = service.locationPublisher.sink { _ in }
        _=service.locationPublisher.sink { _ in }
        waitForExpectations(timeout: 0)

        let c3 = service.locationPublisher.sink { [locationManagerMock] _ in
            XCTAssertTrue(locationManagerMock!.isUpdatingLocation)
        }
        locationManagerMock.currentLocation = CLLocation(latitude: 51.1, longitude: 23.4)
        c1.cancel()
        c3.cancel()
        XCTAssertFalse(locationManagerMock!.isUpdatingLocation)
    }

    func testWhenLastSubscriberPresentThenLocationIsUpdated() {
        let loc1 = CLLocation(latitude: 51.1, longitude: 23.4)
        let loc2 = CLLocation(latitude: 11.1, longitude: -12.2)

        let eAuthRequested = expectation(description: "Authorization requested")
        locationManagerMock.whenInUseAuthorizationRequested = { eAuthRequested.fulfill() }
        let c1 = service.locationPublisher.sink { _ in }
        var c2: AnyCancellable! = service.locationPublisher.sink { _ in }
        let e = expectation(description: "expect still receiving location")
        let c3 = service.locationPublisher.sink { [locationManagerMock] result in
            XCTAssertTrue(locationManagerMock!.isUpdatingLocation)
            if case .success(loc2) = result {
                e.fulfill()
            }
        }
        locationManagerMock.currentLocation = loc1
        c1.cancel()
        c2.cancel()
        c2.cancel()
        c2 = nil

        locationManagerMock.currentLocation = loc2
        waitForExpectations(timeout: 1)

        c3.cancel()
        XCTAssertFalse(locationManagerMock!.isUpdatingLocation)
    }

    func testWhenResubscribedThenLastLocationIsPublished() {
        let location = CLLocation(latitude: 51.1, longitude: 23.4)
        locationManagerMock.whenInUseAuthorizationRequested = { }
        let c1 = service.locationPublisher.sink { _ in }
        locationManagerMock.currentLocation = location
        c1.cancel()

        let e = expectation(description: "expect location")
        _=service.locationPublisher.sink {
            guard case .success(location) = $0 else { XCTFail("Unexpected result"); return }
            e.fulfill()
        }

        waitForExpectations(timeout: 0)
    }

    func testWhenStoppedThenNoErrorIsPublished() {
        let location = CLLocation(latitude: 51.1, longitude: 23.4)
        locationManagerMock.whenInUseAuthorizationRequested = { }
        let c1 = service.locationPublisher.sink { _ in }
        locationManagerMock.currentLocation = location
        c1.cancel()

        struct TestError: Error {}
        locationManagerMock.currentLocation = nil
        locationManagerMock.error = TestError()
        let e = expectation(description: "expect location")
        _=service.locationPublisher.sink {
            guard case .success(location) = $0 else { XCTFail("Unexpected result"); return }
            e.fulfill()
        }

        waitForExpectations(timeout: 0)
    }

    func testWhenHighAccuracyRequestedThenAccuracyIsSetToBest() {
        let eAuthRequested = expectation(description: "Authorization requested")
        locationManagerMock.whenInUseAuthorizationRequested = { eAuthRequested.fulfill() }
        let c1 = service.locationPublisher.sink { _ in }
        XCTAssertEqual(locationManagerMock.desiredAccuracy, kCLLocationAccuracyHundredMeters)

        let c2 = service.highAccuracyPublisher.sink { _ in }
        XCTAssertEqual(locationManagerMock.desiredAccuracy, kCLLocationAccuracyBest)

        c2.cancel()
        XCTAssertEqual(locationManagerMock.desiredAccuracy, kCLLocationAccuracyHundredMeters)
        withExtendedLifetime(c1) {}
        waitForExpectations(timeout: 0)
    }

}
