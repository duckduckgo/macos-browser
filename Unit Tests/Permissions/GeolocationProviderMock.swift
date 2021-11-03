//
//  GeolocationProviderMock.swift
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

final class GeolocationProviderMock: GeolocationProviderProtocol {
    private let geolocationService: GeolocationServiceProtocol

    var onRevoke: (() -> Void)?
    var onReset: (() -> Void)?

    init(geolocationService: GeolocationServiceProtocol) {
        self.geolocationService = geolocationService
    }

    @PublishedAfter private var publishedIsActive: Bool = false
    var isActive: Bool {
        get {
            publishedIsActive
        }
        set {
            publishedIsActive = newValue
        }
    }
    var isActivePublisher: AnyPublisher<Bool, Never> {
        $publishedIsActive.eraseToAnyPublisher()
    }

    @PublishedAfter private var publishedIsPaused: Bool = false
    var isPaused: Bool {
        get {
            publishedIsPaused
        }
        set {
            publishedIsPaused = newValue
        }
    }
    var isPausedPublisher: AnyPublisher<Bool, Never> {
        $publishedIsPaused.eraseToAnyPublisher()
    }

    var isRevoked: Bool = false

    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        self.geolocationService.authorizationStatusPublisher
    }
    var authorizationStatus: CLAuthorizationStatus {
        self.geolocationService.authorizationStatus
    }

    func revoke() {
        isActive = false
        isRevoked = true
        onRevoke?()
    }

    func reset() {
        self.isActive = false
        self.isRevoked = false
        self.isPaused = false
        onReset?()
    }

}
