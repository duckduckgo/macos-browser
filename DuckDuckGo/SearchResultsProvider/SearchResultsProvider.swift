//
//  SearchResultsProvider.swift
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
import SwiftSoup

struct SearchResult: Equatable {
    let title: String
    let snippet: String?
    let url: URL
    let favicon: NSImage?
    let faviconURL: URL?
}
enum SearchError: Error {
    case urlError(URLError)
    case parsingError(ExceptionType, String)
    case dataDecodingError(Data)
    case other(Error)
}

final class SearchResultsProvider {
    static let shared = SearchResultsProvider()

    func querySearchResults(for searchQuery: String) -> AnyPublisher<[SearchResult], SearchError> {
        let url = URL.makeHTMLSearchURL(from: searchQuery)!
        let request = URLRequest(url: url)
        return SharedURLSessionDataTaskProvider()
            .dataTaskPublisher(for: request)
            .tryMap { result -> Document in
                guard let html = String(data: result.data, encoding: .utf8) else {
                    throw SearchError.dataDecodingError(result.data)
                }
                return try SwiftSoup.parse(html)

            }.tryMap { doc in
                try doc.select("div.links_main").array().map {
                    let link = try? $0.select("a").first()
                    let href = try? link?.attr("href")
                    let url = href.flatMap { URL(string: $0, relativeTo: .duckDuckGo) }
                    let img = try? $0.select("img").first()
                    let faviconSrc = try? img?.attr("src")
                    let faviconURL = faviconSrc.flatMap { URL(string: $0, relativeTo: .duckDuckGo) }
                    let title = try? link?.text()
                    let snippet = try? $0.select(".result__snippet").first()?.text()
                    
                    return SearchResult(title: title!,
                                        snippet: snippet,
                                        url: url!,
                                        favicon: nil,
                                        faviconURL: faviconURL)
                }

            }.mapError {
                switch $0 {
                case let urlError as URLError:
                    return SearchError.urlError(urlError)
                case Exception.Error(type: let type, Message: let message):
                    return SearchError.parsingError(type, message)
                default:
                    return SearchError.other($0)
                }

            }.eraseToAnyPublisher()

    }

}
