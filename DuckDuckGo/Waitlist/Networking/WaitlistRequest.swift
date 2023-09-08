//
//  WaitlistRequest.swift
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

enum WaitlistResponse {

    // MARK: Join

    struct Join: Decodable {
        public let token: String
        public let timestamp: Int

        public init(token: String, timestamp: Int) {
            self.token = token
            self.timestamp = timestamp
        }
    }

    enum JoinError: Error {
        case failed
        case noData
    }

    // MARK: Status

    struct Status: Decodable {
        public let timestamp: Int

        public init(timestamp: Int) {
            self.timestamp = timestamp
        }
    }

    enum StatusError: Error {
        case failed
        case noData
    }

    // MARK: Invite Code

    struct InviteCode: Decodable {
        public let code: String

        public init(code: String) {
            self.code = code
        }
    }

    enum InviteCodeError: Error {
        case failed
        case noData
    }

}

typealias WaitlistJoinResult = Result<WaitlistResponse.Join, WaitlistResponse.JoinError>
typealias WaitlistJoinCompletion = (Result<WaitlistResponse.Join, WaitlistResponse.JoinError>) -> Void

protocol WaitlistRequest {

    func joinWaitlist(completionHandler: @escaping WaitlistJoinCompletion)
    func joinWaitlist() async -> WaitlistJoinResult

    func getWaitlistStatus(completionHandler: @escaping (Result<WaitlistResponse.Status, WaitlistResponse.StatusError>) -> Void)
    func getInviteCode(token: String, completionHandler: @escaping (Result<WaitlistResponse.InviteCode, WaitlistResponse.InviteCodeError>) -> Void)

}
