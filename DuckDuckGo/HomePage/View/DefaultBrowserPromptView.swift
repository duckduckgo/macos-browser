//
//  DefaultBrowserPromptView.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

struct DefaultBrowserPrompt: View {

    @EnvironmentObject var model: HomePage.Models.DefaultBrowserModel

    var body: some View {

            HStack {
                Spacer()

                Image("DefaultBrowser")
                    .frame(width: 32, height: 32)

                Text(UserText.defaultBrowserPromptMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color("HomeDefaultBrowserPromptTextColor"))

                let button = Button(UserText.defaultBrowserPromptButton) {
                    self.model.requestSetDefault()
                }

                button.buttonStyle(.bordered)

                Spacer()

                HoverButton(imageName: "Close", imageSize: 22, cornerRadius: 4) {
                    self.model.close()
                }.padding()

            }.background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("HomeDefaultBrowserPromptBackgroundColor"))
            )
            .visibility(model.shouldShow ? .visible : .gone)
            .padding(.top, 24)

    }

}
