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
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96)

                Text(viewData.title)
                    .font(.system(size: 17, weight: .bold))

                Text(viewData.subtitle1)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(.blackWhite80))

                if !viewData.subtitle2.isEmpty {
                    Text(viewData.subtitle2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color(.blackWhite80))
                }

                Text(viewData.availabilityDisclaimer)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 12))
                    .foregroundColor(Color(.blackWhite60))
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
