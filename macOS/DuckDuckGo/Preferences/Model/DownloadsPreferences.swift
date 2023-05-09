//
//  DownloadsPreferences.swift
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

protocol DownloadsPreferencesPersistor {
    var selectedDownloadLocation: String? { get set }
    var lastUsedCustomDownloadLocation: String? { get set }

    var alwaysRequestDownloadLocation: Bool { get set }

    var defaultDownloadLocation: URL? { get }
    func isDownloadLocationValid(_ location: URL) -> Bool
}

struct DownloadsPreferencesUserDefaultsPersistor: DownloadsPreferencesPersistor {
    @UserDefaultsWrapper(key: .selectedDownloadLocationKey, defaultValue: nil)
    var selectedDownloadLocation: String?

    @UserDefaultsWrapper(key: .lastUsedCustomDownloadLocation, defaultValue: nil)
    var lastUsedCustomDownloadLocation: String?

    @UserDefaultsWrapper(key: .alwaysRequestDownloadLocationKey, defaultValue: false)
    var alwaysRequestDownloadLocation: Bool

    var defaultDownloadLocation: URL? {
        let fileManager = FileManager.default
        let folders = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask)

        guard let folderURL = folders.first,
              let resolvedURL = try? URL(resolvingAliasFileAt: folderURL),
              fileManager.isWritableFile(atPath: resolvedURL.path) else { return nil }

        return resolvedURL
    }

    func isDownloadLocationValid(_ directoryLocation: URL) -> Bool {
        let fileManager = FileManager.default
        guard let resolvedURL = try? URL(resolvingAliasFileAt: directoryLocation) else { return false }

        return fileManager.isWritableFile(atPath: resolvedURL.path)
    }
}

final class DownloadsPreferences: ObservableObject {

    private func validatedDownloadLocation(_ location: String?) -> URL? {
        if let selectedLocation = location,
           let selectedLocationURL = URL(string: selectedLocation),
           Self.isDownloadLocationValid(selectedLocationURL) {
            return selectedLocationURL
        }
        return nil
    }

    var effectiveDownloadLocation: URL? {
        if let selectedLocationURL = alwaysRequestDownloadLocation ? validatedDownloadLocation(persistor.lastUsedCustomDownloadLocation) : validatedDownloadLocation(persistor.selectedDownloadLocation) {
            return selectedLocationURL
        }
        return Self.defaultDownloadLocation()
    }

    var lastUsedCustomDownloadLocation: URL? {
        get {
            persistor.lastUsedCustomDownloadLocation?.url
        }

        set {
            defer {
                objectWillChange.send()
            }
            guard let newDownloadLocation = newValue else {
                persistor.lastUsedCustomDownloadLocation = nil
                return
            }

            if Self.isDownloadLocationValid(newDownloadLocation) {
                persistor.lastUsedCustomDownloadLocation = newDownloadLocation.absoluteString
            }
        }
    }

    var selectedDownloadLocation: URL? {
        get {
            persistor.selectedDownloadLocation?.url
        }

        set {
            defer {
                objectWillChange.send()
            }
            guard let newDownloadLocation = newValue else {
                persistor.selectedDownloadLocation = nil
                return
            }

            if Self.isDownloadLocationValid(newDownloadLocation) {
                persistor.selectedDownloadLocation = newDownloadLocation.absoluteString
            }
        }
    }

    var alwaysRequestDownloadLocation: Bool {
        get {
            persistor.alwaysRequestDownloadLocation
        }

        set {
            persistor.alwaysRequestDownloadLocation = newValue
            objectWillChange.send()
        }
    }

    func presentDownloadDirectoryPanel() {
        let panel = NSOpenPanel.downloadDirectoryPanel()
        let result = panel.runModal()

        if result == .OK, let selectedURL = panel.url {
            selectedDownloadLocation = selectedURL
        }
    }

    init(persistor: DownloadsPreferencesPersistor = DownloadsPreferencesUserDefaultsPersistor()) {
        self.persistor = persistor

        // Fix the selected download location if it needs it
        if selectedDownloadLocation == nil || !Self.isDownloadLocationValid(selectedDownloadLocation!) {
            selectedDownloadLocation = Self.defaultDownloadLocation()
        }
    }

    private var persistor: DownloadsPreferencesPersistor

    static func defaultDownloadLocation() -> URL? {
        let fileManager = FileManager.default
        let folders = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask)

        guard let folderURL = folders.first,
              let resolvedURL = try? URL(resolvingAliasFileAt: folderURL),
              fileManager.isWritableFile(atPath: resolvedURL.path) else { return nil }

        return resolvedURL
    }

    static func isDownloadLocationValid(_ directoryLocation: URL) -> Bool {
        let fileManager = FileManager.default
        guard let resolvedURL = try? URL(resolvingAliasFileAt: directoryLocation) else { return false }

        return fileManager.isWritableFile(atPath: resolvedURL.path)
    }
}
