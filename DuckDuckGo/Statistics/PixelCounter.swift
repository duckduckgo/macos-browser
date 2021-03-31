//
//  PixelCounter.swift
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

extension Pixel {

    struct Counter {

        public struct Constants {
            public static let maxCount = 20
            fileprivate static let prefix = "c_"
        }

        let store: UserDefaults

        init(store: UserDefaults = .standard) {
            self.store = store
        }

        func incrementedCount(for event: Pixel.Event.Debug) -> Int {
            let key = Constants.prefix + event.rawValue
            var count = store.value(forKey: key) as? Int ?? 0

            guard count < Constants.maxCount else { return count }

            count += 1

            store.set(count, forKey: key)

            return count
        }

    }

}
