//
//  AboutModel.swift
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
import Common

final class AboutModel: ObservableObject {
    let appVersion = AppVersion()
    private let netPInvitePresenter: NetworkProtectionInvitePresenting

    init(netPInvitePresenter: NetworkProtectionInvitePresenting) {
        self.netPInvitePresenter = netPInvitePresenter
    }

    let displayableAboutURL: String = URL.aboutDuckDuckGo
        .toString(decodePunycode: false, dropScheme: true, needsWWW: false, dropTrailingSlash: false)

    @MainActor
    func openURL(_ url: URL) {
        WindowControllersManager.shared.show(url: url, newTab: true)
    }

    @MainActor
    func openFeedbackForm() {
        FeedbackPresenter.presentFeedbackForm()
    }

    func displayNetPInvite() {
        netPInvitePresenter.present()
    }
}
