//
//  AboutPreferences.swift
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
import Combine

final class AboutPreferences: ObservableObject, PreferencesTabOpening {

    static let shared = AboutPreferences()

#if SPARKLE
    @Published var updateState = UpdateState.upToDate

    var updateController: UpdateControllerProtocol? {
        return Application.appDelegate.updateController
    }

    var areAutomaticUpdatesEnabled: Bool {
        get {
            return updateController?.areAutomaticUpdatesEnabled ?? false
        }

        set {
            updateController?.areAutomaticUpdatesEnabled = newValue
        }
    }

    var lastUpdateCheckDate: Date? {
        updateController?.lastUpdateCheckDate
    }

    private var subscribed = false

#endif

    let appVersion = AppVersion()

    private var cancellable: AnyCancellable?

    let displayableAboutURL: String = URL.aboutDuckDuckGo
        .toString(decodePunycode: false, dropScheme: true, dropTrailingSlash: false)

    var isCurrentOsReceivingUpdates: Bool {
        return SupportedOSChecker.isCurrentOSReceivingUpdates
    }

    @MainActor
    func openFeedbackForm() {
        FeedbackPresenter.presentFeedbackForm()
    }

    func copy(_ value: String) {
        NSPasteboard.general.copy(value)
    }

#if SPARKLE
    func checkForUpdate() {
        updateController?.checkForUpdateSkippingRollout()
    }

    func runUpdate() {
        updateController?.runUpdate()
    }

    func subscribeToUpdateInfoIfNeeded() {
        guard let updateController, !subscribed else { return }

        cancellable = updateController.latestUpdatePublisher
            .combineLatest(updateController.updateProgressPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshUpdateState()
            }

        subscribed = true

        refreshUpdateState()
    }

    private func refreshUpdateState() {
        guard let updateController else { return }
        updateState = UpdateState(from: updateController.latestUpdate, progress: updateController.updateProgress)
    }
#endif

}
