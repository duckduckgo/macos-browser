//
//  Pixel.swift
//
//  Copyright © 2018 DuckDuckGo. All rights reserved.
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
import BrowserServicesKit
import os.log

extension URL {
    static var duckDuckGoMorePrivacyInfo = URL(string: "https://help.duckduckgo.com/duckduckgo-help-pages/privacy/atb/")!
    
    static let pixelBase = ProcessInfo.processInfo.environment["PIXEL_BASE_URL", default: "https://improving.duckduckgo.com"]
    
    static func pixelUrl(forPixelNamed pixelName: String) -> URL {
        let urlString = "\(Self.pixelBase)/t/\(pixelName)"
        let url = URL(string: urlString)!
        // url = url.addParameter(name: \"atb\", value: statisticsStore.atbWithVariant ?? \"\")")
        // https://app.asana.com/0/1177771139624306/1199951074455863/f
        return url
    }
}

final class Pixel {

    static private(set) var shared: Pixel?

    static func setUp(dryRun: Bool = false) {
        shared = Pixel(dryRun: dryRun)
    }

    static func tearDown() {
        shared = nil
    }

    private var dryRun: Bool

    init(dryRun: Bool) {
        self.dryRun = dryRun
    }

    func fire(pixelNamed pixelName: String,
              withAdditionalParameters params: [String: String]? = nil,
              allowedQueryReservedCharacters: CharacterSet? = nil,
              includeAppVersionParameter: Bool = true,
              withHeaders headers: HTTPHeaders = APIHeaders().defaultHeaders,
              onComplete: @escaping (Error?) -> Void = {_ in }) {

        var newParams = params ?? [:]
        if includeAppVersionParameter {
            newParams[Parameters.appVersion] = AppVersion.shared.versionNumber
        }
        #if DEBUG
            newParams[Parameters.test] = Values.test
        #endif

        var headers = headers
        headers[APIHeaders.Name.moreInfo] = "See " + URL.duckDuckGoMorePrivacyInfo.absoluteString

        guard !dryRun else {
            let params = params?.filter { key, _ in !["appVersion", "test"].contains(key) } ?? [:]
            os_log(.debug, log: .pixel, "%@ %@", pixelName.replacingOccurrences(of: "_", with: "."), params)

            // simulate server response time for Dry Run mode
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete(nil)
            }
            return
        }

        let url = URL.pixelUrl(forPixelNamed: pixelName)
        APIRequest.request(
            url: url,
            parameters: newParams,
            allowedQueryReservedCharacters: allowedQueryReservedCharacters,
            headers: headers,
            callBackOnMainThread: true
        ) { (_, error) in
            onComplete(error)
        }
    }

}
