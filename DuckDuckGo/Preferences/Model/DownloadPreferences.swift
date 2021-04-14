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
        static let selectedDownloadLocationKey = "com.duckduckgo.macos.selectedDownloadLocation"
    }

    var selectedDownloadLocation: URL? {
        var location: URL?

        if let selectedLocation = userDefaults.string(forKey: Keys.selectedDownloadLocationKey) {
            location = URL(string: selectedLocation)
        }

        return location ?? defaultDownloadLocation()
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func select(downloadLocationURL: URL) {
        select(downloadLocation: downloadLocationURL.absoluteString)
    }

    func select(downloadLocation: String) {
        if pathIsValid(downloadLocation) {
            userDefaults.setValue(downloadLocation, forKey: Keys.selectedDownloadLocationKey)
        }
    }

    func pathIsValid(_ directoryUrl: String) -> Bool {
        let fileManager = FileManager.default
        guard let directoryURL = URL(string: directoryUrl),
              let resolvedURL = try? URL(resolvingAliasFileAt: directoryURL) else { return false }

        return fileManager.isWritableFile(atPath: resolvedURL.path)
    }

    private func defaultDownloadLocation() -> URL? {
        let fileManager = FileManager.default
        let folders = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask)

        guard let folderURL = folders.first,
              let resolvedURL = try? URL(resolvingAliasFileAt: folderURL),
              fileManager.isWritableFile(atPath: resolvedURL.path) else { return nil }

        return resolvedURL
    }

}

extension DownloadPreferences: Preference {

    var displayName: String {
        return UserText.downloads
    }

    var preferenceIcon: NSImage {
        return NSImage(named: "Downloads")!
    }

}
