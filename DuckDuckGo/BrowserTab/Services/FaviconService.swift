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

    func fetchFavicon(for host: String, completion: @escaping (NSImage?, Error?) -> Void)
    func getCachedFavicon(for host: String) -> NSImage?

}

class LocalFaviconService: FaviconService {

    static let shared = LocalFaviconService()

    private enum FaviconName: String {
        case favicon = "favicon.ico"
    }

    private var cache = [String: NSImage]()
    private let queue = DispatchQueue(label: "LocalFaviconService queue", attributes: .concurrent)

    enum LocalFaviconServiceError: Error {
        case urlConstructionFailed
        case imageInitFailed
    }

    func fetchFavicon(for host: String, completion: @escaping (NSImage?, Error?) -> Void) {

        func mainQueueCompletion(_ favicon: NSImage?, _ error: Error?) {
            DispatchQueue.main.async {
                completion(favicon, error)
            }
        }

        queue.async {
            if let cachedFavicon = self.getCachedFavicon(for: host) {
                mainQueueCompletion(cachedFavicon, nil)
                return
            }

            guard let url = URL(string: "\(URL.Scheme.https.separated())\(host)/\(FaviconName.favicon.rawValue)") else {
                mainQueueCompletion(nil, LocalFaviconServiceError.urlConstructionFailed)
                return
            }

            guard let image = NSImage(contentsOf: url), image.isValid else {
                if let newHost = host.dropSubdomain() {
                    self.fetchFavicon(for: newHost, completion: completion)
                } else {
                    mainQueueCompletion(nil, LocalFaviconServiceError.imageInitFailed)
                }
                return
            }

            self.store(favicon: image, for: host)
            mainQueueCompletion(image, nil)
        }
    }

    func store(favicon: NSImage, for host: String) {
        queue.async(flags: .barrier) {
            self.cache[host] = favicon
        }
    }

    func getCachedFavicon(for host: String) -> NSImage? {
        return cache[host]
    }

}
