//
//  GeolocationProvider.swift
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
import Combine

final class GeolocationProvider: NSObject {
    private let geolocationService: GeolocationServiceProtocol
    private var geolocationManager: WKGeolocationManager
    private var locationCancellable: AnyCancellable?

    @PublishedAfter private(set) var isActive: Bool = false
    @PublishedAfter var isDisabled: Bool = false

    init?(processPool: WKProcessPool,
          geolocationService: GeolocationServiceProtocol = GeolocationService.shared) {

        guard let geolocationManager = processPool.geolocationManager else {
            assertionFailure("GeolocationProveder: WKContextGetGeolocationManager returned null")
            return nil
        }

        self.geolocationManager = geolocationManager
        self.geolocationService = geolocationService
        super.init()

        geolocationManager.setProvider(self)
    }

    private struct GeolocationDisabled: Error, LocalizedError {
        var errorDescription: String? {
            "Geolocation sharing disabled"
        }
    }

    fileprivate func startUpdatingLocation(geolocationManager: WKGeolocationManager) {
        self.isActive = true

        locationCancellable = geolocationService.locationPublisher.sink { [weak self] result in
            guard let self = self,
                  self.isActive,
                  !self.isDisabled
            else {
                geolocationManager.providerDidFailToDeterminePosition(GeolocationDisabled())
                return
            }

            switch result {
            case .none:
                break
            case .success(let location):
                geolocationManager.providerDidChangePosition(location)
            case .failure(let error):
                geolocationManager.providerDidFailToDeterminePosition(error)
            }
        }
    }

    fileprivate func stopUpdatingLocation(geolocationManager: WKGeolocationManager) {
        self.isActive = false
        locationCancellable?.cancel()
    }

    fileprivate func geolocationManager(_ geolocationManager: WKGeolocationManager, setEnableHighAccuracyCallback enable: Bool) {

    }

}

private func dynamicSymbol<T>(named symbolName: String) -> T? {
    guard let f = dlsym(/*RTLD_DEFAULT*/ UnsafeMutableRawPointer(bitPattern: -2), symbolName) else {
        assertionFailure("\(symbolName) symbol not found")
        return nil
    }
    return unsafeBitCast(f, to: T.self)
}

private extension WKProcessPool {

    typealias WKContextGetGeolocationManagerType = @convention(c)
        (UnsafeRawPointer?) -> UnsafeRawPointer?

    static let getGeolocationManager: WKContextGetGeolocationManagerType? =
        dynamicSymbol(named: "WKContextGetGeolocationManager")

    var geolocationManager: WKGeolocationManager? {
        Self.getGeolocationManager?(Unmanaged.passUnretained(self).toOpaque()).map(WKGeolocationManager.init)
    }

}

private struct WKGeolocationManager {

    // https://github.com/WebKit/WebKit/blob/8afe31a018b11741abdf9b4d5bb973d7c1d9ff05/Source/WebKit/UIProcess/API/C/WKGeolocationManager.h
    typealias WKGeolocationManagerSetProviderType = @convention(c)
        (UnsafeRawPointer?, UnsafePointer<WKGeolocationProviderBase>?) -> Void
    typealias WKGeolocationDidChangePositionType = @convention(c)
        (UnsafeRawPointer?, UnsafeRawPointer?) -> Void
    typealias WKGeolocationDidFailType = @convention(c)
        (UnsafeRawPointer?) -> Void
    typealias WKGeolocationDidFailWithErrorType = @convention(c)
        (UnsafeRawPointer?, UnsafeRawPointer?) -> Void

    static let setProvider: WKGeolocationManagerSetProviderType? =
        dynamicSymbol(named: "WKGeolocationManagerSetProvider")
    static let providerDidChangePosition: WKGeolocationDidChangePositionType? =
        dynamicSymbol(named: "WKGeolocationManagerProviderDidChangePosition")
    static let failedToDeterminePosition: WKGeolocationDidFailType? =
        dynamicSymbol(named: "WKGeolocationManagerProviderDidFailToDeterminePosition")
    static let failedToDeterminePositionWithError: WKGeolocationDidFailWithErrorType? =
        dynamicSymbol(named: "WKGeolocationManagerProviderDidFailToDeterminePositionWithErrorMessage")

