//
//  FaviconService.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import Cocoa

protocol FaviconService {

    func fetchFavicon(_ faviconUrl: URL?, for host: String, isFromUserScript: Bool, completion: @escaping (NSImage?, Error?) -> Void)
    func getCachedFavicon(for host: String, mustBeFromUserScript: Bool) -> NSImage?
    func storeIfNeeded(favicon: NSImage, for host: String, isFromUserScript: Bool)

}

final class LocalFaviconService: FaviconService {

    static let shared = LocalFaviconService()

    private enum FaviconName {
        static let favicon = "favicon.ico"
    }

    private enum Favicon {
        static let duckDuckGo = NSImage(named: "HomeFavicon")!
    }
    
    private struct CacheEntry {
        let image: NSImage
        let isFromUserScript: Bool
    }
    
    private var cache = [String: CacheEntry]()
    private let queue = DispatchQueue(label: "LocalFaviconService queue", attributes: .concurrent)

    enum LocalFaviconServiceError: Error {
        case urlConstructionFailed
        case imageInitFailed
    }
    
    init() {
        initCache()

        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(themeChanged),
            name: NSNotification.Name(rawValue: "AppleInterfaceThemeChangedNotification"),
            object: nil)
    }

    private func initCache() {
        queue.async(flags: .barrier) {
            if let duckduckgoHost = URL.duckDuckGo.host {
                self.cache[duckduckgoHost] = CacheEntry(image: Favicon.duckDuckGo, isFromUserScript: true)
            }
        }
    }

    func fetchFavicon(_ faviconUrl: URL?, for host: String, isFromUserScript: Bool, completion: @escaping (NSImage?, Error?) -> Void) {

        func mainQueueCompletion(_ favicon: NSImage?, _ error: Error?) {
            DispatchQueue.main.async {
                completion(favicon, error)
            }
        }

        queue.async {
            if let cachedFavicon = self.getCachedFavicon(for: host, mustBeFromUserScript: isFromUserScript) {
                mainQueueCompletion(cachedFavicon, nil)
                return
            }

            guard let url = faviconUrl ?? URL(string: "\(URL.NavigationalScheme.https.separated())\(host)/\(FaviconName.favicon)") else {
                mainQueueCompletion(nil, LocalFaviconServiceError.urlConstructionFailed)
                return
            }

            guard let image = NSImage(contentsOf: url), image.isValid else {
                if let newHost = host.dropSubdomain(), faviconUrl == nil {
                    self.fetchFavicon(nil, for: newHost, isFromUserScript: isFromUserScript, completion: completion)
                } else {
                    mainQueueCompletion(nil, LocalFaviconServiceError.imageInitFailed)
                }
                return
            }

            self.storeIfNeeded(favicon: image, for: host, isFromUserScript: isFromUserScript)
            mainQueueCompletion(image, nil)
        }
    }

    func storeIfNeeded(favicon: NSImage, for host: String, isFromUserScript: Bool) {
        queue.async(flags: .barrier) {
            // Don't replace a favicon from the UserScript with one that isn't from the UserScript
            if let entry = self.cache[host],
               entry.isFromUserScript && !isFromUserScript {
                return
            }
            self.cache[host] = CacheEntry(image: favicon, isFromUserScript: isFromUserScript)
        }
    }

    func getCachedFavicon(for host: String, mustBeFromUserScript: Bool) -> NSImage? {
        guard let entry = cache[host] else { return nil }
        if mustBeFromUserScript && !entry.isFromUserScript {
            return nil
        }
        return entry.image
    }
    
    @objc func themeChanged() {
        invalidateCache()
    }
    
    private func invalidateCache() {
        cache = [String: CacheEntry]()
    }

}
