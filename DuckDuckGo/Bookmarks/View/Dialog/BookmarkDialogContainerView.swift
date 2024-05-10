//
//  BookmarkDialogContainerView.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

struct BookmarkDialogContainerView<Content: View, Buttons: View>: View {
    private let title: String
    @ViewBuilder private let middleSection: () -> Content
    @ViewBuilder private let bottomSection: () -> Buttons

    init(
        title: String,
        @ViewBuilder middleSection: @escaping () -> Content,
        @ViewBuilder bottomSection: @escaping () -> Buttons
    ) {
        self.title = title
        self.middleSection = middleSection
        self.bottomSection = bottomSection
    }

    var body: some View {
        TieredDialogView(
            verticalSpacing: 16.0,
            horizontalPadding: 20.0,
            top: {
                Text(title)
                    .foregroundColor(.primary)
                    .fontWeight(.semibold)
                    .padding(.top, 20)
            },
            center: middleSection,
            bottom: {
                bottomSection()
                    .padding(.bottom, 16.0)
            }
        )
    }
}
