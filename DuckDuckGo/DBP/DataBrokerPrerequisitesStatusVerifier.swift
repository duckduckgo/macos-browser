//
//  DataBrokerPrerequisitesStatusVerifier.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

enum DataBrokerPrerequisitesStatus {
    case invalidDirectory
    case invalidSystemPermission
    case unverified
    case valid
}

protocol DataBrokerPrerequisitesStatusVerifier: AnyObject {
    var status: DataBrokerPrerequisitesStatus { get set }
    var statusPublisher: Published<DataBrokerPrerequisitesStatus>.Publisher { get }
    func checkStatus()
}

final class DefaultDataBrokerPrerequisitesStatusVerifier: DataBrokerPrerequisitesStatusVerifier {
    @Published var status: DataBrokerPrerequisitesStatus
    var statusPublisher: Published<DataBrokerPrerequisitesStatus>.Publisher { $status }

    init() {
        self.status = .unverified
        checkStatus()
    }

    func checkStatus() {
        self.status = .valid
    }
}


