//
//  UDSMessage.swift
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

public enum UDSMessageResponse: Codable {
    case success(_ data: Data?)
    case failure
}

public enum UDSMessageBody: Codable {
    case request(_ data: Data)
    case response(_ response: UDSMessageResponse)
}

public struct UDSMessage: Codable {
    public let uuid: UUID
    public let body: UDSMessageBody

    public func successResponse(withPayload payload: Data?) -> UDSMessage {
        UDSMessage(uuid: uuid, body: .response(.success(payload)))
    }
}
