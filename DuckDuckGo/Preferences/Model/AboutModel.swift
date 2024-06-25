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
import Combine

final class AboutModel: ObservableObject, PreferencesTabOpening {

    enum UpdateState {

        case loading
        case upToDate
        case newVersionAvailable

        init(from update: Update?, isLoading: Bool) {
            if isLoading {
                self = .loading
            } else {
                if update != nil {
                    self = .newVersionAvailable
                } else {
                    self = .upToDate
                }
            }
        }
    }

    @Published var updateState = UpdateState.upToDate
    let appVersion = AppVersion()
    weak var updateController: UpdateControllerProtocol?

    init(updateController: UpdateControllerProtocol) {
        self.updateController = updateController
        subscribeToUpdateInfo(updateController: updateController)
        refreshUpdateState()
    }

    private var cancellable: AnyCancellable?

    let displayableAboutURL: String = URL.aboutDuckDuckGo
        .toString(decodePunycode: false, dropScheme: true, dropTrailingSlash: false)

    var lastUpdateCheckDate: Date? {
        updateController?.lastUpdateCheckDate
    }

    @MainActor
    func openFeedbackForm() {
        FeedbackPresenter.presentFeedbackForm()
    }

    func copy(_ value: String) {
        NSPasteboard.general.copy(value)
    }

    func checkForUpdate() {
        updateController?.checkForUpdateInBackground()
    }

    func restartToUpdate() {
        updateController?.runUpdate()
    }

    private func subscribeToUpdateInfo(updateController: UpdateControllerProtocol) {
        cancellable = updateController.availableUpdatePublisher
            .combineLatest(updateController.isUpdateBeingLoadedPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshUpdateState()
            }
    }

    private func refreshUpdateState() {
        guard let updateController else { return }
        updateState = UpdateState(from: updateController.availableUpdate, isLoading: updateController.isUpdateBeingLoaded)
    }

}
