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

    var body: some View {
        WaitlistDialogView(innerPadding: 0) {
            VStack(spacing: 0) {
                Text("Network Protection Beta\nService Terms and Privacy Policy")
                    .font(.system(size: 17, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16.0)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(UserText.networkProtectionPrivacyPolicyTitle)
                            .font(.system(size: 15, weight: .bold))
                            .multilineTextAlignment(.leading)

                        Group {
                            Text(UserText.networkProtectionPrivacyPolicySection1Title).titleStyle()

                            if #available(macOS 12.0, *) {
                                Text(LocalizedStringKey(UserText.networkProtectionPrivacyPolicySection1ListMarkdown)).bodyStyle()
                            } else {
                                Text(UserText.networkProtectionPrivacyPolicySection1ListNonMarkdown).bodyStyle()
                            }

                            Text(UserText.networkProtectionPrivacyPolicySection2Title).titleStyle()
                            Text(UserText.networkProtectionPrivacyPolicySection2List).bodyStyle()
                            Text(UserText.networkProtectionPrivacyPolicySection3Title).titleStyle()
                            Text(UserText.networkProtectionPrivacyPolicySection3List).bodyStyle()
                            Text(UserText.networkProtectionPrivacyPolicySection4Title).titleStyle()
                            Text(UserText.networkProtectionPrivacyPolicySection4List).bodyStyle()
                            Text(UserText.networkProtectionPrivacyPolicySection5Title).titleStyle()
                            Text(UserText.networkProtectionPrivacyPolicySection5List).bodyStyle()
                        }

                        Text(UserText.networkProtectionTermsOfServiceTitle)
                            .font(.system(size: 15, weight: .bold))
                            .multilineTextAlignment(.leading)
                            .padding(.top, 28)
                            .padding(.bottom, 14)

                        Group {
                            Text(UserText.networkProtectionTermsOfServiceSection1Title).titleStyle(topPadding: 0)
                            Text(UserText.networkProtectionTermsOfServiceSection1List).bodyStyle()
                            Text(UserText.networkProtectionTermsOfServiceSection2Title).titleStyle()

                            if #available(macOS 12.0, *) {
                                Text(LocalizedStringKey(UserText.networkProtectionTermsOfServiceSection2ListMarkdown)).bodyStyle()
                            } else {
                                Text(UserText.networkProtectionTermsOfServiceSection2ListNonMarkdown).bodyStyle()
                            }

                            Text(UserText.networkProtectionTermsOfServiceSection3Title).titleStyle()
                            Text(UserText.networkProtectionTermsOfServiceSection3List).bodyStyle()
                            Text(UserText.networkProtectionTermsOfServiceSection4Title).titleStyle()
                            Text(UserText.networkProtectionTermsOfServiceSection4List).bodyStyle()
                            Text(UserText.networkProtectionTermsOfServiceSection5Title).titleStyle()
                            Text(UserText.networkProtectionTermsOfServiceSection5List).bodyStyle()
                        }

                        Group {
                            Text(UserText.networkProtectionTermsOfServiceSection6Title).titleStyle()
                            Text(UserText.networkProtectionTermsOfServiceSection6List).bodyStyle()
                            Text(UserText.networkProtectionTermsOfServiceSection7Title).titleStyle()
                            Text(UserText.networkProtectionTermsOfServiceSection7List).bodyStyle()
                            Text(UserText.networkProtectionTermsOfServiceSection8Title).titleStyle()
                            Text(UserText.networkProtectionTermsOfServiceSection8List).bodyStyle()
                        }
                    }
                    .padding(.all, 20)
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 500)
                // .background(Color("BlackWhite1"))
                // .border(Color("BlackWhite5"))
            }
        } buttons: {
            Button(UserText.networkProtectionWaitlistButtonCancel) {
                Task { await model.perform(action: .close) }
            }

            Button(UserText.networkProtectionWaitlistButtonAgreeAndContinue) {
                Task { await model.perform(action: .acceptTermsAndConditions) }
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
        .environmentObject(model)
    }
}

private extension Text {

    func titleStyle(topPadding: CGFloat = 24, bottomPadding: CGFloat = 14) -> some View {
        self
            .font(.system(size: 11, weight: .bold))
            .multilineTextAlignment(.leading)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
    }

    func bodyStyle() -> some View {
        self
            .font(.system(size: 11))
    }

}

#endif
