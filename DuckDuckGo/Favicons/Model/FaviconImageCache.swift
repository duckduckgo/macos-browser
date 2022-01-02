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
import os.log

final class FaviconImageCache {

    private let storing: FaviconStoring
    private let queue: DispatchQueue

    private var entries = [URL: Favicon]()

    private var cancellables = Set<AnyCancellable>()

    init(faviconQueue: DispatchQueue, faviconStoring: FaviconStoring) {
        storing = faviconStoring
        queue = faviconQueue
    }

    private(set) var loaded = false

    func loadFavicons(completionHandler: ((Error?) -> Void)? = nil) {
        dispatchPrecondition(condition: .onQueue(queue))

        storing.loadFavicons()
            .receive(on: self.queue, options: .init(flags: .barrier))
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
                dispatchPrecondition(condition: .onQueue(self!.queue))
                favicons.forEach { favicon in
                    self?.entries[favicon.url] = favicon
                }
                self?.loaded = true
            })
            .store(in: &self.cancellables)
    }

    func insert(_ favicon: Favicon) {
        dispatchPrecondition(condition: .onQueue(queue))

        guard loaded else { return }

        // Remove existing favicon with the same URL
        if let oldFavicon = entries[favicon.url] {
            removeFavicons([oldFavicon])
        }

        // Save the new one
        entries[favicon.url] = favicon
        storing.save(favicon: favicon)
            .receive(on: self.queue, options: .init(flags: .barrier))
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    os_log("Favicon saved successfully. URL: %s", log: .favicons, favicon.url.absoluteString)
                case .failure(let error):
                    os_log("Saving of favicon failed: %s", log: .favicons, type: .error, error.localizedDescription)
                }
            }, receiveValue: {})
            .store(in: &self.cancellables)
    }

    func get(faviconUrl: URL) -> Favicon? {
        dispatchPrecondition(condition: .onQueue(queue))

        return entries[faviconUrl]
    }

    // MARK: - Burning

    func burn(except fireproofDomains: FireproofDomains, completion: @escaping () -> Void) {
        dispatchPrecondition(condition: .onQueue(queue))

        let faviconsToBurn = entries.values.filter { favicon in
            guard let host = favicon.documentUrl.host else {
                return false
            }
            return !fireproofDomains.isFireproof(fireproofDomain: host)
        }

        removeFavicons(faviconsToBurn, completionHandler: completion)
    }

    func burnDomains(_ domains: Set<String>, completion: @escaping () -> Void) {
        dispatchPrecondition(condition: .onQueue(queue))

        let faviconsToBurn = entries.values.filter { favicon in
            guard let host = favicon.documentUrl.host else {
                return false
            }
            return domains.contains(host)
        }

        removeFavicons(faviconsToBurn, completionHandler: completion)
    }

    // MARK: - Private

    private func removeFavicons(_ favicons: [Favicon], completionHandler: (() -> Void)? = nil) {
        storing.removeFavicons(favicons)
            .receive(on: self.queue, options: .init(flags: .barrier))
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
