//
//  InvitedToWaitlistView.swift
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

import Foundation
import SwiftUI
import SwiftUIExtensions

struct InvitedToWaitlistView: View {
    @EnvironmentObject var model: WaitlistViewModel

    var body: some View {
        WaitlistDialogView {
            VStack(spacing: 16.0) {
                Image("Gift-96")

                Text(UserText.networkProtectionWaitlistInvitedTitle)
                    .font(.system(size: 17, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(UserText.networkProtectionWaitlistInvitedSubtitle)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color("BlackWhite80"))

                VStack(spacing: 16.0) {
                    WaitlistListEntryView(
                        imageName: "Shield-16",
                        title: UserText.networkProtectionWaitlistInvitedSection1Title,
                        subtitle: UserText.networkProtectionWaitlistInvitedSection1Subtitle
                    )

                    WaitlistListEntryView(
                        imageName: "Rocket-16",
                        title: UserText.networkProtectionWaitlistInvitedSection2Title,
                        subtitle: UserText.networkProtectionWaitlistInvitedSection2Subtitle
                    )

                    WaitlistListEntryView(
                        imageName: "Card-16",
                        title: UserText.networkProtectionWaitlistInvitedSection3Title,
                        subtitle: UserText.networkProtectionWaitlistInvitedSection3Subtitle
                    )
                }
                .padding(20.0)
                .frame(maxWidth: .infinity)
                .background(Color("BlackWhite1"))
                .border(Color("BlackWhite5"))

                Text(UserText.networkProtectionWaitlistAvailabilityDisclaimer)
                    .font(.system(size: 12))
                    .foregroundColor(Color("BlackWhite60"))
            }
        } buttons: {
            Button(UserText.networkProtectionWaitlistButtonDismiss) {
                Task {
                    await model.perform(action: .close)
                }
            }

            Button(UserText.networkProtectionWaitlistButtonGetStarted) {
                Task {
                    await model.perform(action: .showTermsAndConditions)
                }
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
        .environmentObject(model)
    }
}

private struct WaitlistListEntryView: View {
    let imageName: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(imageName)
                .frame(maxWidth: 16, maxHeight: 16)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color("BlackWhite80"))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color("BlackWhite60"))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
    }
}
