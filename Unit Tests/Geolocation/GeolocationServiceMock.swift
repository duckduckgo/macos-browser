//
//  GeolocationServiceMock.swift
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
@testable import DuckDuckGo_Privacy_Browser

final class GeolocationServiceMock: GeolocationServiceProtocol {

    enum CallHistoryItem: Equatable {
        case subscribed
        case locationPublished
        case cancelled
        case highAccuracyRequested
        case highAccuracyCancelled
    }
    var history = [CallHistoryItem]()

    @PublishedAfter var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @PublishedAfter var currentLocationPublished: Result<CLLocation, Error>? {
        willSet {
            history.append(.locationPublished)
        }
    }
    private var locationPublisherEventsHandler: AnyPublisher<Result<CLLocation, Error>?, Never>!
    private var highAccuracyEventsHandler: AnyPublisher<Void, Never>!

    var onSubscriptionReceived: ((Subscription) -> Void)?
    var onSubscriptionCancelled: (() -> Void)?

    var onHighAccuracyRequested: ((Subscription) -> Void)?
    var onHighAccuracyCancelled: (() -> Void)?

    init() {
        locationPublisherEventsHandler = $currentLocationPublished
            .handleEvents(receiveSubscription: self.didReceiveSubscription, receiveCancel: self.didReceiveCancel)
            .eraseToAnyPublisher()
        highAccuracyEventsHandler = $currentLocationPublished.map { _ in }
            .handleEvents(receiveSubscription: self.didReceiveHighAccuracySubscription,
                          receiveCancel: self.didReceiveHighAccuracyCancel)
            .eraseToAnyPublisher()
    }

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

    var locationServicesEnabledValue = true {
        didSet {
            authorizationStatus = (authorizationStatus)
        }
    }
    var locationServicesEnabled: () -> Bool {
        { self.locationServicesEnabledValue }
    }

    private func didReceiveSubscription(_ s: Subscription) {
        history.append(.subscribed)
        onSubscriptionReceived?(s)
    }

    private func didReceiveCancel() {
        history.append(.cancelled)
        onSubscriptionCancelled?()
    }

    private func didReceiveHighAccuracySubscription(_ s: Subscription) {
        history.append(.highAccuracyRequested)
        onHighAccuracyRequested?(s)
    }
    private func didReceiveHighAccuracyCancel() {
        history.append(.highAccuracyCancelled)
        onHighAccuracyCancelled?()
    }

}
