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

    let fm = FileManager.default
    var tempURL: URL!
    let testFile = "pixel_db"

    func clearTemp() {
        let tempDir = fm.temporaryDirectory
        for file in (try? fm.contentsOfDirectory(atPath: tempDir.path)) ?? [] where file.hasPrefix(testFile) {
            try? fm.removeItem(at: tempDir.appendingPathComponent(file))
        }
    }

    override func setUp() {
        clearTemp()

        self.tempURL = fm.temporaryDirectory

        let keyStore = EncryptionKeyStoreMock()
        try? EncryptedValueTransformer<NSNumber>.registerTransformer(keyStore: keyStore)
        try? EncryptedValueTransformer<NSData>.registerTransformer(keyStore: keyStore)
    }

    override func tearDown() {
        clearTemp()
    }

    func testPixelStoreMigration() throws {
        let url = tempURL.appendingPathComponent(testFile)
        var oldContainer: NSPersistentContainer! = NSPersistentContainer.createPersistentContainer(at: url,
                                                                                                   modelName: "OldPixelDataModel",
                                                                                                   bundle: Bundle(for: type(of: self)))
        var oldContext: NSManagedObjectContext! = oldContainer.viewContext
        func updateModelOld(_ managedObject: NSManagedObject) -> (PixelDataRecord) throws -> Void {
            { record in
                managedObject.setValue(record.key, forKey: #keyPath(PixelData.key))
                managedObject.setValue((record.value as? NSNumber)!, forKey: #keyPath(PixelData.valueEncrypted))
            }
        }
        var oldStore: LocalPixelDataStore! = LocalPixelDataStore(context: oldContext, updateModel: updateModelOld, entityName: PixelData.className())

        let e1 = expectation(description: "Double saved")
        oldContext.perform {
            oldStore.set(1.23, forKey: "a") { error in
                XCTAssertNil(error)
                e1.fulfill()
            }
        }
        
        let e2 = expectation(description: "Int saved")
        oldContext.perform {
            oldStore.set(1, forKey: "b") { error in
                XCTAssertNil(error)
                e2.fulfill()
            }
        }

        withExtendedLifetime(oldContext) {
            withExtendedLifetime(oldContainer) {
                waitForExpectations(timeout: 5)
            }
        }
        oldContext = nil
        oldStore = nil
        oldContainer = nil

        let newContainer = NSPersistentContainer.createPersistentContainer(at: url,
                                                                           modelName: "PixelDataModel",
                                                                           bundle: Bundle(for: DuckDuckGo_Privacy_Browser.PixelData.self))
        let newContext = newContainer.viewContext
        let newStore = LocalPixelDataStore(context: newContext, updateModel: DuckDuckGo_Privacy_Browser.PixelData.update)

        XCTAssertEqual(newStore.cache, ["b": NSNumber(value: 1), "a": NSNumber(value: 1.23)])
    }

}
