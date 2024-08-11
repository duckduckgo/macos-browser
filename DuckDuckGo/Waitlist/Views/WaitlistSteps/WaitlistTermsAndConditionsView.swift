//
//  WaitlistTermsAndConditionsView.swift
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

protocol WaitlistTermsAndConditionsViewData {
    var title: String { get }
    var buttonCancelLabel: String { get }
    var buttonAgreeAndContinueLabel: String { get }
}

struct WaitlistTermsAndConditionsView<Content: View>: View {
    let viewData: WaitlistTermsAndConditionsViewData
    let content: Content
    @EnvironmentObject var model: WaitlistViewModel

    init(viewData: WaitlistTermsAndConditionsViewData, @ViewBuilder content: () -> Content) {
        self.viewData = viewData
        self.content = content()
    }

    var body: some View {
        WaitlistDialogView(innerPadding: 0) {
            VStack(spacing: 0) {
                Text(viewData.title)
                    .font(.system(size: 17, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16.0)

                Divider()

                ScrollView {
                    content
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 500)
            }
        } buttons: {
            Button(viewData.buttonCancelLabel) {
                Task { await model.perform(action: .close) }
            }

            Button(viewData.buttonAgreeAndContinueLabel) {
                Task { await model.perform(action: .acceptTermsAndConditions) }
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
        .environmentObject(model)
    }
}

private extension Text {

    func titleStyle(topPadding: CGFloat = 24, bottomPadding: CGFloat = 14) -> some View {
        self
            .font(.system(size: 11, weight: .bold))
            .multilineTextAlignment(.leading)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
    }

    func bodyStyle() -> some View {
        self
            .font(.system(size: 11))
    }

}
