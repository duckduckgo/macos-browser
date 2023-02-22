//
//  ConfigurationDownloaderTests.swift
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
import Combine
@testable import DuckDuckGo_Privacy_Browser

final class ConfigurationDownloaderTests: XCTestCase {

    static let resultData = "test".data(using: .utf8)!

    var cancellables = Set<AnyCancellable>()

    func test_urls_do_not_contain_localhost() {
        for url in ConfigurationLocation.allCases {
            XCTAssertFalse(url.rawValue.contains("localhost"))
            XCTAssertFalse(url.rawValue.contains("127.0.0.1"))
        }
    }

    func test_when_store_etag_fails_then_failure_returned_and_no_etag_stored() {
        let response = HTTPURLResponse.success
        let storageMock = MockStorage()
        storageMock.errorOnStoreEtag = true

        let networkingMock = MockNetworking(result: (Self.resultData, response))
        let downloader = DefaultConfigurationDownloader(storage: storageMock, dataTaskProvider: networkingMock, deliveryQueue: DispatchQueue.main)

        var completionResult: Subscribers.Completion<Error>?
        downloader.download(.bloomFilterBinary, embeddedEtag: nil).sink { completion in
            completionResult = completion
        } receiveValue: { _ in
            XCTFail("expected value")
        }.store(in: &cancellables)

        XCTAssertNotNil(completionResult)
        if case .failure = completionResult! {
            // we good
        } else {
            XCTFail("completion was not expected failure")
        }

        // Data may have been stored by this point, nothing we can do about that
        XCTAssertNil(storageMock.etag)
        XCTAssertNil(storageMock.etagConfig)
    }

    func test_when_store_data_fails_then_failure_returned_and_no_data_or_etag_stored() {
        let response = HTTPURLResponse.success
        let storageMock = MockStorage()
        storageMock.errorOnStoreData = true

        let networkingMock = MockNetworking(result: (Self.resultData, response))
        let downloader = DefaultConfigurationDownloader(storage: storageMock, dataTaskProvider: networkingMock, deliveryQueue: DispatchQueue.main)

        var completionResult: Subscribers.Completion<Error>?
        downloader.download(.bloomFilterBinary, embeddedEtag: nil).sink { completion in
            completionResult = completion
        } receiveValue: { _ in
            XCTFail("expected value")
        }.store(in: &cancellables)

        XCTAssertNotNil(completionResult)
        if case .failure = completionResult! {
            // we good
        } else {
            XCTFail("completion was not expected failure")
        }

        XCTAssertNil(storageMock.data)
        XCTAssertNil(storageMock.etag)
        XCTAssertNil(storageMock.dataConfig)
        XCTAssertNil(storageMock.etagConfig)
    }

    func test_when_response_is_success_and_no_etag_then_error_returned() {
        let response = HTTPURLResponse.successNoEtag
        let storageMock = MockStorage()
        let networkingMock = MockNetworking(result: (Self.resultData, response))
        let downloader = DefaultConfigurationDownloader(storage: storageMock, dataTaskProvider: networkingMock, deliveryQueue: DispatchQueue.main)

        var completionResult: Subscribers.Completion<Error>?
        downloader.download(.bloomFilterBinary, embeddedEtag: nil).sink { completion in
            completionResult = completion
        } receiveValue: { _ in
            XCTFail("expected value")
        }.store(in: &cancellables)

        XCTAssertNotNil(completionResult)
        if case .failure = completionResult! {
            // we good
        } else {
            XCTFail("completion was not expected failure")
        }

        XCTAssertNil(storageMock.data)
        XCTAssertNil(storageMock.etag)
        XCTAssertNil(storageMock.dataConfig)
        XCTAssertNil(storageMock.etagConfig)
    }

    func test_when_response_is_error_then_error_returned() {
        let response = HTTPURLResponse.internalServerError
        let storageMock = MockStorage()
        let networkingMock = MockNetworking(result: (Self.resultData, response))
        let downloader = DefaultConfigurationDownloader(storage: storageMock, dataTaskProvider: networkingMock, deliveryQueue: DispatchQueue.main)

        var completionResult: Subscribers.Completion<Error>?
        downloader.download(.bloomFilterBinary, embeddedEtag: nil).sink { completion in
            completionResult = completion
        } receiveValue: { _ in
            XCTFail("expected value")
        }.store(in: &cancellables)

        XCTAssertNotNil(completionResult)
        if case .failure = completionResult! {
            // we good
        } else {
            XCTFail("completion was not expected failure")
        }

        XCTAssertNil(storageMock.data)
        XCTAssertNil(storageMock.etag)
        XCTAssertNil(storageMock.dataConfig)
        XCTAssertNil(storageMock.etagConfig)
    }

