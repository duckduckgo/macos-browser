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
    var locationServicesEnabled: () -> Bool { get }

    var authorizationStatus: CLAuthorizationStatus { get }
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> { get }

    var highAccuracyPublisher: AnyPublisher<Void, Never> { get }
}

final class GeolocationService: NSObject, GeolocationServiceProtocol {
    static let shared = GeolocationService()

    private let locationManager: CLLocationManager

    @PublishedAfter private var currentLocationPublished: Result<CLLocation, Error>?
    @PublishedAfter private(set) var authorizationStatus: CLAuthorizationStatus {
        didSet {
            if case .notDetermined = oldValue,
               [.denied, .restricted].contains(authorizationStatus) {
                currentLocationPublished = .failure(CLError(.denied))
            }
        }
    }

    private var locationPublisherEventsHandler: AnyPublisher<Result<CLLocation, Error>?, Never>!
    private var highAccuracyEventsHandler: AnyPublisher<Void, Never>!

    var currentLocation: Result<CLLocation, Error>? {
        currentLocationPublished
    }
    var locationPublisher: AnyPublisher<Result<CLLocation, Error>?, Never> {
        locationPublisherEventsHandler
    }
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        $authorizationStatus.eraseToAnyPublisher()
    }
    var highAccuracyPublisher: AnyPublisher<Void, Never> {
        highAccuracyEventsHandler
    }
    private(set) var locationServicesEnabled: () -> Bool

    init(locationManager: CLLocationManager = .init()) {
        self.locationManager = locationManager
        self.authorizationStatus = locationManager.authorizationStatus
        self.locationServicesEnabled = type(of: locationManager).locationServicesEnabled
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        setupEventsHandlers()
    }

    private func setupEventsHandlers() {
        locationPublisherEventsHandler = $currentLocationPublished
            .handleEvents(receiveSubscription: self.didReceiveGeolocationSubscription,
                          receiveCancel: self.didReceiveGeolocationCancel)
            .eraseToAnyPublisher()
        highAccuracyEventsHandler = $currentLocationPublished.map { _ in }
            .handleEvents(receiveSubscription: self.didReceiveHighAccuracySubscription,
                          receiveCancel: self.didReceiveHighAccuracyCancel)
            .eraseToAnyPublisher()
    }

    private var geolocationSubscriptionCounter = 0 {
        didSet {
            assert(geolocationSubscriptionCounter >= 0)
            switch (oldValue, geolocationSubscriptionCounter) {
            case (0, 1):
                if case .notDetermined = authorizationStatus {
                    locationManager.requestWhenInUseAuthorization()
                }
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

    private func didReceiveGeolocationSubscription(_ s: Subscription) {
        geolocationSubscriptionCounter += 1
    }

    private func didReceiveGeolocationCancel() {
        geolocationSubscriptionCounter -= 1
    }

    private var highAccuracySubscriptionCounter = 0 {
        didSet {
            assert(highAccuracySubscriptionCounter >= 0)
            switch (oldValue, highAccuracySubscriptionCounter) {
            case (0, 1):
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
            case (1, 0):
                locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            default: break
            }
        }
    }

    private func didReceiveHighAccuracySubscription(_ s: Subscription) {
        highAccuracySubscriptionCounter += 1
    }

    private func didReceiveHighAccuracyCancel() {
        highAccuracySubscriptionCounter -= 1
    }

}

extension GeolocationService: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            currentLocationPublished = .success(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard geolocationSubscriptionCounter > 0, authorizationStatus != .notDetermined else { return }
        if case .success = currentLocationPublished,
           error as? CLError == CLError(.locationUnknown) {
            return
        }
        currentLocationPublished = .failure(error)
    }

}
