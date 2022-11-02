//
//  PixelStoreTests.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser
import Combine

final class PixelStoreTests: XCTestCase {

    override func setUp() {
        let keyStore = EncryptionKeyStoreMock()
        try? EncryptedValueTransformer<NSNumber>.registerTransformer(keyStore: keyStore)
        try? EncryptedValueTransformer<NSString>.registerTransformer(keyStore: keyStore)
    }

    func testLocalPixelDataStore() throws {
        let container = NSPersistentContainer.createInMemoryPersistentContainer(modelName: "PixelDataModel",
                                                                                bundle: Bundle(for: PixelData.self))
        var context: NSManagedObjectContext! = container.viewContext
        var store: LocalPixelDataStore! = LocalPixelDataStore(context: context, updateModel: PixelData.update)

        let e1 = expectation(description: "Double saved")
        store.set(1.23, forKey: "a") { error in
            XCTAssertNil(error)
            e1.fulfill()
        }
        
        let e2 = expectation(description: "Int saved")
        store.set(12, forKey: "b") { error in
            XCTAssertNil(error)
            e2.fulfill()
        }

        let e3 = expectation(description: "String saved")
        store.set("string", forKey: "c") { error in
            XCTAssertNil(error)
            e3.fulfill()
        }

        XCTAssertEqual(store.value(forKey: "a"), 1.23)
        XCTAssertEqual(store.value(forKey: "b"), 12 as Int)
        XCTAssertEqual(store.value(forKey: "c"), "string")
        XCTAssertEqual(store.cache, ["b": NSNumber(value: 12), "a": NSNumber(value: 1.23), "c": "string" as NSString])
        waitForExpectations(timeout: 5)

        store = nil
        context = container.viewContext
        store = LocalPixelDataStore(context: context, updateModel: PixelData.update)

        XCTAssertEqual(store.value(forKey: "a"), 1.23)
        XCTAssertEqual(store.value(forKey: "b"), 12 as Int)
        XCTAssertEqual(store.value(forKey: "c"), "string")
        XCTAssertEqual(store.cache, ["b": NSNumber(value: 12), "a": NSNumber(value: 1.23), "c": "string" as NSString])
    }

}
