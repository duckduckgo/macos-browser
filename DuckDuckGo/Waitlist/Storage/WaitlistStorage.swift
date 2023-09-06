//
//  WaitlistStorage.swift
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

protocol WaitlistStorage {

    func getWaitlistToken() -> String?
    func getWaitlistTimestamp() -> Int?
    func getWaitlistInviteCode() -> String?

    func store(waitlistToken: String)
    func store(waitlistTimestamp: Int)
    func store(inviteCode: String)

    func deleteWaitlistState()

}

extension WaitlistStorage {

    var isWaitlistUser: Bool {
        return getWaitlistToken() != nil && getWaitlistTimestamp() != nil
    }

    var isOnWaitlist: Bool {
        return getWaitlistToken() != nil && getWaitlistTimestamp() != nil && !isInvited
    }

    var isInvited: Bool {
        return getWaitlistInviteCode() != nil
    }

}
