//
//  AppTabMaker.swift
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

import AppKit

struct AppTabMaker {

    static let appTabURLKey = "com.duckduckgo.app-tab-url"

    func makeAppTab(named appName: String, for url: URL, icon: NSImage?, completionHandler: @escaping (Error?) -> Void) {
        let fm = FileManager.default
        let applications = fm.urls(for: .applicationDirectory, in: .userDomainMask).first
            ?? fm.urls(for: .applicationDirectory, in: .localDomainMask)[0]
        var destURL = applications.appendingPathComponent(appName + ".app")

        var counter = 1
        while fm.fileExists(atPath: destURL.path) {
            destURL = applications.appendingPathComponent(appName + " \(counter).app")
            counter += 1
        }

        makeAppTab(at: destURL, for: url, icon: icon, completionHandler: completionHandler)
    }

    func makeAppTab(at destURL: URL, for url: URL, icon: NSImage?, completionHandler: ((Error?) -> Void)? = nil) {
        let appURL = Bundle.main.bundleURL
        let fm = FileManager.default

        var nsError: NSError?
        var error: Error?

        NSFileCoordinator().coordinate(writingItemAt: destURL,
                                       options: .forReplacing,
                                       error: &nsError) { destURL in
            do {
                if fm.fileExists(atPath: destURL.path) {
                    _=try fm.replaceItemAt(destURL, withItemAt: appURL, backupItemName: nil, options: [])
                } else {
                    try fm.copyItem(at: appURL, to: destURL)
                }
            } catch let e {
                error = e
            }
        }
        if let error = error ?? nsError {
            completionHandler?(error)
            return
        }

        try? fm.setExtendedAttributeValue(url, forKey: Self.appTabURLKey, at: destURL)
        if let appIcon = icon?.makeAppIcon() {
            NSWorkspace.shared.setIcon(appIcon, forFile: destURL.path, options: [])
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        NSWorkspace.shared.openApplication(at: destURL, newInstance: true, userPrompts: false) { _, error in
            DispatchQueue.main.async {
                completionHandler?(error)
            }
        }
    }

}