    func test_when_response_is_not_modified_and_valid_etag_then_nil_meta_returned_and_no_data_stored() {
        let response = HTTPURLResponse.notModified
        let storageMock = MockStorage()
        let networkingMock = MockNetworking(result: (Self.resultData, response))
        let downloader = DefaultConfigurationDownloader(storage: storageMock, dataTaskProvider: networkingMock, deliveryQueue: DispatchQueue.main)
        var meta: ConfigurationDownloadMeta?
        downloader.download(.bloomFilterBinary, embeddedEtag: nil).sink { completion in
            if case .failure = completion {
                XCTFail("unexpected failure")
            }
        } receiveValue: { value in
            meta = value
        }.store(in: &cancellables)

        XCTAssertNil(meta)
        XCTAssertNil(storageMock.data)
        XCTAssertNil(storageMock.etag)
        XCTAssertNil(storageMock.dataConfig)
        XCTAssertNil(storageMock.etagConfig)
    }

    func test_when_etag_and_data_stored_then_etag_added_to_request() {

        let requestedEtag = UUID().uuidString

        let response = HTTPURLResponse.success
        let storageMock = MockStorage()
        storageMock.data = Data()
        storageMock.etag = requestedEtag

        let networkingMock = MockNetworking(result: (Self.resultData, response))
        let downloader = DefaultConfigurationDownloader(storage: storageMock, dataTaskProvider: networkingMock, deliveryQueue: DispatchQueue.main)
        _ = downloader.download(.bloomFilterSpec, embeddedEtag: nil)

        XCTAssertEqual(requestedEtag, networkingMock.request?.value(forHTTPHeaderField: HTTPURLResponse.ifNoneMatchHeader))
    }

    func test_when_no_etag_stored_then_no_etag_added_to_request() {

        let response = HTTPURLResponse.success
        let storageMock = MockStorage()
        storageMock.data = Data()

        let networkingMock = MockNetworking(result: (Self.resultData, response))
        let downloader = DefaultConfigurationDownloader(storage: storageMock, dataTaskProvider: networkingMock, deliveryQueue: DispatchQueue.main)
        _ = downloader.download(.bloomFilterSpec, embeddedEtag: nil)

        XCTAssertNil(networkingMock.request?.value(forHTTPHeaderField: HTTPURLResponse.ifNoneMatchHeader))
    }

    func test_when_no_data_stored_then_no_etag_added_to_request() {

        let response = HTTPURLResponse.success
        let storageMock = MockStorage()
        storageMock.etag = ""

        let networkingMock = MockNetworking(result: (Self.resultData, response))
        let downloader = DefaultConfigurationDownloader(storage: storageMock, dataTaskProvider: networkingMock, deliveryQueue: DispatchQueue.main)
        _ = downloader.download(.bloomFilterSpec, embeddedEtag: nil)

        XCTAssertNil(networkingMock.request?.value(forHTTPHeaderField: HTTPURLResponse.ifNoneMatchHeader))
    }

    func test_when_embedded_etag_and_external_etag_provided_then_external_included_in_request() {
        let embeddedEtag = UUID().uuidString
        let externalEtag = UUID().uuidString

        let response = HTTPURLResponse.success
        let storageMock = MockStorage()
        storageMock.data = Data()
        storageMock.etag = externalEtag

        let networkingMock = MockNetworking(result: (Self.resultData, response))
        let downloader = DefaultConfigurationDownloader(storage: storageMock, dataTaskProvider: networkingMock, deliveryQueue: DispatchQueue.main)
        _ = downloader.download(.bloomFilterSpec, embeddedEtag: embeddedEtag)

        XCTAssertEqual(externalEtag, networkingMock.request?.value(forHTTPHeaderField: HTTPURLResponse.ifNoneMatchHeader))
    }

