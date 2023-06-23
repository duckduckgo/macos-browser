//
//  ConnectionStatus.swift
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

public enum ConnectionStatus: Codable, Equatable {
    case notConfigured
    case disconnected
    case disconnecting
    case connected(connectedDate: Date)
    case connecting
    case reasserting
    case unknown
}

/// This struct represents a status change and holds the new status and a timestamp registering when
/// the change happened.
///
/// This is useful to know whether we have processed or still need to process the status, in case the notification
/// is sent out more than once.
///
public struct ConnectionStatusChange: Codable {
    let status: ConnectionStatus
    let timestamp: Date

    public init(status: ConnectionStatus, on timestamp: Date) {
        self.status = status
        self.timestamp = timestamp
    }

    enum CodingKeys: CodingKey {
        case status
        case timestamp
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try container.decode(ConnectionStatus.self, forKey: .status)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.status, forKey: .status)
        try container.encode(self.timestamp, forKey: .timestamp)
    }
}
