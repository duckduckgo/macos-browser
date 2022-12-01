//
//  BWCredential.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

struct BWCredential {

    var userId: String
    var credentialId: String?
    var credentialName: String

    var username: String?
    var password: String?

    var domain: String

    var url: String? {
        guard !domain.isEmpty else { return nil }
        return "\(URL.NavigationalScheme.https.separated())\(domain)"
    }

}

extension BWCredential {

    init?(from payloadItem: BWResponse.PayloadItem, domain: String) {
        guard let userId = payloadItem.userId,
              let credentialId = payloadItem.credentialId,
              let credentialName = payloadItem.name else {
            assertionFailure("Failed to init BitwardenCredential from PayloadItem")
            return nil
        }
        self.init(userId: userId, credentialId: credentialId, credentialName: credentialName, username: payloadItem.userName, password: payloadItem.password, domain: domain)
    }

}
