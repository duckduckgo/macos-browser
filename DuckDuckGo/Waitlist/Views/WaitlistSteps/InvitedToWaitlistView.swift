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
                    .foregroundColor(.black.opacity(0.88))

                VStack(spacing: 16.0) {
                    WaitlistListEntryView(
                        imageName: "Shield-16",
                        title: "Secure all traffic to and from your device",
                        subtitle: "We use the WireGuard protocol to encrypt online traffic across your browsers and apps."
                    )

                    WaitlistListEntryView(
                        imageName: "Rocket-16",
                        title: "Fast, reliable, and easy to use",
                        subtitle: "Connect with one click to route your browsing and app activity through the nearest VPN server."
                    )

                    WaitlistListEntryView(
                        imageName: "Card-16",
                        title: "A VPN you can trust",
                        subtitle: "Unlike some VPNs, we do not log or save any data that can connect you to your online activity."
                    )
                }
                .padding(20.0)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.01))
                .border(Color.black.opacity(0.06))

                Text(UserText.networkProtectionWaitlistAvailabilityDisclaimer)
                    .font(.system(size: 12))
                    .foregroundColor(.black.opacity(0.60))
            }
        } buttons: {
            Button(UserText.networkProtectionWaitlistButtonDismiss) {
                model.perform(action: .close)
            }

            Button(UserText.networkProtectionWaitlistButtonGetStarted) {
                model.perform(action: .showTermsAndConditions)
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
        .environmentObject(model)
    }
}
