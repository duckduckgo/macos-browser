//
//  DownloadsPreferencesModel.swift
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

final class DownloadsPreferencesModel: ObservableObject {

    @Published var selectedDownloadLocation: URL? {
        didSet {
            guard let newDownloadLocation = selectedDownloadLocation else {
                selectedDownloadLocationDefaultsValue = nil
                return
            }

            if Self.isDownloadLocationValid(newDownloadLocation) {
                selectedDownloadLocationDefaultsValue = newDownloadLocation.absoluteString
            }
        }
    }
    
    @Published var alwaysRequestDownloadLocation: Bool = false {
        didSet {
            alwaysRequestDownloadLocationDefaultsValue = alwaysRequestDownloadLocation
        }
    }

    func presentDownloadDirectoryPanel() {
        let panel = NSOpenPanel.downloadDirectoryPanel()
        let result = panel.runModal()

        if result == .OK, let selectedURL = panel.url {
            selectedDownloadLocation = selectedURL
        }
    }
    
    init() {
        alwaysRequestDownloadLocation = alwaysRequestDownloadLocationDefaultsValue
        selectedDownloadLocation = {
            if let selectedLocation = selectedDownloadLocationDefaultsValue,
               let selectedLocationURL = URL(string: selectedLocation),
               Self.isDownloadLocationValid(selectedLocationURL) {
                return selectedLocationURL
            }

            return defaultDownloadLocation()
        }()
    }

    @UserDefaultsWrapper(key: .selectedDownloadLocationKey, defaultValue: nil)
    private var selectedDownloadLocationDefaultsValue: String?

    @UserDefaultsWrapper(key: .alwaysRequestDownloadLocationKey, defaultValue: false)
    // swiftlint:disable:next identifier_name
    private var alwaysRequestDownloadLocationDefaultsValue: Bool

    private func defaultDownloadLocation() -> URL? {
        let fileManager = FileManager.default
        let folders = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask)

        guard let folderURL = folders.first,
              let resolvedURL = try? URL(resolvingAliasFileAt: folderURL),
              fileManager.isWritableFile(atPath: resolvedURL.path) else { return nil }

        return resolvedURL
    }

    private static func isDownloadLocationValid(_ directoryLocation: String) -> Bool {
        guard let directoryURL = URL(string: directoryLocation) else { return false }
        return isDownloadLocationValid(directoryURL)
    }

    private static func isDownloadLocationValid(_ directoryLocation: URL) -> Bool {
        let fileManager = FileManager.default
        guard let resolvedURL = try? URL(resolvingAliasFileAt: directoryLocation) else { return false }

        return fileManager.isWritableFile(atPath: resolvedURL.path)
    }
}