    private let geolocationManager: UnsafeRawPointer

    init(_ geolocationManager: UnsafeRawPointer) {
        self.geolocationManager = geolocationManager
    }

    func setProvider(_ provider: AnyObject?) {
        let clientInfo = provider.map { Unmanaged.passUnretained($0).toOpaque() }
        var providerCallback = WKGeolocationProviderV1(base: .init(version: 1,
                                                                   clientInfo: clientInfo),
                                                       startUpdating: startUpdatingCallback,
                                                       stopUpdating: stopUpdatingCallback,
                                                       setEnableHighAccuracy: setEnableHighAccuracyCallback)
        withUnsafePointer(to: &providerCallback.base) { base in
            WKGeolocationManager.setProvider?(geolocationManager, base)
        }
    }

    func providerDidChangePosition(_ location: CLLocation) {
        guard let position = createWKGeolocationPosition(location) else { return }
        WKGeolocationManager.providerDidChangePosition?(geolocationManager, position)
        position.deallocate()
    }

    func providerDidFailToDeterminePosition(_ error: Error?) {
        WKGeolocationManager.failedToDeterminePosition?(geolocationManager)
    }

}

private typealias WKGeolocationPositionCreate_c_type =  @convention(c) // swiftlint:disable:this type_name
    (/*timestamp:*/ Double, /*latitude:*/ Double, /*longitude:*/ Double, /*accuracy:*/ Double,
     /*providesAltitude:*/ Bool, /*altitude:*/ Double, /*providesAltitudeAccuracy:*/ Bool,
     /*altitudeAccuracy:*/ Double, /*providesHeading:*/ Bool, /*heading:*/ Double,
     /*providesSpeed:*/ Bool, /*speed:*/ Double, /*providesFloorLevel:*/ Bool, /*floorLevel:*/ Double)
    -> UnsafeRawPointer?

private let WKGeolocationPositionCreate_c: WKGeolocationPositionCreate_c_type? = // swiftlint:disable:this identifier_name
    dynamicSymbol(named: "WKGeolocationPositionCreate_c")

private func createWKGeolocationPosition(_ location: CLLocation) -> UnsafeRawPointer? {
    WKGeolocationPositionCreate_c?(location.timestamp.timeIntervalSince1970,
                                   location.coordinate.latitude,
                                   location.coordinate.longitude,
                                   location.horizontalAccuracy,
                                   /*providesAltitude:*/ true,
                                   location.altitude,
                                   /*providesAltitudeAccuracy:*/ true,
                                   location.verticalAccuracy,
                                   /*providesHeading:*/ true,
                                   location.course,
                                   /*providesSpeed:*/ true,
                                   location.speed,
                                   location.floor != nil,
                                   location.floor.map { Double($0.level) } ?? 0)
}

private func startUpdatingCallback(geolocationManager: UnsafeRawPointer?, clientInfo: UnsafeRawPointer?) {
    guard let clientInfo = clientInfo,
          let geolocationManager = geolocationManager.map(WKGeolocationManager.init)
    else { return }
    Unmanaged<GeolocationProvider>.fromOpaque(clientInfo).takeUnretainedValue()
        .startUpdatingLocation(geolocationManager: geolocationManager)
}

private func stopUpdatingCallback(geolocationManager: UnsafeRawPointer?, clientInfo: UnsafeRawPointer?) {
    guard let clientInfo = clientInfo,
          let geolocationManager = geolocationManager.map(WKGeolocationManager.init)
    else { return }
    Unmanaged<GeolocationProvider>.fromOpaque(clientInfo).takeUnretainedValue()
        .stopUpdatingLocation(geolocationManager: geolocationManager)
}

private func setEnableHighAccuracyCallback(geolocationManager: UnsafeRawPointer?, enable: Bool, clientInfo: UnsafeRawPointer?) {
    guard let clientInfo = clientInfo,
          let geolocationManager = geolocationManager.map(WKGeolocationManager.init)
    else { return }
    Unmanaged<GeolocationProvider>.fromOpaque(clientInfo).takeUnretainedValue()
        .geolocationManager(geolocationManager, setEnableHighAccuracyCallback: enable)
}
