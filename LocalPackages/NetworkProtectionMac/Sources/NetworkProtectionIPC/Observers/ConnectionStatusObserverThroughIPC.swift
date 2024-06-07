//
//  ConnectionStatusObserverThroughIPC.swift
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

import Combine
import Foundation
import NetworkProtection

public final class ConnectionStatusObserverThroughIPC: ConnectionStatusObserver {

    private let subject = CurrentValueSubject<ConnectionStatus, Never>(.disconnected)

    // MARK: - ConnectionStatusObserver

    public lazy var publisher = subject.eraseToAnyPublisher()

    public var recentValue: ConnectionStatus {
        subject.value
    }

    // MARK: - Publishing Updates

    func publish(_ status: ConnectionStatus) {
        subject.send(status)
    }
}
