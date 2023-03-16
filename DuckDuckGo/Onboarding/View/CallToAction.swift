//
//  CallToAction.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

extension Onboarding {

struct CallToAction: View {

    let text: String
    let cta: String

    let onNext: () -> Void

    @State var typingFinished = false

    var body: some View {
        VStack(spacing: 15) {
            DaxSpeech(text: text) {
                withAnimation {
                    typingFinished = true
                }
            }

            Button {
                withAnimation {
                    onNext()
                }
            } label: {
                Text(cta)
            }
            .frame(width: speechWidth)
            .buttonStyle(ActionButtonStyle())
            .visibility(typingFinished ? .visible : .gone)
        }
    }

}

}
