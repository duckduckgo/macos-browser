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

    static func terms() -> String {
        return """
    Privacy Policy

    • We don’t ask for any personal information from you in order to use this beta service.
    • This Privacy Policy is for our limited waitlist beta VPN product.
    • Our main Privacy Policy also applies here.

    We don’t keep any logs of your online activity.

    That means we have no way to tie what you do online to you as an individual and we don’t have any record of things like:
    • Website visits
    • DNS requests
    • Connections made
    • IP addresses used
    • Session lengths

    We only keep anonymous performance metrics that we cannot connect to your online activity.

    • Our servers store generic usage (for example, CPU load) and diagnostic data (for example, errors), but none of that data is connected to any individual’s activity.
    We use this non-identifying information to monitor and ensure the performance and quality of the service, for example to make sure servers aren’t overloaded.
    """
    }

    @EnvironmentObject var model: WaitlistViewModel

    var body: some View {
        WaitlistDialogView {
            VStack(spacing: 16.0) {
                Text("Network Protection Beta\nService Terms and Privacy Policy")
                    .font(.system(size: 17, weight: .bold))
                    .multilineTextAlignment(.center)

                Group {
                    ScrollView {
                        Text(Self.terms())
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
                model.perform(action: .acceptTermsAndConditions)
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
        .environmentObject(model)
    }
}
