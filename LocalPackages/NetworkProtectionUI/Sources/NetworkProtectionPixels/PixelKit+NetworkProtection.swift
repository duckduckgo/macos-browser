//
//  PixelKit+NetworkProtection.swift
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

import Foundation
import PixelKit
import NetworkProtection

extension PixelKit {

    // TODO: this should probably live in PixelKit?
    enum Parameters {
        static let duration = "duration"
        static let test = "test"
        static let appVersion = "appVersion"

        static let keychainFieldName = "fieldName"
        static let errorCode = "e"
        static let errorDesc = "d"
        static let errorCount = "c"

        static let function = "function"
        static let line = "line"

        static let latency = "latency"
        static let server = "server"
        static let networkType = "net_type"
    }

    // TODO: this should probably live in PixelKit?
    enum Values {
        static let test = "1"
    }
}

extension PixelKit {
    public static func fire(_ event: NetworkProtectionPixelKitEvent,
                            frequency: PixelKit.Frequency,
                            withAdditionalParameters parameters: [String: String]? = nil,
                            allowedQueryReservedCharacters: CharacterSet? = nil,
                            includeAppVersionParameter: Bool = true,
                            onComplete: @escaping (Error?) -> Void = {_ in }) {
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

        PixelKit.shared?.fire(event,
                              frequency: frequency,
                              withAdditionalParameters: newParams,
                              allowedQueryReservedCharacters: allowedQueryReservedCharacters,
                              includeAppVersionParameter: includeAppVersionParameter,
                              onComplete: onComplete)
    }
}
