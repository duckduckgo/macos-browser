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
//import MacroLib


//@attached(member, names: named(Dependencies), named(DynamicDependencies), named(DependencyProvider), named(DynamicDependencyProvider), named(dependencyProvider), named(_currentDependencies), named(getAllDependencyProviderKeyPaths(from:)), named(makeDependencies), named(make))
//@attached(memberAttribute)
//@attached(peer, names: suffixed(_DependencyProvider), suffixed(_DependencyProvider_allKeyPaths), suffixed(_DynamicDependencyProvider))
//public macro Injectable() = #externalMacro(module: "DuckMacroPlugin", type: "InjectableMacro")
//
//@attached(accessor)
//public macro Injected() = #externalMacro(module: "DuckMacroPlugin", type: "InjectedMacro")
//
////@freestanding(declaration, names: arbitrary)
////public macro InjectedDependencies(for type: Any.Type) = #externalMacro(module: "DuckMacroPlugin", type: "InjectedDependenciesMacro")
//@attached(conformance)
//@attached(member, names: arbitrary)
//public macro InjectedDependencies(for type: Any.Type...) = #externalMacro(module: "DuckMacroPlugin", type: "InjectedDependenciesMacro")

//@Injectable
@MainActor
final class AppStateRestorationManager: NSObject/*, Injectable*/ {

//    typealias InjectedDependencies = WindowManagerStateRestoration.Dependencies
    //@Injected var a: Int
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
            let isCalledAtStartup = !interactive
//            let dd: DD = self.dependencyProvider
//            let a: AppStateRestorationManager.DynamicDependencyProvider = dd
//            let b: WindowManagerStateRestoration.DynamicDependencyProvider = a
//            let d: Subclass.DynamicDependencyProvider = dd
            fatalError()
//            try service.restoreState(using: { coder in
//                try WindowsManager.restoreState(from: coder, dependencyProvider: b, includePinnedTabs: isCalledAtStartup)
//            })
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
            fatalError()
//            try service.restoreState(using: { coder in
//                try WindowsManager.restoreState(from: coder, dependencyProvider: self.dependencyProvider, includeWindows: false)
//            })
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
