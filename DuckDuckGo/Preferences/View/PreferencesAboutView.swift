//
//  PreferencesAboutView.swift
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
import SwiftUIExtensions

fileprivate extension Font {
    static let companyName: Font = .title
    static let privacySimplified: Font = {
        if #available(macOS 11.0, *) {
            return .title3.weight(.semibold)
        } else {
            return .system(size: 15, weight: .semibold)
        }
    }()
}

extension Preferences {

    struct AboutView: View {
        @ObservedObject var model: AboutModel

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(UserText.aboutDuckDuckGo)
                    .font(Const.Fonts.preferencePaneTitle)

                PreferencePaneSection {
                    HStack {
                        Image("AboutPageLogo")
                        VStack(alignment: .leading, spacing: 8) {
#if APPSTORE
                            Text(UserText.duckDuckGoForMacAppStore).font(.companyName)
#else
                            Text(UserText.duckDuckGo).font(.companyName)
#endif
                            Text(UserText.privacySimplified).font(.privacySimplified)

                            Text(UserText.versionLabel(version: model.appVersion.versionNumber, build: model.appVersion.buildNumber)).onTapGesture(count: 12) {
                                model.displayNetPInvite()
                            }
                        }
                    }
                    .padding(.bottom, 8)

                    TextButton(UserText.moreAt(url: model.displayableAboutURL)) {
                        model.openURL(.aboutDuckDuckGo)
                    }

                    TextButton(UserText.privacyPolicy) {
                        model.openURL(.privacyPolicy)
                    }

                    #if FEEDBACK
                    Button(UserText.sendFeedback) {
                        model.openFeedbackForm()
                    }
                    .padding(.top, 4)
                    #endif
                }
            }
        }
    }

}
