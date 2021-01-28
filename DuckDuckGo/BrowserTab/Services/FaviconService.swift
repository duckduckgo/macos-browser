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
import Combine

protocol FaviconService {

    func fetchFavicon(at faviconUrl: URL?, for host: String, completion: @escaping LocalFaviconService.Callback)
    func getCachedFavicon(for host: String) -> NSImage?
    func store(favicon: NSImage, for host: String)

}
extension FaviconService {
    func fetchFavicon(for host: String, completion: @escaping LocalFaviconService.Callback) {
        fetchFavicon(at: nil, for: host, completion: completion)
    }
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

    private var requests = [String: Future<NSImage, Error>]()
    private var subscriptions = [NSValue: AnyCancellable]()
    private let cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "LocalFaviconService queue", attributes: .concurrent)

    private func fetchFaviconSync(url: URL, host: String, retryDroppingSubdomain: Bool, callback: @escaping Callback) {
        dispatchPrecondition(condition: .onQueue(queue))

        guard let image = NSImage(contentsOf: url), image.isValid else {
            if retryDroppingSubdomain,
               let newHost = host.dropSubdomain() {

                DispatchQueue.main.async {
                    self.fetchFavicon(at: nil, for: newHost, completion: callback)
                }
            } else {
                callback(.failure(.imageInitFailed))
            }
            return
        }

        callback(.success(image))
    }

    func fetchFavicon(at faviconUrl: URL?, for host: String, completion callback: @escaping Callback) {
        dispatchPrecondition(condition: .onQueue(.main))

        if let cachedFavicon = self.getCachedFavicon(for: host) {
            callback(.success(cachedFavicon))
            return
        }

        guard let url = faviconUrl ?? URL(string: "\(URL.Scheme.https.separated())\(host)/\(FaviconName.favicon.rawValue)")
        else {
            callback(.failure(.urlConstructionFailed))
            return
        }

        func newFuture() -> Future<NSImage, Error> {
            let future = Future<NSImage, Error> { [unowned self] promise in
                self.queue.async { [unowned self] in
                    self.fetchFaviconSync(url: url,
                                          host: host,
                                          retryDroppingSubdomain: faviconUrl == nil,
                                          callback: promise)
                }
            }
            self.requests[host] = future
            
            return future
        }

        let future = requests[host] ?? newFuture()
        let subscriptionKey = NSValue(nonretainedObject: callback)
        subscriptions[subscriptionKey] = future.receive(on: DispatchQueue.main).sink { [unowned self] in
            self.requests[host] = nil
            self.subscriptions[subscriptionKey] = nil

            switch $0 {
            case .failure(let error):
                callback(.failure(error))
            case .finished:
                break
            }

        } receiveValue: { [unowned self] image in
            self.store(favicon: image, for: host)
            callback(.success(image))
        }
    }

    func store(favicon: NSImage, for host: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        cache.setObject(favicon, forKey: host as NSString)
    }

    func getCachedFavicon(for host: String) -> NSImage? {
        dispatchPrecondition(condition: .onQueue(.main))
        return cache.object(forKey: host as NSString)
    }

}
