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

protocol JoinedWaitlistViewData {
    var headerImageName: String { get }
    var title: String { get }
    var joinedWithNoNotificationSubtitle1: String { get }
    var joinedWithNoNotificationSubtitle2: String { get }
    var enableNotificationSubtitle: String { get }
    var buttonConfirmLabel: String { get }
    var buttonCancelLabel: String { get }
    var buttonEnableNotificationLabel: String { get }
}

struct JoinedWaitlistView: View {
    let viewData: JoinedWaitlistViewData
    @EnvironmentObject var model: WaitlistViewModel

    let notificationsAllowed: Bool

    var body: some View {
        WaitlistDialogView {
            VStack(spacing: 16.0) {
                Image(viewData.headerImageName)

                Text(viewData.title)
                    .font(.system(size: 17, weight: .bold))

                if notificationsAllowed {
                    VStack(spacing: 16) {
                        Text(viewData.joinedWithNoNotificationSubtitle1)
                            .multilineTextAlignment(.center)
                            .frame(minHeight: 28) // Hack to force height calculation to work correctly

                        Text(viewData.joinedWithNoNotificationSubtitle2)
                            .multilineTextAlignment(.center)
                    }

                } else {
                    Text(viewData.enableNotificationSubtitle)
                        .multilineTextAlignment(.center)
                }
            }
        } buttons: {
            if notificationsAllowed {
                Button(viewData.buttonConfirmLabel) {
                    Task {
                        await model.perform(action: .close)
                    }
                }
            } else {
                Button(viewData.buttonCancelLabel) {
                    Task {
                        await model.perform(action: .close)
                    }
                }

                Button(viewData.buttonEnableNotificationLabel) {
                    Task {
                        await model.perform(action: .requestNotificationPermission)
                    }
                }
                .buttonStyle(DefaultActionButtonStyle(enabled: true))
            }
        }
        .environmentObject(model)
    }
}
