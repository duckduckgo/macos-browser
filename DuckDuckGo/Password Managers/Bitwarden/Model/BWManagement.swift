//
//  BWManagement.swift
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
import Combine

protocol BWManagement {

    var status: BWStatus { get }
    var statusPublisher: Published<BWStatus>.Publisher { get }

    func initCommunication()
    func sendHandshake()
    func refreshStatusIfNeeded()
    func cancelCommunication()

    func openBitwarden()

    func retrieveCredentials(for url: URL, completion: @escaping ([BWCredential], BWError?) -> Void)
    func create(credential: BWCredential, completion: @escaping (BWError?) -> Void)
    func update(credential: BWCredential, completion: @escaping (BWError?) -> Void)

}

#if APPSTORE

final class BWManager: BWManagement, ObservableObject {

    static let shared = BWManager()

    init() {}

    @Published var status: BWStatus = .disabled
    var statusPublisher: Published<BWStatus>.Publisher { $status }

    func initCommunication() {}
    func sendHandshake() {}
    func refreshStatusIfNeeded() {}
    func cancelCommunication() {}

    func openBitwarden() {}

    func retrieveCredentials(for url: URL, completion: @escaping ([BWCredential], BWError?) -> Void) {}
    func create(credential: BWCredential, completion: @escaping (BWError?) -> Void) {}
    func update(credential: BWCredential, completion: @escaping (BWError?) -> Void) {}

}

#endif
