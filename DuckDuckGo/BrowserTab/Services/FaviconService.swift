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

}

class LocalFaviconService: FaviconService {

    private enum FaviconName: String {
        case favicon = "favicon.ico"
    }

    private var cache = [String: NSImage]()

    enum LocalFaviconServiceError: Error {
        case urlConstructionFailed
        case imageInitFailed
    }

    func fetchFavicon(for host: String, completion: @escaping (NSImage?, Error?) -> Void) {
        if let cachedImage = cache[host] {
            completion(cachedImage, nil)
            return
        }

        guard let url = URL(string: "\(URL.Scheme.https.separated())\(host)/\(FaviconName.favicon.rawValue)") else {
            completion(nil, LocalFaviconServiceError.urlConstructionFailed)
            return
        }

        guard let image = NSImage(contentsOf: url), image.isValid else {
            completion(nil, LocalFaviconServiceError.imageInitFailed)
            return
        }

        self.cache[host] = image
        completion(image, nil)
    }

}
