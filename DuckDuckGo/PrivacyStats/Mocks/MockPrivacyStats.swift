//
//  MockPrivacyStats.swift
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

#if DEBUG

import Combine
import PrivacyStats

final class MockPrivacyStats: PrivacyStatsCollecting {
    func recordBlockedTracker(_ name: String) async {}
    let statsUpdatePublisher: AnyPublisher<Void, Never> = PassthroughSubject<Void, Never>().eraseToAnyPublisher()
    func fetchPrivacyStats() async -> [String: Int64] { [:] }
    func clearPrivacyStats() async {}
    func handleAppTermination() async {}
}

#endif
