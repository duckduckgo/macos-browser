//
//  BWEncryptionTests.swift
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
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class BWEncryptionTests: XCTestCase {

    func testGenerateKeysReturnsPublicKey() {
        let encryption = BWEncryption()
        let publicKey = encryption.generateKeys()
        XCTAssertNotNil(publicKey)
        XCTAssertNotEqual(0, publicKey?.count)
    }

    func testWhenKeyPairIsntGenerated_ThenDecryptionOfSharedKeyFails() {
        let encryption = BWEncryption()
        let decryptionResult = encryption.decryptSharedKey("shared key")
        XCTAssertNil(decryptionResult)
    }

    func testWhenSharedKeyIsntSet_ThenEncryptionOfDataFails() {
        let encryption = BWEncryption()
        let encryptionResult = encryption.encryptData("utf8 string".data(using: .utf8)!)
        XCTAssertNil(encryptionResult)
    }

    func testWhenSharedKeyIsSet_ThenEncryptionMethodProducesOutputWhichCanBeDecrypted() {
        let encryption = BWEncryption()
        let sharedKey = "wL759B5ZDRD27jgfEWMiKWyWXprTXg8Syr4NoP6zF1GrCq+pFQ9EnWUQPiDEmhVn6ibT+hJ+toJq620YqRh/vQ=="
        encryption.setSharedKey(Data(base64Encoded: sharedKey)!)

        let data = "{ command: \"bw-status\" }".data(using: .utf8)
        let encryptionOutput = encryption.encryptData(data!)

        XCTAssertNotNil(encryptionOutput)

        let decryptionOutput = encryption.decryptData(encryptionOutput!.data, andIv: encryptionOutput!.iv)

        XCTAssertEqual(data, decryptionOutput)

    }

    func testCleanKeys() {
        let encryption = BWEncryption()
        let sharedKey = "wL759B5ZDRD27jgfEWMiKWyWXprTXg8Syr4NoP6zF1GrCq+pFQ9EnWUQPiDEmhVn6ibT+hJ+toJq620YqRh/vQ=="
        encryption.setSharedKey(Data(base64Encoded: sharedKey)!)

        encryption.cleanKeys()

        let data = "{ command: \"bw-status\" }".data(using: .utf8)
        let encryptionOutput = encryption.encryptData(data!)

        XCTAssertNil(encryptionOutput)
    }

}
