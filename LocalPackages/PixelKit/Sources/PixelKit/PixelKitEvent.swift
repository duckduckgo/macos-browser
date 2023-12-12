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

    public init(_ event: PixelKitEvent, error: Error? = nil) {
        self.eventType = .custom(event)
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
        var params: [String: String]

        if case let .custom(event) = eventType,
           let eventParams = event.parameters {
            params = eventParams
        } else {
            params = [String: String]()
        }

        if let errorWithUserInfo = error as? ErrorWithPixelParameters {
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
}
