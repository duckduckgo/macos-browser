//
//  WaitlistTermsAndConditionsView.swift
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

#if NETWORK_PROTECTION || DBP

import SwiftUI
import SwiftUIExtensions

protocol WaitlistTermsAndConditionsViewData {
    var title: String { get }
    var buttonCancelLabel: String { get }
    var buttonAgreeAndContinueLabel: String { get }
}

struct WaitlistTermsAndConditionsView<Content: View>: View {
    let viewData: WaitlistTermsAndConditionsViewData
    let content: Content
    @EnvironmentObject var model: WaitlistViewModel

    init(viewData: WaitlistTermsAndConditionsViewData, @ViewBuilder content: () -> Content) {
        self.viewData = viewData
        self.content = content()
    }

    var body: some View {
        WaitlistDialogView(innerPadding: 0) {
            VStack(spacing: 0) {
                Text(viewData.title)
                    .font(.system(size: 17, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16.0)

                Divider()

                ScrollView {
                    content
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 500)
            }
        } buttons: {
            Button(viewData.buttonCancelLabel) {
                Task { await model.perform(action: .close) }
            }

            Button(viewData.buttonAgreeAndContinueLabel) {
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

#if NETWORK_PROTECTION

struct NetworkProtectionTermsAndConditionsContentView: View {
    var body: some View {
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
}

struct NetworkProtectionWaitlistTermsAndConditionsViewData: WaitlistTermsAndConditionsViewData {
    let title = "Network Protection Beta\nService Terms and Privacy Policy"
    let buttonCancelLabel = UserText.networkProtectionWaitlistButtonCancel
    let buttonAgreeAndContinueLabel = UserText.networkProtectionWaitlistButtonAgreeAndContinue
}

#endif

#if DBP

struct DataBrokerProtectionTermsAndConditionsContentView: View {
    private let groupLeadingPadding: CGFloat = 15.0
    private let sectionBottomPadding: CGFloat = 10.0

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {

            Text(UserText.dataBrokerProtectionPrivacyPolicyTitle)
                .font(.system(size: 15, weight: .bold))
                .multilineTextAlignment(.leading)

            Text("\nWe don’t save your personal information for this service to function.")
                .fontWeight(.bold)
                .padding(.bottom, sectionBottomPadding)

            Group {
                Text("• This Privacy Policy is for our waitlist beta service.")
                HStack(spacing: 0) {
                    Text("• Our main ")
                    Text("Privacy Policy ")
                        .foregroundColor(Color.blue)
                        .underline(color: .blue)
                        .onTapGesture {
                            if let url = URL(string: "https://duckduckgo.com/privacy") {
                                WindowsManager.openNewWindow(with: url, source: .ui, isBurner: false)
                            }
                        }
                    Text("also applies here.")
                }
                Text("• This beta product may collect more diagnostic data than our typical products. Examples of such data include: alerts of low memory, application restarts, and user engagement with product features.")
            }
            .padding(.leading, groupLeadingPadding)

            Text("\nYour personal information is stored locally on your device.")
                .fontWeight(.bold)
                .padding(.bottom, sectionBottomPadding)

            Group {
                Text("• The information you provide when you sign-up to use this service, for example your name, age, address, and phone number is stored on your device.")
                Text("• We then scan data brokers from your device to check if any sites contain your personal information.")
                Text("• We may find additional information on data broker sites through this scanning process, like alternative names or phone numbers, or the names of your relatives. This information is also stored locally on your device.")
            }
            .padding(.leading, groupLeadingPadding)

            Text("\nWe submit removal requests to data broker sites on your behalf.")
                .fontWeight(.bold)
                .padding(.bottom, sectionBottomPadding)

            Group {
                Text("• We submit removal requests to the data broker sites directly from your device, unlike other services where the removal process is initiated on remote servers.")
                Text("• The only personal information we may receive is a confirmation email from data broker sites which is deleted within 72 hours.")
                Text("• We regularly re-scan data broker sites to check on the removal status of your information. If it has reappeared, we resubmit the removal request.")
            }
            .padding(.leading, groupLeadingPadding)

            Text("\nTerms of Service")
                .fontWeight(.bold)

            Text("You must be eligible to use this service.")
                .fontWeight(.bold)
                .padding(.bottom, sectionBottomPadding)

            Group {
                Text("• To use this service, you must be 18 or older.")
            }
            .padding(.leading, groupLeadingPadding)

            Text("\nThe service is for limited and personal use only.")
                .fontWeight(.bold)
                .padding(.bottom, sectionBottomPadding)

            Group {
                Text("• The service is available for your personal use only. You represent and warrant that you will only initiate removal of your own personal information.")
                Text("• This service is available on one device only.")
            }
            .padding(.leading, groupLeadingPadding)

            Text("\nYou give DuckDuckGo authority to act on your Here's an updated version with the remaining content:")
                .fontWeight(.bold)
                .padding(.bottom, sectionBottomPadding)

            Group {
                Text("• You hereby authorize DuckDuckGo to act on your behalf to request removal of your personal information from data broker sites.")
                Text("• Because data broker sites often have multi-step processes required to have information removed, and because they regularly update their databases with new personal information, this authorization includes ongoing action on your behalf solely to perform the service.")
            }
            .padding(.leading, groupLeadingPadding)

            Text("\nThe service cannot remove all of your information from the Internet.")
                .fontWeight(.bold)
                .padding(.bottom, sectionBottomPadding)

            Group {
                Text("• This service requests removal from a limited number of data broker sites only. You understand that we cannot guarantee that the third-party sites will honor the requests, or that your personal information will not reappear in the future.")
                Text("• You understand that we will only be able to request the removal of information based upon the information you provide to us.")
            }
            .padding(.leading, groupLeadingPadding)

            Text("\nWe provide this beta service as-is, and without warranty.")
                .fontWeight(.bold)
                .padding(.bottom, sectionBottomPadding)

            Group {
                Text("• This service is provided as-is and without warranties or guarantees of any kind.")
                Text("• To the extent possible under applicable law, DuckDuckGo will not be liable for any damage or loss arising from your use of the service. In any event, the total aggregate liability of DuckDuckGo shall not exceed $25 or the equivalent in your local currency.")
                Text("• We may in the future transfer responsibility for the service to a subsidiary of DuckDuckGo. If that happens, you agree that references to “DuckDuckGo” will refer to our subsidiary, which will then become responsible for providing the service and for any liabilities relating to it.")
            }
            .padding(.leading, groupLeadingPadding)

            Text("\nWe may terminate access at any time.")
                .fontWeight(.bold)
                .padding(.bottom, sectionBottomPadding)

            Group {
                Text("• This service is in beta, and your access to it is temporary.")
                Text("• We reserve the right to terminate access at any time in our sole discretion, including for violation of these terms or our DuckDuckGo Terms of Service, which are incorporated by reference.")
            }
            .padding(.leading, groupLeadingPadding)

        }.padding(.all, 20)
    }
}

struct DataBrokerProtectionWaitlistTermsAndConditionsViewData: WaitlistTermsAndConditionsViewData {
    let title = "Personal Information Removal Beta\nService Terms and Privacy Policy"
    let buttonCancelLabel = UserText.dataBrokerProtectionWaitlistButtonCancel
    let buttonAgreeAndContinueLabel = UserText.dataBrokerProtectionWaitlistButtonAgreeAndContinue
}

#endif
