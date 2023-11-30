//
//  JoinWaitlistView.swift
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

protocol JoinWaitlistViewViewData {
    var headerImageName: String { get }
    var title: String { get }
    var subtitle1: String { get }
    var subtitle2: String { get }
    var availabilityDisclaimer: String { get }
    var buttonCloseLabel: String { get }
    var buttonJoinWaitlistLabel: String { get }
}

struct JoinWaitlistView: View {
    let viewData: JoinWaitlistViewViewData
    @EnvironmentObject var model: WaitlistViewModel

    var body: some View {
        WaitlistDialogView {
            VStack(spacing: 16.0) {
                Image(viewData.headerImageName)

                Text(viewData.title)
                    .font(.system(size: 17, weight: .bold))

                Text(viewData.subtitle1)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color("BlackWhite80"))

                if !viewData.subtitle2.isEmpty {
                    Text(viewData.subtitle2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color("BlackWhite80"))
                }

                Text(viewData.availabilityDisclaimer)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 12))
                    .foregroundColor(Color("BlackWhite60"))
            }
        } buttons: {
            Button(viewData.buttonCloseLabel) {
                Task { await model.perform(action: .close) }
            }

            Button(viewData.buttonJoinWaitlistLabel) {
                Task { await model.perform(action: .joinQueue) }
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: model.viewState == .notOnWaitlist))
        }
        .environmentObject(model)
    }
}

#endif

#if NETWORK_PROTECTION

struct NetworkProtectionJoinWaitlistViewData: JoinWaitlistViewViewData {
    let headerImageName = "JoinWaitlistHeader"
    let title = UserText.networkProtectionWaitlistJoinTitle
    let subtitle1 = UserText.networkProtectionWaitlistJoinSubtitle1
    let subtitle2 = UserText.networkProtectionWaitlistJoinSubtitle2
    let availabilityDisclaimer = UserText.networkProtectionWaitlistAvailabilityDisclaimer
    let buttonCloseLabel = UserText.networkProtectionWaitlistButtonClose
    let buttonJoinWaitlistLabel = UserText.networkProtectionWaitlistButtonJoinWaitlist
}

#endif

#if DBP

struct DataBrokerProtectionJoinWaitlistViewData: JoinWaitlistViewViewData {
    let headerImageName = "DBP-JoinWaitlistHeader"
    let title = UserText.dataBrokerProtectionWaitlistJoinTitle
    let subtitle1 = UserText.dataBrokerProtectionWaitlistInvitedSubtitle
    let subtitle2 = ""
    let availabilityDisclaimer = UserText.dataBrokerProtectionWaitlistAvailabilityDisclaimer
    let buttonCloseLabel = UserText.dataBrokerProtectionWaitlistButtonClose
    let buttonJoinWaitlistLabel = UserText.dataBrokerProtectionWaitlistButtonJoinWaitlist
}

#endif
