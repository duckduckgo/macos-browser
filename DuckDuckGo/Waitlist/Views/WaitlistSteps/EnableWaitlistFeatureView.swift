//
//  EnableWaitlistFeatureView.swift
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

#if NETWORK_PROTECTION || DBP

import SwiftUI
import SwiftUIExtensions

protocol EnableWaitlistFeatureViewData {
    var headerImageName: String { get }
    var title: String { get }
    var subtitle: String { get }
    var availabilityDisclaimer: String { get }
    var buttonConfirmLabel: String { get }
}

struct EnableWaitlistFeatureView: View {
    var viewData: EnableWaitlistFeatureViewData
    @EnvironmentObject var model: WaitlistViewModel

    var body: some View {
        WaitlistDialogView {
            VStack(spacing: 16.0) {
                Image(viewData.headerImageName)

                Text(viewData.title)
                    .font(.system(size: 17, weight: .bold))

                Text(viewData.subtitle)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color("BlackWhite80"))

                Text(viewData.availabilityDisclaimer)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 12))
                    .foregroundColor(Color("BlackWhite60"))
            }
        } buttons: {
            Button(viewData.buttonConfirmLabel) {
                Task {
                    await model.perform(action: .closeAndConfirmFeature)
                }
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
        .environmentObject(model)
    }
}

#endif

#if NETWORK_PROTECTION

struct EnableNetworkProtectionViewData: EnableWaitlistFeatureViewData {
    var headerImageName: String = "Network-Protection-256"
    var title: String = UserText.networkProtectionWaitlistEnableTitle
    var subtitle: String = UserText.networkProtectionWaitlistEnableSubtitle
    var availabilityDisclaimer: String = UserText.networkProtectionWaitlistAvailabilityDisclaimer
    var buttonConfirmLabel: String = UserText.networkProtectionWaitlistButtonGotIt
}

#endif

#if DBP

struct EnableDataBrokerProtectionViewData: EnableWaitlistFeatureViewData {
    var headerImageName: String = "DBP-JoinWaitlistHeader"
    var title: String = UserText.dataBrokerProtectionWaitlistEnableTitle
    var subtitle: String = UserText.dataBrokerProtectionWaitlistEnableSubtitle
    var availabilityDisclaimer: String = UserText.dataBrokerProtectionWaitlistAvailabilityDisclaimer
    var buttonConfirmLabel: String = UserText.dataBrokerProtectionWaitlistButtonGotIt
}

#endif
