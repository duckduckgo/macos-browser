//
//  Tab.swift
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

protocol TabActionDelegate: AnyObject {

    func tabForwardAction(_ tab: Tab)
    func tabBackAction(_ tab: Tab)
    func tabHomeAction(_ tab: Tab)
    func tabReloadAction(_ tab: Tab)
    func tabStopLoadingAction(_ tab: Tab)

}

class Tab {

    init(faviconService: FaviconService) {
        self.faviconService = faviconService
    }

    convenience init() {
        self.init(faviconService: LocalFaviconService())
    }

    let faviconService: FaviconService

    @Published var url: URL? {
        willSet {
            if newValue?.host != url?.host {
                fetchFavicon(for: newValue?.host)
            }
        }
    }
    @Published var title: String?
    @Published var favicon: NSImage?

    weak var actionDelegate: TabActionDelegate?

    func goForward() {
        actionDelegate?.tabForwardAction(self)
    }

    func goBack() {
        actionDelegate?.tabBackAction(self)
    }

    func goHome() {
        actionDelegate?.tabHomeAction(self)
    }

    func reload() {
        actionDelegate?.tabReloadAction(self)
    }

    func stopLoading() {
        actionDelegate?.tabStopLoadingAction(self)
    }

    private func fetchFavicon(for host: String?) {
        guard let host = host else {
            favicon = nil
            return
        }

        faviconService.fetchFavicon(for: host) { (image, error) in
            guard error == nil, let image = image else {
                self.favicon = nil
                return
            }

            self.favicon = image
        }
    }

}

extension Tab: Equatable {

    static func == (lhs: Tab, rhs: Tab) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

}

extension Tab: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

}
