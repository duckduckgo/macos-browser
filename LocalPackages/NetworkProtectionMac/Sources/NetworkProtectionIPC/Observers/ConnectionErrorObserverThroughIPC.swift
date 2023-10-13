//
//  ConnectionErrorObserverThroughIPC.swift
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
import Combine
import NetworkProtection

/// This status observer can only be used from the App that owns the tunnel, as other Apps won't have access to the
/// NEVPNStatusDidChange notifications or tunnel session.
///
public class ConnectionErrorObserverThroughIPC: ConnectionErrorObserver {
    private let subject = CurrentValueSubject<String?, Never>(nil)

    // MARK: - ConnectionStatusObserver

    public lazy var publisher = subject.eraseToAnyPublisher()

    public var recentValue: String? {
        subject.value
    }

    // MARK: - Publishing Updates

    func publish(_ error: String?) {
        subject.send(error)
    }
}
