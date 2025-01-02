//
//  CapturingNewTabPageActiveRemoteMessageProvider.swift
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

import Combine
import RemoteMessaging
import XCTest
import NewTabPage

final class CapturingNewTabPageActiveRemoteMessageProvider: NewTabPageActiveRemoteMessageProviding {
    @Published var newTabPageRemoteMessage: RemoteMessageModel?

    var newTabPageRemoteMessagePublisher: AnyPublisher<RemoteMessageModel?, Never> {
        $newTabPageRemoteMessage.dropFirst().eraseToAnyPublisher()
    }

    func isMessageSupported(_ message: RemoteMessageModel) -> Bool {
        true
    }

    func handleAction(_ action: RemoteAction?, andDismissUsing button: RemoteMessageButton) async {
        dismissCalls.append(.init(action: action, button: button))
    }

    struct Dismiss: Equatable {
        let action: RemoteAction?
        let button: RemoteMessageButton
    }

    var dismissCalls: [Dismiss] = []
}
