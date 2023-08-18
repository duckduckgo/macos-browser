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

                if !SupportedOSChecker.isCurrentOsSupported {
                    UnsupportedDeviceInfoBox(wide: true)
                        .padding(.top, 10)
                        .padding(.leading, -20)
                }

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
#if NETWORK_PROTECTION
                                model.displayNetPInvite()
#endif
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

    struct UnsupportedDeviceInfoBox: View {

        static let appleSupportURL = URL(string: "https://support.apple.com/en-us/HT211238")!

        var wide: Bool

        var width: CGFloat {
            return wide ? 510 : 320
        }

        var height: CGFloat {
            return wide ? 130 : 140
        }

        var osVersion: String {
            return "\(ProcessInfo.processInfo.operatingSystemVersion)"
        }

        var combinedText: String {
            return UserText.aboutUnsupportedDeviceInfo2Part1 + " " + UserText.aboutUnsupportedDeviceInfo2Part2 + " " + UserText.aboutUnsupportedDeviceInfo2Part3 + " " + UserText.aboutUnsupportedDeviceInfo2Part4
        }

        var body: some View {
            let image = Image("Alert-Color-16")
                .resizable()
                .frame(width: 16, height: 16)
                .padding(.trailing, 4)

            let versionText = Text(UserText.aboutUnsupportedDeviceInfo1(version: osVersion))

            let narrowContentView = Text(combinedText)

            let wideContentView: some View = VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 0) {
                    Text(UserText.aboutUnsupportedDeviceInfo2Part1 + " ")
                    Button(action: {
                        WindowControllersManager.shared.show(url: Self.appleSupportURL, newTab: true)
                    }) {
                        Text(UserText.aboutUnsupportedDeviceInfo2Part2 + " ")
                            .foregroundColor(Color.blue)
                            .underline()
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                    Text(UserText.aboutUnsupportedDeviceInfo2Part3)
                }
                Text(UserText.aboutUnsupportedDeviceInfo2Part4)
            }

            return HStack(alignment: .top) {
                image
                VStack(alignment: .leading, spacing: 12) {
                    versionText
                    if wide {
                        wideContentView
                    } else {
                        narrowContentView
                    }
                }
            }
            .padding()
            .background(Color(red: 254/255, green: 240/255, blue: 199/255))
            .cornerRadius(8)
            .frame(width: width, height: height)
        }
    }

}
