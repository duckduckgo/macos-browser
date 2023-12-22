//
//  SyncUIViews.swift
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

enum SyncUIViews {

    struct TextHeader: View {
        let text: String

        var body: some View {
            Text(text)
                .bold()
                .font(.system(size: 17))
        }
    }

    struct TextHeader2: View {
        let text: String

        var body: some View {
            Text(text)
                .font(
                    .system(size: 17)
                    .weight(.semibold)
                )
        }
    }

    struct TextDetailMultiline: View {
        let text: String

        var body: some View {
            Text(text)
                .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                .multilineTextAlignment(.center)
        }
    }

    struct TextDetailSecondary: View {
        let text: String

        var body: some View {
            Text(text)
                .foregroundColor(Color("BlackWhite60"))
                .multilineTextAlignment(.center)
        }
    }

    struct TextLink: View {
        let text: String

        var body: some View {
            Text(text)
                .fontWeight(.semibold)
                .foregroundColor(Color("LinkBlueColor"))
        }
    }
}
