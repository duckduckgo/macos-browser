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

final class AppStateRestorationManager {
    static let fileName = "persistentState"

    private let service: StatePersistenceService
    private var cancellable: AnyCancellable!

    init(fileStore: FileStore) {
        self.service = StatePersistenceService(fileStore: fileStore, fileName: AppStateRestorationManager.fileName)
    }

    var canRestoreState: Bool {
        service.canRestoreState
    }

    func restoreState(activateWindows: Bool = false) {
        do {
            if activateWindows {
                try service.restoreState(using: WindowsManager.restoreStateAndActivateWindows(from:))
            } else {
                try service.restoreState(using: WindowsManager.restoreState(from:))
            }
        } catch CocoaError.fileReadNoSuchFile {
            // ignore
        } catch {
            os_log("App state could not be decoded: %s", "\(error)")
            Pixel.fire(.debug(event: .appStateRestorationFailed, error: error))
        }
    }

    func applicationDidFinishLaunching() {
        if StartupPreferences().restorePreviousSession {
            restoreState()
        }

        cancellable = WindowControllersManager.shared.stateChanged
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            // There is a favicon assignment after a restored tab loads that triggered unnecessary
            // saving of the state
            .dropFirst()
            .sink { [weak self] _ in
                self?.stateDidChange()
            }
    }

    private func stateDidChange() {
        service.persistState(using: WindowControllersManager.shared.encodeState(with:))
    }

    func applicationWillTerminate() {
        cancellable.cancel()
        service.persistState(using: WindowControllersManager.shared.encodeState(with:), sync: true)
    }

}
