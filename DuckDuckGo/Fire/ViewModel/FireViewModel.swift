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

extension Fire.BurningData {
    /**
     * We want to delay showing modal dialog by 1s while burn animation is being played
     * on the New Tab Page (i.e. when "specific domains" are burned without all-window fire animation).
     */
    var shouldDelayShowingDialog: Bool {
        switch self {
        case .specificDomains(_, false):
            return true
        default:
            return false
        }
    }
}

final class FireViewModel {

    let fire: Fire

    @Published var isAnimationPlaying = false

    /// Publisher that emits true if burning animation or burning process is in progress
    var isFirePresentationInProgress: AnyPublisher<Bool, Never> {
        Publishers
            .CombineLatest($isAnimationPlaying.removeDuplicates(), fire.$burningData.removeDuplicates())
            .map { (isAnimationPlaying, burningData) in
                let shouldDisplayDialog = isAnimationPlaying || burningData != nil
                if burningData?.shouldDelayShowingDialog == true {
                    return Just(shouldDisplayDialog).delay(for: .seconds(1), scheduler: RunLoop.main).eraseToAnyPublisher()
                }
                return Just(shouldDisplayDialog).eraseToAnyPublisher()
            }
            .switchToLatest()
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
