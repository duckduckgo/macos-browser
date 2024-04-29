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

#if DBP

struct DataBrokerProtectionTermsAndConditionsContentView: View {
    private let groupLeadingPadding: CGFloat = 15.0
    private let sectionBottomPadding: CGFloat = 10.0

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {

            Text(verbatim: UserText.dataBrokerProtectionPrivacyPolicyTitle)
                .font(.system(size: 15, weight: .bold))
                .multilineTextAlignment(.leading)

            Text(verbatim: "\nWe don’t save your personal information for this service to function.")
                .fontWeight(.bold)
                .padding(.bottom, sectionBottomPadding)

            Group {
                Text(verbatim: "• This Privacy Policy is for our waitlist beta service.")
                HStack(spacing: 0) {
                    Text(verbatim: "• Our main ")
                    Text(verbatim: "Privacy Policy ")
                        .foregroundColor(Color.blue)
                        .underline(color: .blue)
                        .onTapGesture {
                            let url = URL(string: "https://duckduckgo.com/privacy")!
                            WindowsManager.openNewWindow(with: url, source: .ui, isBurner: false)
                        }
                    Text(verbatim: "also applies here.")
                }
                Text(verbatim: "• This beta product may collect more diagnostic data than our typical products. Examples of such data include: alerts of low memory, application restarts, and user engagement with product features.")
            }
            .padding(.leading, groupLeadingPadding)

            Text(verbatim: "\nYour personal information is stored locally on your device.")
                .fontWeight(.bold)
                .padding(.bottom, sectionBottomPadding)

            Group {
                Text(verbatim: "• The information you provide when you sign-up to use this service, for example your name, age, address, and phone number is stored on your device.")
                Text(verbatim: "• We then scan data brokers from your device to check if any sites contain your personal information.")
                Text(verbatim: "• We may find additional information on data broker sites through this scanning process, like alternative names or phone numbers, or the names of your relatives. This information is also stored locally on your device.")
            }
            .padding(.leading, groupLeadingPadding)

            Text(verbatim: "\nWe submit removal requests to data broker sites on your behalf.")
                .fontWeight(.bold)
                .padding(.bottom, sectionBottomPadding)

            Group {
                Text(verbatim: "• We submit removal requests to the data broker sites directly from your device, unlike other services where the removal process is initiated on remote servers.")
                Text(verbatim: "• The only personal information we may receive is a confirmation email from data broker sites which is deleted within 72 hours.")
                Text(verbatim: "• We regularly re-scan data broker sites to check on the removal status of your information. If it has reappeared, we resubmit the removal request.")
            }
            .padding(.leading, groupLeadingPadding)

            Text(verbatim: "\nTerms of Service")
                .fontWeight(.bold)

            Text(verbatim: "You must be eligible to use this service.")
                .fontWeight(.bold)
                .padding(.bottom, sectionBottomPadding)

            Group {
                Text(verbatim: "• To use this service, you must be 18 or older.")
            }
            .padding(.leading, groupLeadingPadding)

            Text(verbatim: "\nThe service is for limited and personal use only.")
                .fontWeight(.bold)
                .padding(.bottom, sectionBottomPadding)

            Group {
                Text(verbatim: "• The service is available for your personal use only. You represent and warrant that you will only initiate removal of your own personal information.")
                Text(verbatim: "• This service is available on one device only.")
            }
            .padding(.leading, groupLeadingPadding)

            Text(verbatim: "\nYou give DuckDuckGo authority to act on your Here's an updated version with the remaining content:")
                .fontWeight(.bold)
                .padding(.bottom, sectionBottomPadding)

            Group {
                Text(verbatim: "• You hereby authorize DuckDuckGo to act on your behalf to request removal of your personal information from data broker sites.")
                Text(verbatim: "• Because data broker sites often have multi-step processes required to have information removed, and because they regularly update their databases with new personal information, this authorization includes ongoing action on your behalf solely to perform the service.")
            }
            .padding(.leading, groupLeadingPadding)

            Text(verbatim: "\nThe service cannot remove all of your information from the Internet.")
                .fontWeight(.bold)
                .padding(.bottom, sectionBottomPadding)

            Group {
                Text(verbatim: "• This service requests removal from a limited number of data broker sites only. You understand that we cannot guarantee that the third-party sites will honor the requests, or that your personal information will not reappear in the future.")
                Text(verbatim: "• You understand that we will only be able to request the removal of information based upon the information you provide to us.")
            }
            .padding(.leading, groupLeadingPadding)

            Text(verbatim: "\nWe provide this beta service as-is, and without warranty.")
                .fontWeight(.bold)
                .padding(.bottom, sectionBottomPadding)

            Group {
                Text(verbatim: "• This service is provided as-is and without warranties or guarantees of any kind.")
                Text(verbatim: "• To the extent possible under applicable law, DuckDuckGo will not be liable for any damage or loss arising from your use of the service. In any event, the total aggregate liability of DuckDuckGo shall not exceed $25 or the equivalent in your local currency.")
                Text(verbatim: "• We may in the future transfer responsibility for the service to a subsidiary of DuckDuckGo. If that happens, you agree that references to “DuckDuckGo” will refer to our subsidiary, which will then become responsible for providing the service and for any liabilities relating to it.")
            }
            .padding(.leading, groupLeadingPadding)

            Text(verbatim: "\nWe may terminate access at any time.")
                .fontWeight(.bold)
                .padding(.bottom, sectionBottomPadding)

            Group {
                Text(verbatim: "• This service is in beta, and your access to it is temporary.")
                Text(verbatim: "• We reserve the right to terminate access at any time in our sole discretion, including for violation of these terms or our DuckDuckGo Terms of Service, which are incorporated by reference.")
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
