//
//  ConnectionStatusCoders.swift
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

public class ConnectionStatusChangeEncoder {
    public init() {}

    public func encode(_ change: ConnectionStatusChange) -> String? {
        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(change)

            return String(data: jsonData, encoding: DistributedNotificationCenter.preferredStringEncoding)
        } catch {
            return nil
        }
    }
}

public class ConnectionStatusChangeDecoder {
    public init() {}

    public func decode(_ object: Any?) -> ConnectionStatusChange {
        guard let payload = object as? String else {
            return ConnectionStatusChange(status: .unknown)
        }

        guard let jsonData = payload.data(using: DistributedNotificationCenter.preferredStringEncoding) else {
            return ConnectionStatusChange(status: .unknown)
        }

        let jsonDecoder = JSONDecoder()
        let change: ConnectionStatusChange

        do {
            change = try jsonDecoder.decode(ConnectionStatusChange.self, from: jsonData)
        } catch {
            return ConnectionStatusChange(status: .unknown)
        }

        return change
    }
}
