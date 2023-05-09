//
//  FaviconImageCache.swift
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
import BrowserServicesKit

final class FaviconImageCache {

    private let storing: FaviconStoring

    private var entries = [URL: Favicon]()

    private var cancellables = Set<AnyCancellable>()

    init(faviconStoring: FaviconStoring) {
        storing = faviconStoring
    }

    private(set) var loaded = false

    func loadFavicons(completionHandler: ((Error?) -> Void)? = nil) {
        storing.loadFavicons()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    os_log("Favicons loaded successfully", log: .favicons)
                    completionHandler?(nil)
                case .failure(let error):
                    os_log("Loading of favicons failed: %s", log: .favicons, type: .error, error.localizedDescription)
                    completionHandler?(error)
                }
            }, receiveValue: { [weak self] favicons in
                favicons.forEach { favicon in
                    self?.entries[favicon.url] = favicon
                }
                self?.loaded = true
            })
            .store(in: &self.cancellables)
    }

    func insert(_ favicon: Favicon) {
        guard loaded else { return }

        // Remove existing favicon with the same URL
        if let oldFavicon = entries[favicon.url] {
            removeFaviconsFromStore([oldFavicon])
        }

        // Save the new one
        entries[favicon.url] = favicon
        storing.save(favicon: favicon)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    os_log("Favicon saved successfully. URL: %s", log: .favicons, favicon.url.absoluteString)
                    NotificationCenter.default.post(name: .faviconCacheUpdated, object: nil)
                case .failure(let error):
                    os_log("Saving of favicon failed: %s", log: .favicons, type: .error, error.localizedDescription)
                }
            }, receiveValue: {})
            .store(in: &self.cancellables)
    }

    func get(faviconUrl: URL) -> Favicon? {
        guard loaded else {
            return nil
        }

        return entries[faviconUrl]
    }

    // MARK: - Clean

    func cleanOldExcept(fireproofDomains: FireproofDomains,
                        bookmarkManager: BookmarkManager,
                        completion: @escaping () -> Void) {
        removeFavicons(filter: { favicon in
            guard let host = favicon.documentUrl.host else {
                return false
            }
            return favicon.dateCreated < Date.monthAgo &&
                !fireproofDomains.isFireproof(fireproofDomain: host) &&
                !bookmarkManager.isHostInBookmarks(host: host)
        }, completionHandler: completion)
    }

    // MARK: - Burning

    func burnExcept(fireproofDomains: FireproofDomains,
                    bookmarkManager: BookmarkManager,
                    completion: @escaping () -> Void) {
        removeFavicons(filter: { favicon in
            guard let host = favicon.documentUrl.host else {
                return false
            }
            return !(fireproofDomains.isFireproof(fireproofDomain: host) ||
                     bookmarkManager.isHostInBookmarks(host: host))
        }, completionHandler: completion)
    }

    func burnDomains(_ domains: Set<String>,
                     except bookmarkManager: BookmarkManager,
                     completion: @escaping () -> Void) {
        removeFavicons(filter: { favicon in
            guard let host = favicon.documentUrl.host else {
                return false
            }
            return domains.contains(host) && !bookmarkManager.isHostInBookmarks(host: host)
        }, completionHandler: completion)
    }

    // MARK: - Private

    private func removeFavicons(filter isRemoved: (Favicon) -> Bool, completionHandler: (() -> Void)? = nil) {
        let faviconsToRemove = entries.values.filter(isRemoved)
        faviconsToRemove.forEach { entries[$0.url] = nil }

        removeFaviconsFromStore(faviconsToRemove, completionHandler: completionHandler)
    }

    private func removeFaviconsFromStore(_ favicons: [Favicon], completionHandler: (() -> Void)? = nil) {
        guard !favicons.isEmpty else { completionHandler?(); return }

        storing.removeFavicons(favicons)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    os_log("Favicons removed successfully.", log: .favicons)
                case .failure(let error):
                    os_log("Removing of favicons failed: %s", log: .favicons, type: .error, error.localizedDescription)
                }
                completionHandler?()
            }, receiveValue: {})
            .store(in: &self.cancellables)
    }
}
