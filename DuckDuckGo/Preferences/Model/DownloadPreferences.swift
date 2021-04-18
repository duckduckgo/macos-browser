//
//  DownloadPreferences.swift
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

struct DownloadPreferences {

    private struct Keys {
        static let selectedDownloadLocationKey = "preferences.download-location"
        static let alwaysRequestDownloadLocationKey = "preferences.download-location.always-request"
    }

    var selectedDownloadLocation: URL? {
        get {
            if let selectedLocation = userDefaults.string(forKey: Keys.selectedDownloadLocationKey),
               let selectedLocationURL = URL(string: selectedLocation),
               downloadLocationIsValid(selectedLocationURL) {
                return selectedLocationURL
            }

            return defaultDownloadLocation()
        }

        set {
            guard let newDownloadLocation = newValue else {
                userDefaults.setValue(nil, forKey: Keys.selectedDownloadLocationKey)
                return
            }

            if downloadLocationIsValid(newDownloadLocation) {
                userDefaults.setValue(newDownloadLocation.absoluteString, forKey: Keys.selectedDownloadLocationKey)
            }
        }
    }

    @UserDefaultsWrapper(key: .alwaysRequestDownloadLocationKey, defaultValue: false)
    var alwaysRequestDownloadLocation: Bool

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func defaultDownloadLocation() -> URL? {
        let fileManager = FileManager.default
        let folders = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask)

        guard let folderURL = folders.first,
              let resolvedURL = try? URL(resolvingAliasFileAt: folderURL),
              fileManager.isWritableFile(atPath: resolvedURL.path) else { return nil }

        return resolvedURL
    }

    private func downloadLocationIsValid(_ directoryLocation: String) -> Bool {
        guard let directoryURL = URL(string: directoryLocation) else { return false }
        return downloadLocationIsValid(directoryURL)
    }

    private func downloadLocationIsValid(_ directoryLocation: URL) -> Bool {
        let fileManager = FileManager.default
        guard let resolvedURL = try? URL(resolvingAliasFileAt: directoryLocation) else { return false }

        return fileManager.isWritableFile(atPath: resolvedURL.path)
    }

}

extension DownloadPreferences: PreferenceSection {

    var displayName: String {
        return UserText.downloads
    }

    var preferenceIcon: NSImage {
        return NSImage(named: "Downloads")!
    }

}
