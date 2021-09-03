//
//  OpenURLNotificationMessage.swift
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

struct OpenURLNotificationMessage: Codable {
    
    let pid: pid_t
    let url: URL

    func toString() throws -> String {
        try JSONEncoder().encode(self).base64EncodedString()
    }

    static func fromString(_ string: String) throws -> OpenURLNotificationMessage {
        guard let data = Data(base64Encoded: string) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: ""))
        }
        return try JSONDecoder().decode(Self.self, from: data)
    }

}
