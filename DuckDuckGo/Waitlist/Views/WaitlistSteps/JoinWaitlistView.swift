//
//  JoinWaitlistView.swift
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

struct JoinWaitlistView: View {
    @EnvironmentObject var model: WaitlistViewModel

    var body: some View {
        WaitlistDialogView {
            WaitlistInfoView(
                headerImageName: "JoinWaitlistHeader",
                title: "Network Protection Beta",
                subtitle: "Secure your network connection and keep your online activity private with Network Protection, a VPN from DuckDuckGo.",
                infoSectionTitle: "How it works:",
                infoSections: [
                    WaitlistInfoView.InfoSection(imageName: "Join-16", title: "Join the waitlist", subtitle: "Beta access is limited for now."),
                    WaitlistInfoView.InfoSection(imageName: "Timer-16", title: "Wait your turn", subtitle: "We send new invites every few days."),
                    WaitlistInfoView.InfoSection(imageName: "Gift-16", title: "Get your invite", subtitle: "We can notify you when it's your turn.")
                ]
            )
        } buttons: {
            Button("Close") {
                model.perform(action: .close)
            }

            Button("Join the Waitlist") {
                model.perform(action: .joinQueue)
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: model.viewState == .notOnWaitlist))
        }
        .environmentObject(model)
    }
}

struct WaitlistListEntryView: View {
    let imageName: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(imageName)
                .frame(maxWidth: 16, maxHeight: 16)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color("BlackWhite80"))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color("BlackWhite60"))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
    }
}
