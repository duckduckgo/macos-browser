//
//  PixelKitEventV2.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

/// New version of this protocol that allows us to maintain backwards-compatibility with PixelKitEvent
///
/// This new implementation seeks to unify the handling of standard pixel parameters inside PixelKit.
/// The starting example of how this can be useful is error parameter handling - this protocol allows
/// the implementer to specify an error without having to know about its parameterisation.
///
/// The reason this wasn't done directly in `PixelKitEvent` is to reduce the risk of breaking existing
/// pixels, and to allow us to migrate towards this incrementally.
///
public protocol PixelKitEventV2: PixelKitEvent {
    var error: Error? { get }
}

/// Protocol to support mocking pixel firing.
///
/// We're adding support for `PixelKitEventV2` events strategically because adding support for earlier pixels
/// would be more complicated and time consuming.  The idea of V2 events is that fire calls should not include a lot
/// of parameters.  Parameters should be provided by the `PixelKitEventV2` protocol (extending it if necessary)
/// and the call to `fire` should process those properties to serialize in the requests.
///
public protocol PixelFiring {
    func fire(_ event: PixelKitEventV2)

    func fire(_ event: PixelKitEventV2,
              frequency: PixelKit.Frequency)
}

extension PixelKit: PixelFiring {
    public func fire(_ event: PixelKitEventV2) {
        fire(event, frequency: .standard)
    }

    public func fire(_ event: PixelKitEventV2,
                     frequency: PixelKit.Frequency) {

        fire(event, frequency: frequency, onComplete: { _, _ in })
    }
}
