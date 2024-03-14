//
//  CLLocationManagerMock.swift
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
import CoreLocation

final class CLLocationManagerMock: CLLocationManager {
    private static var instances = [NSValue]()
    private var selfRef: NSValue!

    static var authStatus: CLAuthorizationStatus = .notDetermined {
        didSet {
            for value in instances {
                guard let instance = value.nonretainedObjectValue as? CLLocationManagerMock else { fatalError() }
                instance.delegate?.locationManagerDidChangeAuthorization?(instance)
            }
        }
    }
    static var systemLocationServicesEnabled: Bool = false {
        didSet {
            for value in instances {
                guard let instance = value.nonretainedObjectValue as? CLLocationManagerMock else { fatalError() }
                instance.delegate?.locationManagerDidChangeAuthorization?(instance)
            }
        }
    }

    var isUpdatingLocation = false
    var isUpdatingHeading = false

    override init() {
        super.init()

        selfRef = NSValue(nonretainedObject: self)
        Self.instances.append(selfRef)
    }

    deinit {
        Self.instances.remove(at: Self.instances.firstIndex(of: selfRef)!)
    }

    override var authorizationStatus: CLAuthorizationStatus {
        Self.authStatus
    }

    override class func locationServicesEnabled() -> Bool {
        systemLocationServicesEnabled
    }

    var currentLocation: CLLocation? {
        didSet {
            if isUpdatingLocation,
               let location = currentLocation {
                delegate?.locationManager?(self, didUpdateLocations: [location])
            }
        }
    }
    var error: Error? {
        didSet {
            if isUpdatingLocation,
               let error = error {
                delegate?.locationManager?(self, didFailWithError: error)
            }
        }
    }

    override var location: CLLocation? {
        currentLocation
    }

    override func startUpdatingLocation() {
        assert(!isUpdatingLocation)
        isUpdatingLocation = true
        isUpdatingHeading = true
        if let location = currentLocation {
            delegate?.locationManager?(self, didUpdateLocations: [location])
        }
    }

    override func stopUpdatingLocation() {
        assert(isUpdatingLocation)
        isUpdatingLocation = false
        isUpdatingHeading = false
    }

    override func startUpdatingHeading() {
        assert(!isUpdatingHeading)
        isUpdatingHeading = true
    }

    override func requestLocation() {
        fatalError("Unexpected call")
    }

    var whenInUseAuthorizationRequested: (() -> Void)!
    override func requestWhenInUseAuthorization() {
        whenInUseAuthorizationRequested!()
    }

    override func requestAlwaysAuthorization() {
        fatalError("Unexpected call")
    }

    override func requestTemporaryFullAccuracyAuthorization(withPurposeKey purposeKey: String, completion: (((any Error)?) -> Void)? = nil) {
        fatalError("Unexpected call")
    }

}
