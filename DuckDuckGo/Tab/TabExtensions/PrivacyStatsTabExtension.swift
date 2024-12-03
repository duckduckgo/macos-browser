//
//  PrivacyStatsTabExtension.swift
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
import Common
import ContentBlocking
import Foundation
import Navigation
import PrivacyStats

final class PrivacyStatsTabExtension: NSObject {

    let privacyStats: PrivacyStatsCollecting
    private var cancellables = Set<AnyCancellable>()

    init(privacyStats: PrivacyStatsCollecting = NSApp.delegateTyped.privacyStats, trackersPublisher: some Publisher<DetectedTracker, Never>) {
        self.privacyStats = privacyStats
        super.init()

        trackersPublisher
            .sink { [weak self] tracker in
                self?.recordDetectedTracker(tracker)
            }
            .store(in: &cancellables)
    }

    private func recordDetectedTracker(_ tracker: DetectedTracker) {
        guard tracker.request.isBlocked, let entityName = tracker.request.entityName else {
            return
        }
        switch tracker.type {
        case .tracker, .trackerWithSurrogate:
            Task {
                await privacyStats.recordBlockedTracker(entityName)
            }
        case .thirdPartyRequest:
            break
        }
    }
}

protocol PrivacyStatsExtensionProtocol: AnyObject, NavigationResponder {
}

extension PrivacyStatsTabExtension: PrivacyStatsExtensionProtocol, TabExtension {
    func getPublicProtocol() -> PrivacyStatsExtensionProtocol { self }
}

extension TabExtensions {
    var privacyStats: PrivacyStatsExtensionProtocol? {
        resolve(PrivacyStatsTabExtension.self)
    }
}
