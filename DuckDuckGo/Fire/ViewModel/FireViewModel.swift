//
//  FireViewModel.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import WebKit
import Combine

final class FireViewModel {

    let fire: Fire

    @Published var isAnimationPlaying = false

    /// Publisher that emits true if burning animation or burning process is in progress
    var isFirePresentationInProgress: AnyPublisher<Bool, Never> {
        Publishers
            .CombineLatest($isAnimationPlaying, fire.$burningData)
            .map { (isAnimationPlaying, burningData) -> (Bool) in
                return isAnimationPlaying || burningData != nil
            }
            .eraseToAnyPublisher()
    }

    @MainActor
    init(fire: Fire) {
        self.fire = fire
    }

    @MainActor
    init() {
        fire = Fire(tld: ContentBlocking.shared.tld)
    }

}
