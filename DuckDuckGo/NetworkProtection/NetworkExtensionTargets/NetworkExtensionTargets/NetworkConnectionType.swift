//
//  NetworkConnectionType.swift
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

import Network

public enum NetworkConnectionType: String, CustomStringConvertible, Sendable {
    public var description: String { rawValue }

    case cellular = "cell"
    case wifi
    case eth

    public init?(nwPath: NWPath) {
        if nwPath.usesInterfaceType(.wiredEthernet) {
            self = .eth
        } else if nwPath.usesInterfaceType(.wifi) {
            self = .wifi
        } else if nwPath.usesInterfaceType(.cellular) {
            self = .cellular
        } else {
            return nil
        }
    }

}
