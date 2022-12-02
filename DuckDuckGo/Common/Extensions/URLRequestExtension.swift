//
//  URLRequestExtension.swift
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

import Foundation

extension URLRequest {

    enum HeaderKey: String {
        case acceptEncoding = "Accept-Encoding"
        case acceptLanguage = "Accept-Language"
        case userAgent = "User-Agent"
        case referer = "Referer"
    }

    static func defaultRequest(with url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("gzip;q=1.0, compress;q=0.5",
                         forHTTPHeaderField: HeaderKey.acceptEncoding.rawValue)

        let userAgent = UserAgent.duckDuckGoUserAgent()
        
        request.setValue(userAgent, forHTTPHeaderField: HeaderKey.userAgent.rawValue)

        let languages = Locale.preferredLanguages.prefix(6)
        let acceptLanguage = languages.enumerated().map { index, language in
            let q = 1.0 - (Double(index) * 0.1)
            return "\(language);q=\(q)"
        }.joined(separator: ", ")

        request.setValue(acceptLanguage,
                         forHTTPHeaderField: HeaderKey.acceptLanguage.rawValue)
        return request
    }

    private static let requestAttributionKey = "requestAttribution"
    private static var requestAttributionValue: String = "#" + UUID().uuidString

    /// Used instead of macOS-12 introduced request.attribution property to differentiate user-initiated vs. developer-initiated requests
    var requestAttribution: URLRequestAttribution {
        get {
//            if #available(macOS 12.0, *) {
//                return URLRequestAttribution(rawValue: self.attribution.rawValue)
//            } else {
//                let associatedAttribution = objc_getAssociatedObject(self as NSURLRequest, Self.requestAttributionKey) as? NSNumber
            let isUserInitiated = self.mainDocumentURL?.absoluteString.hasSuffix(Self.requestAttributionValue) == true
            return isUserInitiated ? .user : .developer // URLRequestAttribution(rawValue: associatedAttribution?.uintValue ?? 0)
//            }
        }
        set {
//            if #available(macOS 12.0, *) {
//                self.attribution = Attribution(rawValue: newValue.rawValue) ?? .developer
//            } else {
            if var urlString = (self.mainDocumentURL ?? self.url)?.absoluteString {
                if let hashIdx = urlString.firstIndex(of: "#") {
                    urlString = String(urlString[..<hashIdx])
                }
                self.mainDocumentURL = URL(string: urlString + Self.requestAttributionValue)
            }


//            let req = NSMutableURLRequest(url: self.url!)
//            req.
//                let associatedAttribution = NSNumber(value: newValue.rawValue)
//                objc_setAssociatedObject(self as NSURLRequest, Self.requestAttributionKey, associatedAttribution, .OBJC_ASSOCIATION_RETAIN)
//            }
        }
    }
    var isUserInitiated: Bool { requestAttribution == .user }

    init(url: URL, userInitiated: Bool, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy, timeoutInterval: TimeInterval = 60.0) {
        self.init(url: url, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
        self.requestAttribution = .user
    }

}

struct URLRequestAttribution: RawRepresentable {
    var rawValue: UInt

    /// Automatically or developer-initiated request
    static let developer: URLRequestAttribution = {
        URLRequestAttribution(rawValue: {
            if #available(macOS 12.0, *) {
                return URLRequest.Attribution.developer.rawValue
            } else {
                return 0
            }
        }())
    }()
    /// Request initiated by a user intent (userEntered)
    static let user: URLRequestAttribution = {
        URLRequestAttribution(rawValue: {
            if #available(macOS 12.0, *) {
                return URLRequest.Attribution.user.rawValue
            } else {
                return 1
            }
        }())
    }()

}
