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
@testable import DuckDuckGo_Privacy_Browser

extension GeolocationServiceTests: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print(manager, locations)
//        if !cancelled {
//            manager.stopUpdatingLocation()
//            cancelled = true
//        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print(manager, "didChangeAuth", CLLocationManager.locationServicesEnabled(), CLLocationManager.authorizationStatus().rawValue)
    }
}
final class GeolocationServiceTests: XCTestCase {
    var cancelled = false

    func testG() {
        let lm1 = CLLocationManager()
        let lm2 = CLLocationManager()

        print("auth", CLLocationManager.authorizationStatus().rawValue)
        print("locationServicesEnabled", CLLocationManager.locationServicesEnabled())
//        lm1.requestAlwaysAuthorization()

        lm1.delegate = self
        lm2.delegate = self

        lm1.startUpdatingLocation()
        lm2.startUpdatingLocation()

        RunLoop.current.run(until: Date().addingTimeInterval(3.0))

        lm1.stopUpdatingLocation()
        lm2.stopUpdatingLocation()

    }

    func testGeo() {
        let locationManager = CLLocationManagerMock()
        let service = GeolocationService(locationManager: locationManager)

//        let e = expectation(description: "location received")
        let c = service.locationPublisher.sink { location in
            print("c1", location)
        }
        let c2 = service.locationPublisher.sink { location in
            print("c2", location)
        }

        c.cancel()
        c.cancel()

        let c3 = service.locationPublisher.sink { location in
            print("c3", location)
        }

        c2.cancel()
        c3.cancel()

        let c4 = service.locationPublisher.sink { location in
            print("c4", location)
        }

        c4.cancel()
//        withExtendedLifetime(c) {
//            waitForExpectations(timeout: 1)
//        }

    }

}