    func test_when_embedded_etag_provided_then_is_included_in_request() {
        let embeddedEtag = UUID().uuidString

        let response = HTTPURLResponse.success
        let storageMock = MockStorage()
        let networkingMock = MockNetworking(result: (Self.resultData, response))
        let downloader = DefaultConfigurationDownloader(storage: storageMock, dataTaskProvider: networkingMock, deliveryQueue: DispatchQueue.main)
        _ = downloader.download(.bloomFilterSpec, embeddedEtag: embeddedEtag)

        XCTAssertEqual(embeddedEtag, networkingMock.request?.value(forHTTPHeaderField: HTTPURLResponse.ifNoneMatchHeader))
    }

    func test_when_response_is_success_and_valid_etag_then_meta_returned_and_data_stored() {

        for config in ConfigurationLocation.allCases {

            let response = HTTPURLResponse.success
            let storageMock = MockStorage()
            let networkingMock = MockNetworking(result: (Self.resultData, response))
            let downloader = DefaultConfigurationDownloader(storage: storageMock, dataTaskProvider: networkingMock, deliveryQueue: DispatchQueue.main)
            var meta: ConfigurationDownloadMeta?
            downloader.download(config, embeddedEtag: nil).sink { completion in
                if case .failure = completion {
                    XCTFail("unexpected failure for \(config.rawValue)")
                }
            } receiveValue: { value in
                meta = value
            }.store(in: &cancellables)

            XCTAssertEqual(meta?.etag, HTTPURLResponse.etagValue)
            XCTAssertEqual(meta?.data, Self.resultData)
            XCTAssertNotNil(storageMock.data)
            XCTAssertNotNil(storageMock.etag)
            XCTAssertEqual(storageMock.dataConfig, config)
            XCTAssertNotNil(storageMock.etagConfig, HTTPURLResponse.etagValue)

        }

    }

    class MockNetworking: DataTaskProviding {

        let result: (Data, URLResponse)
        var publisher: CurrentValueSubject<(data: Data, response: URLResponse), URLError>?
        var request: URLRequest?

        init(result: (Data, URLResponse)) {
            self.result = result
        }

        func send(_ data: Data, _ response: URLResponse) {
            publisher?.send((data: data, response: response))
        }

        func dataTaskPublisher(for request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), URLError> {
            self.request = request
            let publisher = CurrentValueSubject<(data: Data, response: URLResponse), URLError>(result)
            self.publisher = publisher
            return publisher.eraseToAnyPublisher()
        }

    }

    class MockStorage: ConfigurationStoring {

        enum Error: Swift.Error {
            case mockError
        }

        var errorOnStoreData = false
        var errorOnStoreEtag = false

        var data: Data?
        var dataConfig: ConfigurationLocation?

        var etag: String?
        var etagConfig: ConfigurationLocation?

        func loadData(for: ConfigurationLocation) -> Data? {
            return data
        }

        func loadEtag(for: ConfigurationLocation) -> String? {
            return etag
        }

        func saveData(_ data: Data, for config: ConfigurationLocation) throws {
            if errorOnStoreData {
                throw Error.mockError
            }

            self.data = data
            self.dataConfig = config
        }

        func saveEtag(_ etag: String, for config: ConfigurationLocation) throws {
            if errorOnStoreEtag {
                throw Error.mockError
            }

            self.etag = etag
            self.etagConfig = config
        }

        func log() { }

    }

}

fileprivate extension HTTPURLResponse {

    static let etagHeader = "Etag"
    static let ifNoneMatchHeader = "If-None-Match"
    static let etagValue = "test-etag"

    static let success = HTTPURLResponse(url: URL.blankPage,
                                         statusCode: 200,
                                         httpVersion: nil,
                                         headerFields: [HTTPURLResponse.etagHeader: HTTPURLResponse.etagValue])!

    static let notModified = HTTPURLResponse(url: URL.blankPage,
                                             statusCode: 304,
                                             httpVersion: nil,
                                             headerFields: [HTTPURLResponse.etagHeader: HTTPURLResponse.etagValue])!

    static let internalServerError = HTTPURLResponse(url: URL.blankPage,
                                                     statusCode: 500,
                                                     httpVersion: nil,
                                                     headerFields: [:])!

    static let successNoEtag = HTTPURLResponse(url: URL.blankPage,
                                               statusCode: 200,
                                               httpVersion: nil,
                                               headerFields: [:])!

}
