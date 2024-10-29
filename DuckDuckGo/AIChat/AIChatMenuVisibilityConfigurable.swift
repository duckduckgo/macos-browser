//
//  AIChatMenuVisibilityConfigurable.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import Combine
import BrowserServicesKit

protocol AIChatMenuVisibilityConfigurable {

    /// This property validates remote feature flags and user settings to determine if the shortcut
    /// should be presented to the user.
    ///
    /// - Returns: `true` if the application menu shortcut should be displayed; otherwise, `false`.
    var shouldDisplayApplicationMenuShortcut: Bool { get }

    /// This property checks the relevant settings to decide if the toolbar shortcut is to be shown.
    ///
    /// - Returns: `true` if the toolbar shortcut should be displayed; otherwise, `false`.
    var shouldDisplayToolbarShortcut: Bool { get }

    /// This property reflects the current state of the feature flag for the application menu shortcut.
    ///
    /// - Returns: `true` if the remote feature for the application menu shortcut is enabled; otherwise, `false`.
    var isFeatureEnabledForApplicationMenuShortcut: Bool { get }

    /// This property reflects the current state of the feature flag for the toolbar shortcut.
    ///
    /// - Returns: `true` if the remote feature for the toolbar shortcut is enabled; otherwise, `false`.
    var isFeatureEnabledForToolbarShortcut: Bool { get }

    /// A publisher that emits a value when either the `shouldDisplayApplicationMenuShortcut` or
    /// `shouldDisplayToolbarShortcut` settings, backed by storage, are changed.
    ///
    /// This allows subscribers to react to changes in the visibility settings of the application menu
    /// and toolbar shortcuts.
    ///
    /// - Returns: A `PassthroughSubject` that emits `Void` when the values change.
    var valuesChangedPublisher: PassthroughSubject<Void, Never> { get }

    /// A publisher that is triggered when it is validated that the onboarding should be displayed.
    ///
    /// This property listens to `AIChatOnboardingTabExtension` and triggers the publisher when a
    /// notification `AIChatOpenedForReturningUser`  is posted.
    ///
    /// - Returns: A `PassthroughSubject` that emits `Void` when the onboarding popover should be displayed.
    var shouldDisplayToolbarOnboardingPopover: PassthroughSubject<Void, Never> { get }

    /// Marks the toolbar onboarding popover as shown, preventing it from being displayed more than once.
    /// This method should be called after the onboarding popover has been presented to the user.
    func markToolbarOnboardingPopoverAsShown()
}

final class AIChatMenuConfiguration: AIChatMenuVisibilityConfigurable {
    enum ShortcutType {
        case applicationMenu
        case toolbar
    }

    private var cancellables = Set<AnyCancellable>()
    private var storage: AIChatPreferencesStorage
    private let notificationCenter: NotificationCenter
    private let remoteSettings: AIChatRemoteSettingsProvider

    var valuesChangedPublisher = PassthroughSubject<Void, Never>()
    var shouldDisplayToolbarOnboardingPopover = PassthroughSubject<Void, Never>()

    var isFeatureEnabledForApplicationMenuShortcut: Bool {
        isFeatureEnabledFor(shortcutType: .applicationMenu)
    }

    var isFeatureEnabledForToolbarShortcut: Bool {
        isFeatureEnabledFor(shortcutType: .toolbar)
    }

    var shouldDisplayToolbarShortcut: Bool {
        return isFeatureEnabledForToolbarShortcut && storage.shouldDisplayToolbarShortcut
    }

    var shouldDisplayApplicationMenuShortcut: Bool {
        return isFeatureEnabledForApplicationMenuShortcut && storage.showShortcutInApplicationMenu
    }

    func markToolbarOnboardingPopoverAsShown() {
        storage.didDisplayAIChatToolbarOnboarding = true
    }

    init(storage: AIChatPreferencesStorage = DefaultAIChatPreferencesStorage(),
         notificationCenter: NotificationCenter = .default,
         remoteSettings: AIChatRemoteSettingsProvider = AIChatRemoteSettings()) {
        self.storage = storage
        self.notificationCenter = notificationCenter
        self.remoteSettings = remoteSettings

        self.subscribeToValuesChanged()
        self.subscribeToAIChatLoadedNotification()
    }

    private func subscribeToAIChatLoadedNotification() {
        notificationCenter.publisher(for: .AIChatOpenedForReturningUser)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if !self.storage.didDisplayAIChatToolbarOnboarding && !storage.shouldDisplayToolbarShortcut {
                    self.shouldDisplayToolbarOnboardingPopover.send()
                }
            }.store(in: &cancellables)
    }

    private func subscribeToValuesChanged() {
        storage.shouldDisplayToolbarShortcutPublisher
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.valuesChangedPublisher.send()
            }.store(in: &cancellables)

        storage.showShortcutInApplicationMenuPublisher
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.valuesChangedPublisher.send()
            }.store(in: &cancellables)
    }

    private func isFeatureEnabledFor(shortcutType: ShortcutType) -> Bool {
        switch shortcutType {
        case .applicationMenu:
            return remoteSettings.isApplicationMenuShortcutEnabled
        case .toolbar:
            return remoteSettings.isToolbarShortcutEnabled
        }
    }
}
