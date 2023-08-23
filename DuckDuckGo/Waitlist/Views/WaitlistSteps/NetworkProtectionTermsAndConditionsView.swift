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

#if NETWORK_PROTECTION

import SwiftUI
import SwiftUIExtensions

struct NetworkProtectionTermsAndConditionsView: View {

    @EnvironmentObject var model: WaitlistViewModel

    let acceptingTermsAndConditions: Bool

    var body: some View {
        WaitlistDialogView {
            VStack(spacing: 16.0) {
                Text("Network Protection Beta\nService Terms and Privacy Policy")
                    .font(.system(size: 17, weight: .bold))
                    .multilineTextAlignment(.center)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8.0) {
                        Text(UserText.networkProtectionPrivacyPolicyTitle)
                            .font(.system(size: 13, weight: .bold))
                            .multilineTextAlignment(.leading)
                            .padding(.bottom, 10)

                        Group {
                            Text(UserText.networkProtectionPrivacyPolicySection1Title)
                                .titleStyle()

                            Text(UserText.networkProtectionPrivacyPolicySection1List)
                                .bodyStyle()

                            Text(UserText.networkProtectionPrivacyPolicySection2Title)
                                .titleStyle()
                                .padding(.top, 10)

                            Text(UserText.networkProtectionPrivacyPolicySection2List)
                                .bodyStyle()

                            Text(UserText.networkProtectionPrivacyPolicySection3Title)
                                .titleStyle()
                                .padding(.top, 10)

                            Text(UserText.networkProtectionPrivacyPolicySection3List)
                                .bodyStyle()

                            Text(UserText.networkProtectionPrivacyPolicySection4Title)
                                .titleStyle()
                                .padding(.top, 10)

                            Text(UserText.networkProtectionPrivacyPolicySection4List)
                                .bodyStyle()

                            Text(UserText.networkProtectionPrivacyPolicySection5Title)
                                .titleStyle()
                                .padding(.top, 10)

                            Text(UserText.networkProtectionPrivacyPolicySection5List)
                                .bodyStyle()
                        }

                        Text(UserText.networkProtectionTermsOfServiceTitle)
                            .font(.system(size: 13, weight: .bold))
                            .multilineTextAlignment(.leading)
                            .padding(.bottom, 10)
                            .padding(.top, 20)

                        Group {
                            Text(UserText.networkProtectionTermsOfServiceSection1Title)
                                .titleStyle()

                            Text(UserText.networkProtectionTermsOfServiceSection1List)
                                .bodyStyle()

                            Text(UserText.networkProtectionTermsOfServiceSection2Title)
                                .titleStyle()
                                .padding(.top, 10)

                            Text(UserText.networkProtectionTermsOfServiceSection2List)
                                .bodyStyle()

                            Text(UserText.networkProtectionTermsOfServiceSection3Title)
                                .titleStyle()
                                .padding(.top, 10)

                            Text(UserText.networkProtectionTermsOfServiceSection3List)
                                .bodyStyle()
                        }
                    }
                    .padding(20.0)
                }
                .frame(maxWidth: .infinity)
                .background(Color("BlackWhite1"))
                .border(Color("BlackWhite5"))
                .frame(maxHeight: 500)
            }
        } buttons: {
            Button(UserText.networkProtectionWaitlistButtonCancel) {
                Task { await model.perform(action: .close) }
            }

            Button(UserText.networkProtectionWaitlistButtonAgreeAndContinue) {
                Task { await model.perform(action: .acceptTermsAndConditions) }
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: !acceptingTermsAndConditions))
        }
        .environmentObject(model)
    }
}

private extension Text {

    func titleStyle() -> some View {
        self
            .font(.system(size: 11, weight: .bold))
            .multilineTextAlignment(.leading)
    }

    func bodyStyle() -> some View {
        self
            .font(.system(size: 11))
    }

}

#endif
