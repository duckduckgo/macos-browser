//
//  LoginsPreferencesModel.swift
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

final class LoginsPreferencesModel: ObservableObject {

    enum AutoLockThreshold: String, CaseIterable {
        case oneMinute
        case fiveMinutes
        case fifteenMinutes
        case thirtyMinutes
        case oneHour

        var title: String {
            switch self {
            case .oneMinute: return UserText.autoLockThreshold1Minute
            case .fiveMinutes: return UserText.autoLockThreshold5Minutes
            case .fifteenMinutes: return UserText.autoLockThreshold15Minutes
            case .thirtyMinutes: return UserText.autoLockThreshold30Minutes
            case .oneHour: return UserText.autoLockThreshold1Hour
            }
        }
        
        var seconds: TimeInterval {
            switch self {
            case .oneMinute: return 60
            case .fiveMinutes: return 60 * 5
            case .fifteenMinutes: return 60 * 15
            case .thirtyMinutes: return 60 * 30
            case .oneHour: return 60 * 60
            }
        }
        
        var pixelEvent: Pixel.Event {
            switch self {
            case .oneMinute: return .passwordManagerLockScreenTimeoutSelected1Minute
            case .fiveMinutes: return .passwordManagerLockScreenTimeoutSelected5Minutes
            case .fifteenMinutes: return .passwordManagerLockScreenTimeoutSelected15Minutes
            case .thirtyMinutes: return .passwordManagerLockScreenTimeoutSelected30Minutes
            case .oneHour: return .passwordManagerLockScreenTimeoutSelected1Hour
            }
        }

    }
    
    @Published var shouldAutoLockLogins: Bool = true {
        didSet {
            statisticsStore.autoLockEnabled = shouldAutoLockLogins
            
            if oldValue != shouldAutoLockLogins {
                NotificationCenter.default.post(name: .loginsAutoLockSettingsDidChange, object: nil)
            }
        }
    }
    
    @Published var autoLockThreshold: AutoLockThreshold = .fifteenMinutes {
        didSet {
            statisticsStore.autoLockThreshold = autoLockThreshold.rawValue
        }
    }
    
    private var statisticsStore: StatisticsStore {
        return injectedDependencyStore ?? defaultDependencyStore
    }

    private let injectedDependencyStore: StatisticsStore?
    private lazy var defaultDependencyStore: StatisticsStore = {
        return LocalStatisticsStore()
    }()

    init(statisticsStore: StatisticsStore? = nil) {
        self.injectedDependencyStore = statisticsStore
        shouldAutoLockLogins = self.statisticsStore.autoLockEnabled
        autoLockThreshold = {
            if let rawValue = self.statisticsStore.autoLockThreshold, let threshold = AutoLockThreshold(rawValue: rawValue) {
                return threshold
            } else {
                return .fifteenMinutes
            }
        }()
    }

}
