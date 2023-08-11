//
//  JoinedWaitlistView.swift
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

struct JoinedWaitlistView: View {
    @EnvironmentObject var model: WaitlistViewModel

    let notificationsAllowed: Bool

    var body: some View {
        WaitlistDialogView {
            VStack(spacing: 16.0) {
                Image("JoinedWaitlistHeader")

                Text("You're on the list!")
                    .font(.system(size: 17, weight: .bold))

                if notificationsAllowed {
                    VStack(spacing: 16) {
                        Text("New invites are sent every few days, on a first come, first served basis.")
                            .multilineTextAlignment(.center)
                        Text("We'll notify you know when your invite is ready.")
                            .multilineTextAlignment(.center)
                    }

                } else {
                    Text("Want to get a notification when your Network Protection invite is ready?")
                        .multilineTextAlignment(.center)
                }
            }
        } buttons: {
            if notificationsAllowed {
                Button("Done") {
                    model.perform(action: .close)
                }
            } else {
                Button("No Thanks") {
                    model.perform(action: .close)
                }

                Button("Enable Notifications") {
                    model.perform(action: .requestNotificationPermission)
                }
                .buttonStyle(DefaultActionButtonStyle(enabled: true))
            }
        }
        .environmentObject(model)
    }
}
