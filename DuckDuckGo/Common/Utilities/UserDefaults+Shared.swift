//
//  UserDefaultPublisher.swift
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
import NetworkProtectionUI
/*
extension UserDefaultPublisher {
    convenience init(key: UserDefaultsWrapper<T>.Key, defaults: UserDefaults, defaultValue: T) {
        self.init(key: key.rawValue, defaults: defaults, defaultValue: defaultValue)
    }
}*/

extension UserDefaults {
    @objc
    dynamic var networkProtectionOnboardingStatus: Int {
        get {
            value(forKey: "networkProtectionOnboardingStatus") as? Int ?? OnboardingStatus.default.rawValue
        }

        set {
            set(newValue, forKey: "networkProtectionOnboardingStatus")
            synchronize()
        }
    }
}

final class UserDefaultPublisher<T>: NSObject, Publisher {
    private let defaults: UserDefaults
    private let subject: CurrentValueSubject<T, Never>
    var observation: NSKeyValueObservation?

    init(keyPath: KeyPath<UserDefaults, T>, defaults: UserDefaults, defaultValue: T) {
        self.defaults = defaults

        subject = CurrentValueSubject<T, Never>(defaults[keyPath: keyPath])
        super.init()

        observation = defaults.observe(keyPath) { [weak self] defaults, _ in
            // We're ignoring the change parameter as it seems to come in as `nil` for some strange reason
            self?.subject.send(defaults[keyPath: keyPath])
        }
    }

    // MARK: - Publisher Wrapping

    typealias Output = T
    typealias Failure = Never

    func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, T == S.Input {
        subject.receive(subscriber: subscriber)
    }
}
