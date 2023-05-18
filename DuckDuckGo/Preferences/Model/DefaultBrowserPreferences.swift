//
//  DefaultBrowserPreferences.swift
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

import Foundation
import SwiftUI
import Combine
import Common

protocol DefaultBrowserProvider {
    var bundleIdentifier: String { get }
    var isDefault: Bool { get }
    func presentDefaultBrowserPrompt() throws
    func openSystemPreferences()
}

struct SystemDefaultBrowserProvider: DefaultBrowserProvider {

    enum SystemDefaultBrowserProviderError: Error {
        case unableToSetDefaultURLHandler
    }

    let bundleIdentifier: String

    var isDefault: Bool {
        guard let defaultBrowserURL = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "http://")!),
              let ddgBrowserURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        else {
            return false
        }

        return ddgBrowserURL == defaultBrowserURL
    }

    init(bundleIdentifier: String = AppVersion.shared.identifier) {
        var bundleID = bundleIdentifier
        #if DEBUG
        bundleID = bundleID.dropping(suffix: ".debug")
        #endif
        self.bundleIdentifier = bundleIdentifier
    }

    func presentDefaultBrowserPrompt() throws {
        let result = LSSetDefaultHandlerForURLScheme("http" as CFString, bundleIdentifier as CFString)
        if result != 0 {
            throw SystemDefaultBrowserProviderError.unableToSetDefaultURLHandler
        }
    }

    func openSystemPreferences() {
        // Apple provides a more general URL for opening System Preferences
        // in the form of "x-apple.systempreferences:com.apple.preference" but it doesn't support
        // opening the Appearance prefpane directly.
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Appearance.prefPane"))
    }
}

final class DefaultBrowserPreferences: ObservableObject {

    @Published private(set) var isDefault: Bool = false {
        didSet {
            // Temporary pixel for first time user import data
#if DEBUG
            if NSApp.isRunningUnitTests {
                return
            }
#endif
            if isDefault {
                let repetition = Pixel.Event.Repetition(key: Pixel.Event.setAsDefaultInitial.name)
                if repetition == .initial {
                    Pixel.fire(.setAsDefaultInitial)
                }
            }
        }
    }
    @Published private(set) var restorePreviousSession: Bool = false

    init(defaultBrowserProvider: DefaultBrowserProvider = SystemDefaultBrowserProvider()) {
        self.defaultBrowserProvider = defaultBrowserProvider

        appDidBecomeActiveCancellable = NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkIfDefault()
            }

        checkIfDefault()
    }

    func checkIfDefault() {
        isDefault = defaultBrowserProvider.isDefault
    }

    func becomeDefault(_ completion: ((Bool) -> Void)? = nil) {
        if let receiveValue = completion {
            // Skip initial value and wait for the next event (happening on appDidBecomeActive)
            // Take only one value, which ensures that the subscription is automatically disposed of.
            $isDefault.dropFirst().prefix(1).subscribe(
                Subscribers.Sink(receiveCompletion: { _ in }, receiveValue: receiveValue)
            )
        }

        do {
            try defaultBrowserProvider.presentDefaultBrowserPrompt()
        } catch {
            defaultBrowserProvider.openSystemPreferences()
        }
    }

    private var appDidBecomeActiveCancellable: AnyCancellable?
    private let defaultBrowserProvider: DefaultBrowserProvider
}
