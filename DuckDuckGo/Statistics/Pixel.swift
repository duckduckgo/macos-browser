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

enum Pixel {

    static func fire(pixelNamed pixelName: String,
                     withAdditionalParameters params: [String: String]? = nil,
                     withHeaders headers: HTTPHeaders = APIHeaders().defaultHeaders,
                     onComplete: @escaping (Error?) -> Void = {_ in }) {

        var newParams = params ?? [:]
        newParams[Parameters.appVersion] = AppVersion.shared.versionAndBuildNumber
        #if DEBUG
            newParams[Parameters.test] = Values.test
        #endif

        var headers = headers
        headers[APIHeaders.Name.moreInfo] = "See " + URL.duckDuckGoMorePrivacyInfo.absoluteString

        let url = URL.pixelUrl(forPixelNamed: pixelName)

        APIRequest.request(url: url, parameters: newParams, headers: headers, callBackOnMainThread: true) { (_, error) in

            os_log("Pixel fired %s %s", type: .debug, pixelName, "\(params?.debugDescription ?? "<nil>")")
            onComplete(error)
        }
    }
    
}

extension Pixel {
    static func fire(_ event: Pixel.Event) {
        fire(pixelNamed: event.name, withAdditionalParameters: event.parameters)
    }
}
