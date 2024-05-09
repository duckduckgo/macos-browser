//
//  SyncBookmarksAdapterTests.swift
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

import XCTest
import BrowserServicesKit
import Combine
import DDGSync
import Persistence
@testable import DuckDuckGo_Privacy_Browser

final class SyncBookmarksAdapterTests: XCTestCase {

    var errorHandler: CapturingAdapterErrorHandler!
    var adapter: SyncBookmarksAdapter!
    let metadataStore = MockMetadataStore()
    var cancellables: Set<AnyCancellable>!
    var database: CoreDataDatabase!

    override func setUpWithError() throws {
        errorHandler = CapturingAdapterErrorHandler()
        let bundle = DDGSync.bundle
        guard let model = CoreDataDatabase.loadModel(from: bundle, named: "SyncMetadata") else {
            XCTFail("Failed to load model")
            return
        }
        database = CoreDataDatabase(name: "", containerLocation: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), model: model, readOnly: true, options: [:])
        adapter = SyncBookmarksAdapter(database: database, bookmarkManager: MockBookmarkManager(), syncErrorHandler: errorHandler)
        cancellables = []
    }

    override func tearDownWithError() throws {
        errorHandler = nil
        adapter = nil
        cancellables = nil
    }

    func testWhenSyncErrorPublished_ThenErrorHandlerHandleCredentialErrorCalled() async {
        let expectation = XCTestExpectation(description: "Sync did fail")
        let expectedError = NSError(domain: "some error", code: 400)
        await adapter.setUpProviderIfNeeded(database: database, metadataStore: metadataStore)
        adapter.provider!.syncErrorPublisher
            .sink { error in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        adapter.provider?.handleSyncError(expectedError)

        await self.fulfillment(of: [expectation], timeout: 10.0)
        XCTAssertTrue(errorHandler.handleBookmarkErrorCalled)
        XCTAssertEqual(errorHandler.capturedError as? NSError, expectedError)
    }

    func testWhenSyncErrorPublished_ThenErrorHandlerSyncCredentialsSuccededCalled() async {
        let expectation = XCTestExpectation(description: "Sync Did Update")
        await adapter.setUpProviderIfNeeded(database: database, metadataStore: metadataStore)

        Task {
            adapter.provider?.syncDidUpdateData()
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertTrue(errorHandler.syncBookmarksSuccededCalled)
    }

}
