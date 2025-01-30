//
//  PreferencesEmailProtectionView.swift
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

import AppKit
import Combine
import PreferencesUI_macOS
import SwiftUI
import SwiftUIExtensions
import BrowserServicesKit

extension Preferences {
    struct EmailProtectionView: View, PreferencesTabOpening {
        var emailManager: EmailManager
        @ObservedObject var protectionStatus: PrivacyProtectionStatus = PrivacyProtectionStatus.status(for: .emailProtection)

        var body: some View {
            PreferencePane(UserText.emailProtectionPreferences, spacing: 4) {

                // SECTION 1: Status Indicator
                PreferencePaneSection {
                    StatusIndicatorView(status: protectionStatus.status ?? .off, isLarge: true)
                }

                // SECTION 2: Description
                PreferencePaneSection {
                    VStack(alignment: .leading, spacing: 1) {
                        TextMenuItemCaption(UserText.emailProtectionExplanation)
                        TextButton(UserText.learnMore) {
                            openNewTab(with: .duckDuckGoEmailInfo)
                        }
                    }
                }

                // SECTION 3: Current Account Info
                PreferencePaneSection {
                    if emailManager.isSignedIn {
                        if let userEmail = emailManager.userEmail {
                            Text(UserText.autofillEnabledFor) + Text(" \(userEmail)").bold()
                        }
                        Button(UserText.emailOptionsMenuManageAccountSubItem + "…") {
                            openNewTab(with: EmailUrls().emailProtectionAccountLink)
                        }
                        Button(UserText.emailOptionsMenuTurnOffSubItem) {
                            let alert = NSAlert.disableEmailProtection()
                            let response = alert.runModal()
                            if response == .alertFirstButtonReturn {
                                try? emailManager.signOut()
                            }
                        }

                        // Support
                        PreferencePaneSubSection {
                            TextButton(UserText.support) {
                                openNewTab(with: EmailUrls().emailProtectionSupportLink)
                            }
                        }
                    } else {
                        Button(UserText.emailOptionsMenuTurnOnSubItem + "…") {
                            openNewTab(with: EmailUrls().emailProtectionLink)
                        }
                    }
                }
            }
        }
    }
}
