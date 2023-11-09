//
//  FaviconsFetcherOnboardingView.swift
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

public struct FaviconsFetcherOnboardingView: View {

    public init(model: FaviconsFetcherOnboardingViewModel) {
        self.model = model
    }

    @ObservedObject public var model: FaviconsFetcherOnboardingViewModel

    public var body: some View {
        SyncDialog(spacing: 20.0) {
            VStack(alignment: .center, spacing: 20) {
                Image("Sync-setup-success")

                Text(UserText.fetchFaviconsOnboardingTitle)
                    .font(.system(size: 17, weight: .bold))

                Text(UserText.fetchFaviconsOnboardingMessage)
                    .frame(width: 320, alignment: .center)
                    .multilineTextAlignment(.center)
                    .fixedSize()

                VStack(spacing: 8) {
                    Text(UserText.optionsSectionDialogTitle)
                        .font(.system(size: 11))
                        .foregroundColor(Color("BlackWhite60"))
                    VStack {
                        Toggle(isOn: $model.isFaviconsFetchingEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(UserText.fetchFaviconsOnboardingOptionTitle)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color("BlackWhite80"))
                                Text(UserText.fetchFaviconsOnboardingOptionCaption)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color("BlackWhite60"))
                                    .frame(width: 254)
                                    .fixedSize()
                            }
                            .frame(width: 254)
                        }
                        .padding(.bottom, 13)
                        .padding(.top, 7)
                        .padding(.horizontal, 16)
                        .frame(height: 65)
                        .toggleStyle(.switch)
                        .roundedBorder()
                    }
                    .frame(width: 320)
                }
                .padding(.top, 32)
            }
            .frame(width: 320)
        } buttons: {
            Button("Dismiss") {
                model.onDismiss()
            }
        }
        .padding(.vertical, 20)
        .frame(width: 360, height: 386)
    }
}
