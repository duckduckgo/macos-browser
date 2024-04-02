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
    var shouldOpenPopupOnCompletion: Bool { get set }

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

    @UserDefaultsWrapper(key: .openDownloadsPopupOnCompletionKey, defaultValue: true)
    var shouldOpenPopupOnCompletion: Bool

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

    static let shared = DownloadsPreferences(persistor: DownloadsPreferencesUserDefaultsPersistor())

    private func validatedDownloadLocation(_ selectedLocation: URL?) -> URL? {
        if let selectedLocation, Self.isDownloadLocationValid(selectedLocation) {
            return selectedLocation
        }
        return nil
    }

    var effectiveDownloadLocation: URL? {
        if alwaysRequestDownloadLocation {
            if let lastUsedCustomDownloadLocation = validatedDownloadLocation(persistor.lastUsedCustomDownloadLocation.flatMap(URL.init(string:))) {
                return lastUsedCustomDownloadLocation
            }
        } else if let selectedLocationURL = validatedDownloadLocation(selectedDownloadLocation) {
            return selectedLocationURL
        }
        return Self.defaultDownloadLocation()
    }

    var lastUsedCustomDownloadLocation: URL? {
        get {
            let url = persistor.lastUsedCustomDownloadLocation?.url
            var isDirectory: ObjCBool = false
            guard let url, FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                return nil
            }
            return url
        }
        set {
            defer {
                objectWillChange.send()
            }

            persistor.lastUsedCustomDownloadLocation = newValue?.absoluteString
        }
    }

    private var _selectedDownloadLocation: URL?
    private var isUsingSecurityScopedResource = false
    var selectedDownloadLocation: URL? {
        get {
            if let selectedDownloadLocation = _selectedDownloadLocation {
                return selectedDownloadLocation
            }
#if APPSTORE
            var isStale = false
            if let bookmarkData = persistor.selectedDownloadLocation.flatMap({ Data(base64Encoded: $0) }),
               let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                if isStale {
                    setSelectedDownloadLocation(url) // update bookmark data
                }
                if !isUsingSecurityScopedResource {
                    isUsingSecurityScopedResource = url.startAccessingSecurityScopedResource()
                }

                _selectedDownloadLocation = url
                return url
            }
#endif
            guard let url = persistor.selectedDownloadLocation.flatMap(URL.init(string:)),
                  url.isFileURL else { return nil }
            return url
        }
        set {
            defer {
                objectWillChange.send()
            }

            if isUsingSecurityScopedResource,
               let newValue, _selectedDownloadLocation /* oldValue */ != newValue {
                selectedDownloadLocation?.stopAccessingSecurityScopedResource()
            }
            // the setter is called for already selected directory,
            // so consume the unbalanced startAccessingSecurityScopedResource
            isUsingSecurityScopedResource = true

            setSelectedDownloadLocation(validatedDownloadLocation(newValue))
        }
    }
    private func setSelectedDownloadLocation(_ url: URL?) {
        _selectedDownloadLocation = url
        let locationString: String?
#if APPSTORE
        locationString = (try? url?.bookmarkData(options: .withSecurityScope).base64EncodedString()) ?? url?.absoluteString
#else
        locationString = url?.absoluteString
#endif
        persistor.selectedDownloadLocation = locationString
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

    var shouldOpenPopupOnCompletion: Bool {
        get {
            persistor.shouldOpenPopupOnCompletion
        }
        set {
            persistor.shouldOpenPopupOnCompletion = newValue
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

    init(persistor: DownloadsPreferencesPersistor) {
        self.persistor = persistor

        // Fix the selected download location if it needs it
        if selectedDownloadLocation == nil || !Self.isDownloadLocationValid(selectedDownloadLocation!) {
            selectedDownloadLocation = Self.defaultDownloadLocation()
        }
    }

    private var persistor: DownloadsPreferencesPersistor

    static func defaultDownloadLocation(validate: Bool = true) -> URL? {
        let fileManager = FileManager.default
        let folders = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask)

        guard let folderURL = folders.first,
              let resolvedURL = try? URL(resolvingAliasFileAt: folderURL),
              fileManager.isWritableFile(atPath: resolvedURL.path) || !validate else { return nil }

        return resolvedURL
    }

    static func isDownloadLocationValid(_ directoryLocation: URL) -> Bool {
        let fileManager = FileManager.default
        guard let resolvedURL = try? URL(resolvingAliasFileAt: directoryLocation) else { return false }

        return fileManager.isWritableFile(atPath: resolvedURL.path)
    }
}
