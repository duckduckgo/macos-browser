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

                Text(UserText.networkProtectionWaitlistJoinedTitle)
                    .font(.system(size: 17, weight: .bold))

                if notificationsAllowed {
                    VStack(spacing: 16) {
                        Text(UserText.networkProtectionWaitlistJoinedWithNotificationsSubtitle1)
                            .multilineTextAlignment(.center)
                        Text(UserText.networkProtectionWaitlistJoinedWithNotificationsSubtitle2)
                            .multilineTextAlignment(.center)
                    }

                } else {
                    Text(UserText.networkProtectionWaitlistEnableNotifications)
                        .multilineTextAlignment(.center)
                }
            }
        } buttons: {
            if notificationsAllowed {
                Button(UserText.networkProtectionWaitlistButtonDone) {
                    model.perform(action: .close)
                }
            } else {
                Button(UserText.networkProtectionWaitlistButtonNoThanks) {
                    model.perform(action: .close)
                }

                Button(UserText.networkProtectionWaitlistButtonEnableNotifications) {
                    model.perform(action: .requestNotificationPermission)
                }
                .buttonStyle(DefaultActionButtonStyle(enabled: true))
            }
        }
        .environmentObject(model)
    }
}
