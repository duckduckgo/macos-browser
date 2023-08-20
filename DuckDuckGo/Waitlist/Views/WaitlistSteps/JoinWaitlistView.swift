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

import SwiftUI
import SwiftUIExtensions

struct JoinWaitlistView: View {
    @EnvironmentObject var model: WaitlistViewModel

    var body: some View {
        WaitlistDialogView {
            VStack(spacing: 16.0) {
                Image("JoinWaitlistHeader")

                Text(UserText.networkProtectionWaitlistJoinTitle)
                    .font(.system(size: 17, weight: .bold))

                Text(UserText.networkProtectionWaitlistJoinSubtitle1)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color("BlackWhite80"))

                Text(UserText.networkProtectionWaitlistJoinSubtitle2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color("BlackWhite80"))

                Text(UserText.networkProtectionWaitlistAvailabilityDisclaimer)
                    .font(.system(size: 12))
                    .foregroundColor(Color("BlackWhite60"))
            }
        } buttons: {
            Button(UserText.networkProtectionWaitlistButtonClose) {
                Task { await model.perform(action: .close) }
            }

            Button(UserText.networkProtectionWaitlistButtonJoinWaitlist) {
                Task { await model.perform(action: .joinQueue) }
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: model.viewState == .notOnWaitlist))
        }
        .environmentObject(model)
    }
}
