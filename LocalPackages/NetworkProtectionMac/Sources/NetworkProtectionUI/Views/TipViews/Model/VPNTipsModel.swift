//
//  VPNTipsModel.swift
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

import AppKit
import Combine
import CombineExtensions
import NetworkProtection
import TipKitUtils

public final class VPNTipsModel: ObservableObject {

    @Published
    private(set) var featureFlag: Bool
    let tips: TipGrouping

    private var cancellables = Set<AnyCancellable>()

    static func makeTips(forMenuApp isMenuApp: Bool) -> TipGrouping {
        // This is temporarily disabled until Xcode 16 is available.
        // Ref: https://app.asana.com/0/414235014887631/1208528787265444/f
        //
        // if #available(macOS 15.0, *) {
        //     if isMenuApp {
        //         return TipGroup(.ordered) {
        //             VPNGeoswitchingTip()
        //             VPNAutoconnectTip()
        //         }
        //     } else {
        //         return TipGroup(.ordered) {
        //             VPNGeoswitchingTip()
        //             VPNDomainExclusionsTip()
        //             VPNAutoconnectTip()
        //         }
        //     }
        // }
        if #available(macOS 14, *) {
            if isMenuApp {
                return LegacyTipGroup(.ordered) {
                    VPNGeoswitchingTip()
                    VPNAutoconnectTip()
                }
            } else {
                return LegacyTipGroup(.ordered) {
                    VPNGeoswitchingTip()
                    VPNDomainExclusionsTip()
                    VPNAutoconnectTip()
                }
            }
        } else {
            return EmptyTipGroup()
        }
    }

    public init(featureFlagPublisher: CurrentValuePublisher<Bool, Never>,
                forMenuApp isMenuApp: Bool) {

        self.featureFlag = featureFlagPublisher.value
        self.tips = Self.makeTips(forMenuApp: isMenuApp)

        subscribeToFeatureFlagChanges(featureFlagPublisher)
    }

    private func subscribeToFeatureFlagChanges(_ publisher: CurrentValuePublisher<Bool, Never>) {
        publisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.featureFlag, onWeaklyHeld: self)
            .store(in: &cancellables)
    }
}
