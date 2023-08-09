//
//  NetworkProtectionTermsAndConditionsView.swift
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

struct NetworkProtectionTermsAndConditionsView: View {
    @EnvironmentObject var model: WaitlistViewModel

    var body: some View {
        WaitlistDialogView {
            VStack(spacing: 16.0) {
                Text("Network Protection Beta\nService Terms and Privacy Policy")
                    .font(.system(size: 17, weight: .bold))
                    .multilineTextAlignment(.center)

                Group {
                    ScrollView {
                        Text("TODO: actual terms and conditions go here")
                    }
                    .padding(20.0)
                }
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.01))
                .border(Color.black.opacity(0.06))
            }
        } buttons: {
            Button("Cancel") {
                model.perform(action: .close)
            }

            Button("Agree and Continue") {
                model.perform(action: .joinQueue)
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
    }
}
