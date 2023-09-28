//
//  PixelKitEvent.swift
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

/// An event that can be fired using PixelKit.
///
public protocol PixelKitEvent {
    var name: String { get }
    var parameters: [String: String]? { get }
    var frequency: PixelKitEventFrequency { get }
}

/// The frequency with which a pixel is sent to our endpoint.
///
public enum PixelKitEventFrequency {
    /// The default frequency for pixels. This fires pixels with the event names as-is.
    case standard

    /// Sent once per day. The last timestamp for this pixel is stored and compared to the current date. Pixels of this type will have `_d` appended to their name.
    case dailyOnly

    /// Sent once per day with a `_d` suffix, in addition to every time it is called with a `_c` suffix.
    /// This means a pixel will get sent twice the first time it is called per-day, and subsequent calls that day will only send the `_c` variant.
    /// This is useful in situations where pixels receive spikes in volume, as the daily pixel can be used to determine how many users are actually affected.
    case dailyAndContinuous
}

/// Implementation of ``PixelKitEvent`` with specific logic for debug events.
///
public final class DebugEvent: PixelKitEvent {
    public enum EventType {
        case assertionFailure(message: String, file: StaticString, line: UInt)
        case custom(_ event: PixelKitEvent)
    }

    public let eventType: EventType
    private let error: Error?

    public init(eventType: EventType, error: Error? = nil) {
        self.eventType = eventType
        self.error = error
    }

    public var name: String {
        switch eventType {
        case .assertionFailure:
            return "assertion_failure"
        case .custom(let event):
            return event.name
        }
    }

    public var parameters: [String: String]? {
        var params = [String: String]()

        if let errorWithUserInfo = error as? ErrorWithParameters {
            params = errorWithUserInfo.errorParameters
        }

        if case let .assertionFailure(message, file, line) = eventType {
            params[PixelKit.Parameters.assertionMessage] = message
            params[PixelKit.Parameters.assertionFile] = String(file)
            params[PixelKit.Parameters.assertionLine] = String(line)
        }

        if let error = error {
            let nsError = error as NSError

            params[PixelKit.Parameters.errorCode] = "\(nsError.code)"
            params[PixelKit.Parameters.errorDesc] = nsError.domain

            if let underlyingError = nsError.userInfo["NSUnderlyingError"] as? NSError {
                params[PixelKit.Parameters.underlyingErrorCode] = "\(underlyingError.code)"
                params[PixelKit.Parameters.underlyingErrorDesc] = underlyingError.domain
            }

            if let sqlErrorCode = nsError.userInfo["SQLiteResultCode"] as? NSNumber {
                params[PixelKit.Parameters.underlyingErrorSQLiteCode] = "\(sqlErrorCode.intValue)"
            }

            if let sqlExtendedErrorCode = nsError.userInfo["SQLiteExtendedResultCode"] as? NSNumber {
                params[PixelKit.Parameters.underlyingErrorSQLiteExtendedCode] = "\(sqlExtendedErrorCode.intValue)"
            }
        }

        return params
    }

    public var frequency: PixelKitEventFrequency {
        switch eventType {
        case .assertionFailure:
            return .standard
        case .custom(let event):
            return event.frequency
        }
    }
}
