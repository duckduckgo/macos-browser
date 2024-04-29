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

import AppKit
import BrowserServicesKit
import Combine
import Foundation
import PixelKit
import Sparkle

#if SPARKLE

final class UpdateController: NSObject {

    enum Constants {
        static let internalChannelName = "internal-channel"
    }

    let willRelaunchAppPublisher: AnyPublisher<Void, Never>

    init(internalUserDecider: InternalUserDecider) {
        willRelaunchAppPublisher = willRelaunchAppSubject.eraseToAnyPublisher()
        self.internalUserDecider = internalUserDecider
        super.init()

        configureUpdater()
    }

    func checkForUpdates(_ sender: Any!) {
        if !SupportedOSChecker.isCurrentOSReceivingUpdates {
            showNotSupportedInfo()
        }

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

    private var updater: SPUStandardUpdaterController!
    private let willRelaunchAppSubject = PassthroughSubject<Void, Never>()

    private var internalUserDecider: InternalUserDecider

    private var updaterWindowsCancellable: AnyCancellable?

    private func configureUpdater() {
        // The default configuration of Sparkle updates is in Info.plist
        updater = SPUStandardUpdaterController(updaterDelegate: self, userDriverDelegate: self)

#if DEBUG
        updater.updater.automaticallyChecksForUpdates = false
        updater.updater.updateCheckInterval = 0
#endif

        subscribeToAppWindows()
    }

    func subscribeToAppWindows() {
        // observe updater windows and App isActive state
        updaterWindowsCancellable = NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)
            .compactMap { _ -> [NSWindow]? in
                let updaterWindows = NSApp.windows.filter {
                    ["SUUpdateAlert", "SUStatusController"].contains($0.windowController?.className)
                }
                guard !updaterWindows.isEmpty else { return nil }
                return updaterWindows
            }
            .removeDuplicates()
            .combineLatest(NSApp.isActivePublisher())
            .sink { (updaterWindows, appIsActive) in
                // display updater windows on top when the app is active
                for window in updaterWindows {
                    window.level = appIsActive ? .modalPanel: .normal
                }
            }
    }

    private func showNotSupportedInfo() {
        if NSAlert.osNotSupported().runModal() != .cancel {
            let url = Preferences.UnsupportedDeviceInfoBox.softwareUpdateURL
            NSWorkspace.shared.open(url)
        }
    }

}

extension UpdateController: SPUStandardUserDriverDelegate {
}

extension UpdateController: SPUUpdaterDelegate {

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
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
                Int(Sparkle.SUError.installationCanceledError.rawValue),
                Int(Sparkle.SUError.runningTranslocated.rawValue)].contains(errorCode) else {
            return
        }

        PixelKit.fire(DebugEvent(GeneralPixel.updaterAborted, error: error))
    }

    func updater(_ updater: SPUUpdater,
                 userDidMake choice: SPUUserUpdateChoice,
                 forUpdate updateItem: SUAppcastItem,
                 state: SPUUserUpdateState) {
        switch choice {
        case .skip:
            PixelKit.fire(DebugEvent(GeneralPixel.userSelectedToSkipUpdate))
        case .install:
            PixelKit.fire(DebugEvent(GeneralPixel.userSelectedToInstallUpdate))
        case .dismiss:
            PixelKit.fire(DebugEvent(GeneralPixel.userSelectedToDismissUpdate))
        @unknown default:
            break
        }
    }

}

#endif
