//
//  SyncPreferencesRow.swift
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

struct SyncPreferencesRow<ImageContent, CenterContent, RightContent>: View where ImageContent: View, CenterContent: View, RightContent: View {

    let imageContent: () -> ImageContent
    let centerContent: () -> CenterContent
    let rightContent: () -> RightContent

    init(
        @ViewBuilder imageContent: @escaping () -> ImageContent,
        @ViewBuilder centerContent: @escaping () -> CenterContent,
        @ViewBuilder rightContent: @escaping () -> RightContent = { EmptyView() }
    ) {
        self.imageContent = imageContent
        self.centerContent = centerContent
        self.rightContent = rightContent
    }

    var body: some View {
        HStack(spacing: 12) {
            imageContent()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
            centerContent()
            Spacer()
            rightContent()
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 40)
    }

}
