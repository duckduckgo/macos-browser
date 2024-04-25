//
//  MockSyncPreferencesErrorHandler.swift
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

class MockSyncPreferencesErrorHandler: SyncPreferencesErrorHandler {
    static var syncBookmarksPausedData = SyncPausedErrorMetadata(syncPausedTitle: "Bookmarks Paused", syncPausedMessage: "Something with bookmark is wrong", syncPausedButtonTitle: "Manage Bookmarks", syncPausedAction: {print("something bookmarks")})
    static var syncCredentialsPausedData = SyncPausedErrorMetadata(syncPausedTitle: "Credentials Paused", syncPausedMessage: "Something with Credentials is wrong", syncPausedButtonTitle: "Manage Credentials", syncPausedAction: {print("something Credentials")})
    static var synclsPausedData = SyncPausedErrorMetadata(syncPausedTitle: "Paused", syncPausedMessage: "Something is wrong", syncPausedButtonTitle: "", syncPausedAction: nil)

    var isSyncPausedChangedPublisher = PassthroughSubject<Void, Never>()

    var syncDidTurnOffCalled = false

    var isSyncPaused: Bool = false

    var isSyncBookmarksPaused: Bool = false

    var isSyncCredentialsPaused: Bool = false

    var syncPausedChangedPublisher: AnyPublisher<Void, Never> {
        isSyncPausedChangedPublisher.eraseToAnyPublisher()
    }

    var syncPausedMetadata: SyncPausedErrorMetadata? {
        return Self.synclsPausedData
    }

    var syncBookmarksPausedMetadata: SyncPausedErrorMetadata {
        return Self.syncBookmarksPausedData
    }

    var syncCredentialsPausedMetadata: SyncPausedErrorMetadata {
        return Self.syncCredentialsPausedData
    }

    func syncDidTurnOff() {
        syncDidTurnOffCalled = true
    }
}
