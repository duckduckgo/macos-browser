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

protocol InvitedToWaitlistViewData {
    var headerImageName: String { get }
    var title: String { get }
    var subtitle: String { get }
    var entryViewViewDataList: [WaitlistEntryViewItemViewData] { get }
    var availabilityDisclaimer: String { get }
    var buttonDismissLabel: String { get }
    var buttonGetStartedLabel: String { get }
}

struct InvitedToWaitlistView: View {
    let viewData: InvitedToWaitlistViewData
    @EnvironmentObject var model: WaitlistViewModel

    var body: some View {
        WaitlistDialogView {
            VStack(spacing: 16.0) {
                Image(viewData.headerImageName)

                Text(viewData.title)
                    .font(.system(size: 17, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(viewData.subtitle)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(.blackWhite80))

                if !viewData.entryViewViewDataList.isEmpty {
                    VStack(spacing: 16.0) {
                        ForEach(viewData.entryViewViewDataList) { itemData in
                            WaitlistListEntryView(viewData: itemData)
                        }
                    }
                    .padding(20.0)
                    .frame(maxWidth: .infinity)
                    .background(Color.blackWhite1)
                        .border(.blackWhite5)
                }

                Text(viewData.availabilityDisclaimer)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 12))
                    .foregroundColor(Color(.blackWhite60))
            }
        } buttons: {
            Button(viewData.buttonDismissLabel) {
                Task {
                    await model.perform(action: .close)
                }
            }

            Button(viewData.buttonGetStartedLabel) {
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
    let viewData: WaitlistEntryViewItemViewData

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(viewData.imageName)
                .frame(maxWidth: 16, maxHeight: 16)

            VStack(alignment: .leading, spacing: 6) {
                Text(viewData.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(.blackWhite80))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(viewData.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color(.blackWhite60))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
    }
}

struct WaitlistEntryViewItemViewData: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
    let subtitle: String
}
