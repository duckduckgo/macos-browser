//
//  MockSyncPausedStateManaging.swift
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
import Combine
@testable import DuckDuckGo_Privacy_Browser

class MockSyncPausedStateManaging: SyncPausedStateManaging {
    static var syncBookmarksPausedData = SyncPausedMessageData(title: "Bookmarks Paused", description: "Something with bookmark is wrong", buttonTitle: "Manage Bookmarks", action: {print("something bookmarks")})
    static var syncCredentialsPausedData = SyncPausedMessageData(title: "Credentials Paused", description: "Something with Credentials is wrong", buttonTitle: "Manage Credentials", action: {print("something Credentials")})
    static var syncIsPausedData = SyncPausedMessageData(title: "Paused", description: "Something is wrong", buttonTitle: "", action: nil)

    var isSyncPausedChangedPublisher = PassthroughSubject<Void, Never>()

    var syncDidTurnOffCalled = false

    var isSyncPaused: Bool = false

    var isSyncBookmarksPaused: Bool = false

    var isSyncCredentialsPaused: Bool = false

    var syncPausedChangedPublisher: AnyPublisher<Void, Never> {
        isSyncPausedChangedPublisher.eraseToAnyPublisher()
    }

    var syncPausedMessageData: SyncPausedMessageData? {
        return Self.syncIsPausedData
    }

    var syncBookmarksPausedMessageData: SyncPausedMessageData? {
        return Self.syncBookmarksPausedData
    }

    var syncCredentialsPausedMessageData: SyncPausedMessageData? {
        return Self.syncCredentialsPausedData
    }

    func syncDidTurnOff() {
        syncDidTurnOffCalled = true
    }
}
