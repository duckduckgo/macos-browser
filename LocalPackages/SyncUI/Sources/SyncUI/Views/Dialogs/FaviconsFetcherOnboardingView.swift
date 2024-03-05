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
import SwiftUIExtensions

public struct FaviconsFetcherOnboardingView: View {

    public init(model: FaviconsFetcherOnboardingViewModel) {
        self.model = model
    }

    @ObservedObject public var model: FaviconsFetcherOnboardingViewModel

    public var body: some View {
        SyncDialog(spacing: 20.0) {

            VStack(alignment: .center, spacing: 20) {
                Image(.syncFetchFavicons)

                Text(UserText.fetchFaviconsOnboardingTitle)
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 320, alignment: .center)
                    .multilineTextAlignment(.center)
                    .fixedSize()

                Text(UserText.fetchFaviconsOnboardingMessage)
                    .frame(width: 320, alignment: .center)
                    .multilineTextAlignment(.center)
                    .fixedSize()
            }
            .frame(width: 320)

        } buttons: {

            Button(UserText.notNow) {
                model.onDismiss()
            }
            .buttonStyle(DismissActionButtonStyle())

            Button(UserText.keepFaviconsUpdated) {
                model.isFaviconsFetchingEnabled = true
                model.onDismiss()
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))

        }
        .frame(width: 360)
    }
}
