//
//  GeolocationService.swift
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
import CoreLocation

protocol GeolocationServiceProtocol: AnyObject {
    var currentLocation: Result<CLLocation, Error>? { get }
    var locationPublisher: AnyPublisher<Result<CLLocation, Error>?, Never> { get }
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> { get }
}

final class GeolocationService: NSObject, GeolocationServiceProtocol {
    static let shared = GeolocationService()

    private let locationManager: CLLocationManager

    @Published private var currentLocationPublished: Result<CLLocation, Error>?
    @Published private var authorizationStatus: CLAuthorizationStatus
    private var locationPublisherEventsHandler: AnyPublisher<Result<CLLocation, Error>?, Never>!

    var currentLocation: Result<CLLocation, Error>? {
        currentLocationPublished
    }
    var locationPublisher: AnyPublisher<Result<CLLocation, Error>?, Never> {
        locationPublisherEventsHandler
    }
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        $authorizationStatus.eraseToAnyPublisher()
    }
    private(set) var locationServicesEnabled: () -> Bool

    init(locationManager: CLLocationManager = .init()) {
        self.locationManager = locationManager
        self.authorizationStatus = type(of: locationManager).authorizationStatus()
        self.locationServicesEnabled = type(of: locationManager).locationServicesEnabled
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        setupEventsHandler()
    }

    private func setupEventsHandler() {
        locationPublisherEventsHandler = $currentLocationPublished
            .handleEvents(receiveSubscription: self.didReceiveSubscription, receiveCancel: self.didReceiveCancel)
            .eraseToAnyPublisher()
    }

    private var subscriptionCounter = 0 {
        didSet {
            assert(subscriptionCounter >= 0)
            switch (oldValue, subscriptionCounter) {
            case (0, 1):
                locationManager.startUpdatingLocation()
            case (1, 0):
                locationManager.stopUpdatingLocation()
                if case .failure = currentLocation {
                    currentLocationPublished = nil
                }
            default: break
            }
        }
    }

    private func didReceiveSubscription(_ s: Subscription) {
        subscriptionCounter += 1
    }

    private func didReceiveCancel() {
        subscriptionCounter -= 1
    }

}

extension GeolocationService: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.authorizationStatus = status
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            currentLocationPublished = .success(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard subscriptionCounter > 0 else { return }
        currentLocationPublished = .failure(error)
    }

}
