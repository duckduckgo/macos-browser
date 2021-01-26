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

    func fetchFavicon(_ faviconUrl: URL?, for host: String, completion: @escaping LocalFaviconService.Callback)
    func getCachedFavicon(for host: String) -> NSImage?
    func store(favicon: NSImage, for host: String)

}

class LocalFaviconService: FaviconService {

    static let shared = LocalFaviconService()

    enum Error: Swift.Error {
        case urlConstructionFailed
        case imageInitFailed
    }
    typealias Callback = (Result<NSImage, Error>) -> Void

    private enum FaviconName: String {
        case favicon = "favicon.ico"
    }

    private var requests = [String: Promise<NSImage, Error>]()
    private var cache = [String: NSImage]()
    private let queue = DispatchQueue(label: "LocalFaviconService queue", attributes: .concurrent)

    func fetchFavicon(_ faviconUrl: URL?, for host: String, completion: @escaping Callback) {
        dispatchPrecondition(condition: .onQueue(.main))

        if let cachedFavicon = self.getCachedFavicon(for: host) {
            return completion(.success(cachedFavicon))
        }
        if let promise = requests[host] {
            return promise.append(completion)
        }

        requests[host] = Promise(queue, callback: { result in
            if case .success(let image) = result {
                self.store(favicon: image, for: host)
            }

            self.requests[host] = nil
            completion(result)

        }) { resolve in
            guard let url = faviconUrl ?? URL(string: "\(URL.Scheme.https.separated())\(host)/\(FaviconName.favicon.rawValue)") else {
                return resolve(.failure(.urlConstructionFailed))
            }

            guard let image = NSImage(contentsOf: url), image.isValid else {
                if let newHost = host.dropSubdomain(), faviconUrl == nil {
                    DispatchQueue.main.async {
                        self.fetchFavicon(nil, for: newHost, completion: resolve)
                    }
                } else {
                    resolve(.failure(.imageInitFailed))
                }
                return
            }

            resolve(.success(image))
        }
    }

    func store(favicon: NSImage, for host: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        cache[host] = favicon
    }

    func getCachedFavicon(for host: String) -> NSImage? {
        dispatchPrecondition(condition: .onQueue(.main))
        return cache[host]
    }

}
