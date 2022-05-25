//
//  AppStateRestorationManager.swift
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
import os.log

final class AppStateRestorationManager: NSObject {
    static let fileName = "persistentState"

    private let service: StatePersistenceService
    private var appWillRelaunchCancellable: AnyCancellable?
    private var stateChangedCancellable: AnyCancellable?

    @UserDefaultsWrapper(key: .appIsRelaunchingAutomatically, defaultValue: false)
    private var appIsRelaunchingAutomatically: Bool
    private let shouldRestorePreviousSession: Bool

    convenience init(fileStore: FileStore) {
        let service = StatePersistenceService(fileStore: fileStore, fileName: AppStateRestorationManager.fileName)
        self.init(service: service)
    }

    init(
        service: StatePersistenceService,
        shouldRestorePreviousSession: Bool = StartupPreferences().restorePreviousSession
    ) {
        self.service = service
        self.shouldRestorePreviousSession = shouldRestorePreviousSession
    }

    func subscribeToAutomaticAppRelaunching(using relaunchPublisher: AnyPublisher<Void, Never>) {
        appWillRelaunchCancellable = relaunchPublisher
            .map { true }
            .assign(to: \.appIsRelaunchingAutomatically, onWeaklyHeld: self)
    }

    var canRestoreLastSessionState: Bool {
        service.canRestoreLastSessionState
    }

    func restoreLastSessionState(interactive: Bool) {
        do {
            try service.restoreState(using: WindowsManager.restoreState(from:))
        } catch CocoaError.fileReadNoSuchFile {
            // ignore
        } catch {
            os_log("App state could not be decoded: %s", "\(error)")
            Pixel.fire(
                .debug(event: .appStateRestorationFailed, error: error),
                withAdditionalParameters: ["interactive": String(interactive)]
            )
        }
    }

    func clearLastSessionState() {
        service.removeLastSessionState()
    }

    func applicationDidFinishLaunching() {
        let isRelaunchingAutomatically = appIsRelaunchingAutomatically
        appIsRelaunchingAutomatically = false
        readLastSessionState(restore: shouldRestorePreviousSession || isRelaunchingAutomatically)

        stateChangedCancellable = WindowControllersManager.shared.stateChanged
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            // There is a favicon assignment after a restored tab loads that triggered unnecessary
            // saving of the state
            .dropFirst()
            .sink { [weak self] _ in
                self?.persistAppState()
            }
    }

    func applicationWillTerminate() {
        stateChangedCancellable?.cancel()
        if WindowControllersManager.shared.isInInitialState {
            service.clearState(sync: true)
        } else {
            persistAppState(sync: true)
        }
    }

    private func readLastSessionState(restore: Bool) {
        service.loadLastSessionState()
        if restore {
            restoreLastSessionState(interactive: false)
        }
    }

    private func persistAppState(sync: Bool = false) {
        service.persistState(using: WindowControllersManager.shared.encodeState(with:), sync: sync)
    }
}
