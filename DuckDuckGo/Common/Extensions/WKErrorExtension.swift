//
//  WKErrorExtension.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import WebKit

extension WKError {

    private enum Parameters {
        static var code = "c"
        static var domain = "domain"
        static var description = "descr"
        static var failingUrl = "url"
        static var title = "title"
    }

    static let pageTitleKey = "PageTitleKey"
    var pageTitle: String? {
        self.userInfo[Self.pageTitleKey] as? String
    }

    init(urlEncoded url: URL) {
        let domain = url.getParameter(named: Parameters.domain) ?? WKErrorDomain
        let code = url.getParameter(named: Parameters.code).flatMap(Int.init) ?? WKError.Code.unknown.rawValue
        let description = url.getParameter(named: Parameters.description) ?? ""
        let failingURL = url.getParameter(named: Parameters.failingUrl).flatMap(URL.init(string:)) ?? .blankPage
        let title = url.getParameter(named: Parameters.title) ?? ""
        let error = NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: description,
                                                                   NSURLErrorFailingURLErrorKey: failingURL,
                                                                   Self.pageTitleKey: title])
        self.init(_nsError: error)
    }

    func urlEncoded(withPrefix prefix: String, withPageTitle title: String?) -> URL {
        return URL(string: prefix)!.appendingParameters([
            Parameters.domain: self._nsError.domain,
            Parameters.code: "\(code.rawValue)",
            Parameters.description: self.localizedDescription,
            Parameters.failingUrl: self.failingUrl?.absoluteString ?? "",
            Parameters.title: title ?? ""
        ])
    }

}
