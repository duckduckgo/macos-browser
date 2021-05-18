//
//  ExternalURLHandler.swift
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

import Combine

final class ExternalURLHandler {

    var openExternalUrlPublisher: AnyPublisher<URL, Never> {
        urlPublisher.eraseToAnyPublisher()
    }

    private let urlHandler = PassthroughSubject<URL, Never>()
    private let urlPublisher = PassthroughSubject<URL, Never>()

    private var cancellable: AnyCancellable?
    private var lastPage: URL?

    private let collectionTimeMillis: Int
    private let scheduler: DispatchQueue

    init(collectionTimeMillis: Int = 300, scheduler: DispatchQueue = DispatchQueue.main) {
        self.collectionTimeMillis = collectionTimeMillis
        self.scheduler = scheduler
    }

    func isBlob(scheme: String) -> Bool {
        return scheme == "blob"
    }

    func isExternal(scheme: String) -> Bool {
        return !["https", "http", "about", "data", "file"].contains(scheme)
    }

    func handle(url: URL, onPage page: URL?, fromFrame: Bool, triggeredByUser: Bool) {
        // just cancel frame based external urls
        guard !fromFrame else { return }

        if triggeredByUser {
            urlPublisher.send(url)
            return
        }

        if page != self.lastPage {
            lastPage = page
            cancellable?.cancel()
            cancellable = urlHandler
                .collect(.byTime(scheduler, .milliseconds(collectionTimeMillis)))
                .sink {
                    // tell subscriber(s) to show the prompt now
                    if let url = $0.last {
                        self.urlPublisher.send(url)
                    }

                    // prevents further prompts from this page as it seems to be spammy
                    if $0.count > 1 {
                        self.cancellable?.cancel()
                        self.cancellable = nil
                    }
                }
        }

        urlHandler.send(url)
    }

}
