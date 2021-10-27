//
//  Pixel.swift
//  DuckDuckGo
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
import os.log

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
              withHeaders headers: HTTPHeaders = APIHeaders().defaultHeaders,
              onComplete: @escaping (Error?) -> Void = {_ in }) {

        var newParams = params ?? [:]
        newParams[Parameters.appVersion] = AppVersion.shared.versionNumber
        #if DEBUG
            newParams[Parameters.test] = Values.test
        #endif
        #if BETA
            newParams[Parameters.beta] = Values.beta
        #endif

        var headers = headers
        headers[APIHeaders.Name.moreInfo] = "See " + URL.duckDuckGoMorePrivacyInfo.absoluteString

        guard !dryRun else {
            os_log(.debug, log: .pixel, "%@", pixelName.replacingOccurrences(of: "_", with: "."))

            onComplete(nil)
            return
        }

        let url = URL.pixelUrl(forPixelNamed: pixelName)
        APIRequest.request(url: url, parameters: newParams, headers: headers, callBackOnMainThread: true) { (_, error) in
            onComplete(error)
        }
    }

    static func fire(_ event: Pixel.Event, withAdditionalParameters parameters: [String: String]? = nil) {
        let newParams: [String: String]?
        switch (event.parameters, parameters) {
        case (.some(let parameters), .none):
            newParams = parameters
        case (.none, .some(let parameters)):
            newParams = parameters
        case (.some(let params1), .some(let params2)):
            newParams = params1.merging(params2) { $1 }
        case (.none, .none):
            newParams = nil
        }

        Self.shared?.fire(pixelNamed: event.name, withAdditionalParameters: newParams)
    }

}
