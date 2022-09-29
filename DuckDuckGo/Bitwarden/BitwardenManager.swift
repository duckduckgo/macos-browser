//
//  BitwardenManager.swift
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

protocol BitwardenManagement {

    var status: BitwardenStatus { get }
    var statusPublisher: Published<BitwardenStatus>.Publisher { get }

    func retrieveCredentials(for url: URL, completion: @escaping ([BitwardenCredential], BitwardenError?) -> Void)
    func create(credential: BitwardenCredential, completion: @escaping (BitwardenError?) -> Void)
    func update(credential: BitwardenCredential, completion: @escaping (BitwardenError?) -> Void)

}

final class BitwardenManager: BitwardenManagement {

    static let shared = BitwardenManager()

    @Published private(set) var status: BitwardenStatus = .disabled
    var statusPublisher: Published<BitwardenStatus>.Publisher { $status }

    func retrieveCredentials(for url: URL, completion: @escaping ([BitwardenCredential], BitwardenError?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let credentials = [
                BitwardenCredential(userId: "user-id",
                                    credentialId: "credential-id-1",
                                    credentialName: "domain.com",
                                    username: "username",
                                    password: "password123",
                                    url: url),
                BitwardenCredential(userId: "user-id",
                                           credentialId: "credential-id-2",
                                           credentialName: "domain2.com",
                                           username: "duck",
                                           password: "password123",
                                           url: url)
            ]
            completion(credentials, nil)
        }
    }

    func create(credential: BitwardenCredential, completion: @escaping (BitwardenError?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion(nil)
        }
    }

    func update(credential: BitwardenCredential, completion: @escaping (BitwardenError?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion(nil)
        }
    }

}
