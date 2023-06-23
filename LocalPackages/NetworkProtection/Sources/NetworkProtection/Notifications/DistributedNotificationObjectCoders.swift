//
//  DistributedNotificationObjectCoders.swift
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

/// JSONEncoder encrypts its output encoded as UTF8.  This is just a convenience constant to make sure we're using
/// the proper encoding across the encoder and decoder.
///
private let defaultJSONEncoding = String.Encoding.utf8

public typealias ConnectionStatusChangeEncoder = DistributedNotificationObjectEncoder<ConnectionStatusChange>
public typealias ConnectionStatusChangeDecoder = DistributedNotificationObjectDecoder<ConnectionStatusChange>

public typealias ServerSelectedNotificationObjectEncoder = DistributedNotificationObjectEncoder<NetworkProtectionStatusServerInfo>
public typealias ServerSelectedNotificationObjectDecoder = DistributedNotificationObjectDecoder<NetworkProtectionStatusServerInfo>

/// Implements the standard encoder used for NetworkProtection distributed notifications.
/// This encoder converts the given object to a JSON string that can be sent in notifications.
///
public struct DistributedNotificationObjectEncoder<T: Encodable> {
    public init() {}

    public func encode(_ object: T) -> String {
        let jsonData = (try? JSONEncoder().encode(object))!
        return String(data: jsonData, encoding: defaultJSONEncoding)!
    }
}

/// Implements the standard decoder used for NetworkProtection distributed notifications
///
public struct DistributedNotificationObjectDecoder<T: Decodable> {
    enum DecodeError: Error {
        case couldNotCastNotificationObjectToString
        case decodeFailed(_ error: Error)
    }

    public init() {}

    /// Decodes the object from a Network Protection distributed notification.
    ///
    public func decodeObject(from notification: Notification) throws -> T {
        guard let string = notification.object as? String else {
            throw DecodeError.couldNotCastNotificationObjectToString
        }

        return try decode(string)
    }

    /// Decodes the object from a Network Protection distributed notification.
    ///
    public func decode(_ payload: String) throws -> T {
        let jsonData = payload.data(using: defaultJSONEncoding)!
        let object: T

        do {
            object = try JSONDecoder().decode(T.self, from: jsonData)
        } catch {
            throw DecodeError.decodeFailed(error)
        }

        return object
    }
}
