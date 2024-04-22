//
//  PixelKitMock.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import PixelKit
import XCTest

public final class PixelKitMock: PixelFiring {

    /// An array of fire calls, in order, that this mock expects
    ///
    private let expectedFireCalls: [ExpectedFireCall]

    /// The actual fire calls
    ///
    private var actualFireCalls = [ExpectedFireCall]()

    public init(expecting expectedFireCalls: [ExpectedFireCall]) {
        self.expectedFireCalls = expectedFireCalls
    }

    public func fire(_ event: PixelKitEventV2) {
        fire(event, frequency: .standard)
    }

    public func fire(_ event: PixelKitEventV2, frequency: PixelKit.Frequency) {
        let fireCall = ExpectedFireCall(pixel: event, frequency: frequency)
        actualFireCalls.append(fireCall)
    }

    public func verifyExpectations(file: StaticString, line: UInt) {
        XCTAssertEqual(expectedFireCalls, actualFireCalls, file: file, line: line)
    }
}

public struct ExpectedFireCall: Equatable {
    let pixel: PixelKitEventV2
    let frequency: PixelKit.Frequency

    public init(pixel: PixelKitEventV2, frequency: PixelKit.Frequency) {
        self.pixel = pixel
        self.frequency = frequency
    }

    public static func == (lhs: ExpectedFireCall, rhs: ExpectedFireCall) -> Bool {
        lhs.pixel.name == rhs.pixel.name
        && lhs.pixel.parameters == rhs.pixel.parameters
        && (lhs.pixel.error as? NSError) == (rhs.pixel.error as? NSError)
        && lhs.frequency == rhs.frequency
    }
}
