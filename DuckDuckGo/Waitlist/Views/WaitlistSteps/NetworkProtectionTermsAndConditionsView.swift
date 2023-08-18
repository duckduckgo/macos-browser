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

                ScrollView {
                    VStack(alignment: .leading, spacing: 8.0) {
                        Text(UserText.networkProtectionPrivacyPolicyTitle)
                            .font(.system(size: 17, weight: .bold))
                            .multilineTextAlignment(.leading)
                            .padding(.bottom, 16)

                        Group {
                            Text(UserText.networkProtectionPrivacyPolicySection1Title)
                                .font(.system(size: 15, weight: .bold))
                                .multilineTextAlignment(.leading)

                            Text(UserText.networkProtectionPrivacyPolicySection1List)

                            Text(UserText.networkProtectionPrivacyPolicySection2Title)
                                .font(.system(size: 15, weight: .bold))
                                .multilineTextAlignment(.leading)
                                .padding(.top, 10)

                            Text(UserText.networkProtectionPrivacyPolicySection2List)

                            Text(UserText.networkProtectionPrivacyPolicySection3Title)
                                .font(.system(size: 15, weight: .bold))
                                .multilineTextAlignment(.leading)
                                .padding(.top, 10)

                            Text(UserText.networkProtectionPrivacyPolicySection3List)

                            Text(UserText.networkProtectionPrivacyPolicySection4Title)
                                .font(.system(size: 15, weight: .bold))
                                .multilineTextAlignment(.leading)
                                .padding(.top, 10)

                            Text(UserText.networkProtectionPrivacyPolicySection4List)

                            Text(UserText.networkProtectionPrivacyPolicySection5Title)
                                .font(.system(size: 15, weight: .bold))
                                .multilineTextAlignment(.leading)
                                .padding(.top, 10)

                            Text(UserText.networkProtectionPrivacyPolicySection5List)
                        }

                        Text(UserText.networkProtectionTermsOfServiceTitle)
                            .font(.system(size: 17, weight: .bold))
                            .multilineTextAlignment(.leading)
                            .padding(.bottom, 16)
                            .padding(.top, 10)

                        Group {
                            Text(UserText.networkProtectionTermsOfServiceSection1Title)
                                .font(.system(size: 15, weight: .bold))
                                .multilineTextAlignment(.leading)

                            Text(UserText.networkProtectionTermsOfServiceSection1List)

                            Text(UserText.networkProtectionTermsOfServiceSection2Title)
                                .font(.system(size: 15, weight: .bold))
                                .multilineTextAlignment(.leading)
                                .padding(.top, 10)

                            Text(UserText.networkProtectionTermsOfServiceSection2List)

                            Text(UserText.networkProtectionTermsOfServiceSection3Title)
                                .font(.system(size: 15, weight: .bold))
                                .multilineTextAlignment(.leading)
                                .padding(.top, 10)

                            Text(UserText.networkProtectionTermsOfServiceSection3List)
                        }
                    }
                    .padding(20.0)
                }
                .frame(maxWidth: .infinity)
                .background(Color("BlackWhite1"))
                .border(Color("BlackWhite5"))
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
