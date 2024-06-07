//
//  SearchNonexistentDomainNavigationResponder.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import Common
import Foundation
import Navigation

final class SearchNonexistentDomainNavigationResponder {

    private let tld: TLD
    private let setContent: (Tab.TabContent) -> Void
    private var lastUserEnteredValue: String?
    private var cancellable: AnyCancellable?

    init(tld: TLD, contentPublisher: some Publisher<Tab.TabContent, Never>, setContent: @escaping (Tab.TabContent) -> Void) {
        self.tld = tld
        self.setContent = setContent

        cancellable = contentPublisher.sink { [weak self] tabContent in
            if case .url(_, credential: .none, source: .userEntered(let userEnteredValue, _)) = tabContent {
                self?.lastUserEnteredValue = userEnteredValue
            }
        }
    }

}

extension SearchNonexistentDomainNavigationResponder: NavigationResponder {

    func navigationDidFinish(_ navigation: Navigation) {
        lastUserEnteredValue = nil
    }

    func navigation(_ navigation: Navigation, didFailWith error: WKError) {
        guard navigation.isCurrent else { return }
        defer {
            lastUserEnteredValue = nil
        }

        guard case .custom(.userEnteredUrl) = navigation.navigationAction.navigationType,
              error._nsError.domain == NSURLErrorDomain,
              error.errorCode == NSURLErrorCannotFindHost,
              let lastUserEnteredValue,
              let scheme = navigation.url.scheme.map(URL.NavigationalScheme.init)?.separated(),
              // if user-entered value actually had the scheme - don‘t search
              !lastUserEnteredValue.hasPrefix(scheme),
              // if url had a valid top level domain - don‘t search
              tld.domain(navigation.url.host) == nil,
              let url = URL.makeSearchUrl(from: lastUserEnteredValue) else { return }

        // redirect to SERP for non-valid domains entered by user
        // https://app.asana.com/0/1177771139624306/1204041033469842/f

        setContent(.url(url, source: .userEntered(lastUserEnteredValue)))
    }

}

protocol NonexistentDomainsResponder: AnyObject, NavigationResponder {}

extension SearchNonexistentDomainNavigationResponder: NonexistentDomainsResponder, TabExtension {
    func getPublicProtocol() -> NonexistentDomainsResponder { self }
}

extension TabExtensions {
    var searchForNonexistentDomains: NonexistentDomainsResponder? {
        resolve(SearchNonexistentDomainNavigationResponder.self)
    }
}
