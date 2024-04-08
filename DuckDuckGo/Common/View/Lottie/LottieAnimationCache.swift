//
//  LottieAnimationCache.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import Lottie

final class LottieAnimationCache: AnimationCacheProvider {

    static let shared = LottieAnimationCache()
    private let lock = NSRecursiveLock()

    private var cache: [String: LottieAnimation] = [:]

    func animation(forKey: String) -> LottieAnimation? {
        lock.lock()
        defer { lock.unlock() }
        return cache[forKey]
    }

    func setAnimation(_ animation: LottieAnimation, forKey: String) {
        lock.lock()
        defer { lock.unlock() }
        if cache[forKey] == nil {
            cache[forKey] = animation
        }
    }

    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        cache = [String: LottieAnimation]()
    }

}

// `AnimationCacheProvider` conforms now to `Sendable`. This generates the warning `Stored property 'cache' of 'Sendable'-conforming class 'LottieAnimationCache' is mutable`.
// Implemented a lock mechanism and removed compiler strict check for Sendable requirement.
extension LottieAnimationCache: @unchecked Sendable {}
