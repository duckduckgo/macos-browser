//
//  UpdateController.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import Foundation
import Combine
import Sparkle

final class UpdateController: NSObject {

    enum Constants {
        static let internalChannelName = "internal-channel"
    }

    let willRelaunchAppPublisher: AnyPublisher<Void, Never>

    init(internalUserDecider: InternalUserDeciding) {
        willRelaunchAppPublisher = willRelaunchAppSubject.eraseToAnyPublisher()
        self.internalUserDecider = internalUserDecider
        super.init()

        configureUpdater()
    }

    func checkForUpdates(_ sender: Any!) {
        NSApp.windows.forEach {
            if let controller = $0.windowController, "\(type(of: controller))" == "SUUpdateAlert" {
                $0.orderFrontRegardless()
                $0.makeKey()
                $0.makeMain()
            }
        }
        updater.checkForUpdates(sender)
    }

    // MARK: - Private

    lazy private var updater = SPUStandardUpdaterController(updaterDelegate: self, userDriverDelegate: self)
    private let willRelaunchAppSubject = PassthroughSubject<Void, Never>()

    private var internalUserDecider: InternalUserDeciding

    private func configureUpdater() {
    // The default configuration of Sparkle updates is in Info.plist
#if DEBUG
        updater.updater.automaticallyChecksForUpdates = false
        updater.updater.updateCheckInterval = 0
#endif
    }

}

extension UpdateController: SPUStandardUserDriverDelegate {

}

extension UpdateController: SPUUpdaterDelegate {

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        guard updater == self.updater.updater else {
            return Set()
        }

        if internalUserDecider.isInternalUser {
            return Set([Constants.internalChannelName])
        } else {
            return Set()
        }
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        willRelaunchAppSubject.send()
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let errorCode = (error as NSError).code
        guard ![Int(Sparkle.SUError.noUpdateError.rawValue),
                Int(Sparkle.SUError.installationCanceledError.rawValue)].contains(errorCode) else {
            return
        }

        Pixel.fire(.debug(event: .updaterAborted, error: error))
    }

    func updater(_ updater: SPUUpdater,
                 userDidMake choice: SPUUserUpdateChoice,
                 forUpdate updateItem: SUAppcastItem,
                 state: SPUUserUpdateState) {
        switch choice {
        case .skip:
            Pixel.fire(.debug(event: .userSelectedToSkipUpdate))
        case .install:
            Pixel.fire(.debug(event: .userSelectedToInstallUpdate))
        case .dismiss:
            Pixel.fire(.debug(event: .userSelectedToDismissUpdate))
        @unknown default:
            break
        }
    }

}
