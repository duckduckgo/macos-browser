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

struct DefaultBrowserPrompt: View {

    @EnvironmentObject var model: Homepage.Models.DefaultBrowserModel

    var body: some View {

        VStack {
            Spacer()

            HStack {
                HoverButton(imageName: "Close", imageSize: 22) {
                    self.model.close()
                }.padding()

                Spacer()

                Image("Logo")
                    .resizable(resizingMode: .stretch)
                    .frame(width: 38, height: 38)

                Text(UserText.defaultBrowserPromptMessage)
                    .font(.body)

                let button = Button(UserText.defaultBrowserPromptButton) {
                    self.model.requestSetDefault()
                }

                if #available(macOS 12.0, *) {
                    button.buttonStyle(.borderedProminent)
                } else {
                    button.buttonStyle(.bordered)
                }

                Spacer()
            }
            .background(Color("BrowserTabBackgroundColor").shadow(radius: 3))

        }.visibility(model.shouldShow ? .visible : .gone)

    }

}
