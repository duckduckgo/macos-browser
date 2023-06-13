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
import Common
import DependencyInjection

#if swift(>=5.9)
@Injectable
#endif
@MainActor
final class AppStateRestorationManager: NSObject, Injectable {

    typealias InjectedDependencies = TabCollectionViewModel.Dependencies

    static let fileName = "persistentState"

    @Injected
    var statePersistenceService: StatePersistenceService
    private var service: StatePersistenceService { statePersistenceService }

    private var appWillRelaunchCancellable: AnyCancellable?
    private var stateChangedCancellable: AnyCancellable?

    @UserDefaultsWrapper(key: .appIsRelaunchingAutomatically, defaultValue: false)
    private var appIsRelaunchingAutomatically: Bool
    private let shouldRestorePreviousSession: Bool

    @available(*, deprecated, message: "use AppStateRestorationManager.make")
    init(shouldRestorePreviousSession: Bool) {
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
            let isCalledAtStartup = !interactive
            try service.restoreState(using: { coder in
                try WindowsManager.restoreState(from: coder, dependencyProvider: dependencyProvider, includePinnedTabs: isCalledAtStartup)
            })
            clearLastSessionState()
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
        readLastSessionState(restoreWindows: shouldRestorePreviousSession || isRelaunchingAutomatically)

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

    private func readLastSessionState(restoreWindows: Bool) {
        service.loadLastSessionState()
        if restoreWindows {
            restoreLastSessionState(interactive: false)
        } else {
            restorePinnedTabs()
        }
        WindowControllersManager.shared.updateIsInInitialState()
    }

    @MainActor
    private func restorePinnedTabs() {
        do {
            try service.restoreState(using: { coder in
                try WindowsManager.restoreState(from: coder, dependencyProvider: self.dependencyProvider, includeWindows: false)
            })
        } catch CocoaError.fileReadNoSuchFile {
            // ignore
        } catch {
            os_log("Pinned tabs state could not be decoded: %s", "\(error)")
            Pixel.fire(.debug(event: .appStateRestorationFailed, error: error))
        }
    }

    @MainActor
    private func persistAppState(sync: Bool = false) {
        service.persistState(using: WindowControllersManager.shared.encodeState(with:), sync: sync)
    }
}
