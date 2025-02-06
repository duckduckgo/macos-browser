//
//  DataImportViewModelTests.swift
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

import Common
import Foundation
import XCTest
@testable import DuckDuckGo_Privacy_Browser
import BrowserServicesKit

final class DataImportViewModelTests: XCTestCase {

    typealias Source = DataImport.Source
    typealias BrowserProfileList = DataImport.BrowserProfileList
    typealias BrowserProfile = DataImport.BrowserProfile
    typealias DataType = DataImport.DataType
    typealias DataTypeSummary = DataImport.DataTypeSummary

    var model: DataImportViewModel!

    override func tearDown() {
        model = nil
        importTask = nil
        openPanelCallback = nil
        NSError.disableSwizzledDescription = false
    }

    // MARK: - Tests

    // Validate supported DataType-s of all Import Sources
    func testDataImportSourceSupportedDataTypes() {
        for source in Source.allCases {
            if source.initialScreen == .profileAndDataTypesPicker {
                if source == .tor {
                    XCTAssertEqual(source.supportedDataTypes, [.bookmarks], source.importSourceName)
                } else {
                    XCTAssertEqual(source.supportedDataTypes, [.bookmarks, .passwords], source.importSourceName)
                }
            } else {
                if source == .bookmarksHTML {
                    XCTAssertEqual(source.supportedDataTypes, [.bookmarks], source.importSourceName)
                } else {
                    XCTAssertEqual(source.supportedDataTypes, [.passwords], source.importSourceName)
                }
            }
        }
    }

    func testWhenPreferredImportSourcesAvailable_firstPreferredSourceIsSelected() {
        model = DataImportViewModel(availableImportSources: [.safari, .csv, .bitwarden], preferredImportSources: [.firefox, .chrome, .bitwarden, .safari])
        XCTAssertEqual(model.importSource, .bitwarden)
    }

    func testWhenModelIsInstantiated_initialScreenIsShown() {
        for source in Source.allCases {
            model = DataImportViewModel(importSource: source)
            XCTAssertEqual(model.screen, source.initialScreen, "\(source)")
        }
    }

    func testImportTaskCancellation() async throws {
        setupModel(with: .firefox, profiles: [BrowserProfile.test])

        let e1 = expectation(description: "task started")
        let e2 = expectation(description: "task cancelled")
        self.importTask = { _, progress in
            e1.fulfill()
            await Task.yield() // let cancellation in

            do {
                try? await Task.sleep(interval: 10) // forever
                try progress(.importingPasswords(numberOfPasswords: nil, fraction: 0))
            } catch is CancellationError {
                e2.fulfill()
            } catch {
                XCTFail("unexpected \(error)")
            }
            return [:]
        }
        let eDismissed = expectation(description: "dismissed")
        Task { @MainActor in
            await fulfillment(of: [e1], timeout: 1)
            var model = self.model!
            model.performAction(for: .cancel) {
                eDismissed.fulfill()
            }
        }

        try await initiateImport(of: [.bookmarks, .passwords], from: .test(for: ThirdPartyBrowser.firefox))
        await fulfillment(of: [e2, eDismissed], timeout: 0)
    }

    func testWhenImportSummaryCompletesWithErrorsThenHasSummaryErrorsShouldReturnTrue() async throws {
        // GIVEN
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            // GIVEN
            let browser = try XCTUnwrap(ThirdPartyBrowser.browser(for: source))
            for dataType in DataType.allCases {
                setupModel(with: source, profiles: [BrowserProfile.test])
                try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                    dataType: .failure(Failure(.bookmarks, DataImport.ErrorType.dataCorrupted))
                ])

                // WHEN
                let result = model.hasAnySummaryError

                // THEN
                XCTAssertTrue(result)
            }
        }
    }

    func testWhenImportSummaryCompletesWithoutErrorsThenHasSummaryErrorsShouldReturnFalse() async throws {
        // GIVEN
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            // GIVEN
            let browser = try XCTUnwrap(ThirdPartyBrowser.browser(for: source))
            for dataType in DataType.allCases {
                setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])
                try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                    dataType: .success(.init(successful: 10, duplicate: 0, failed: 1))
                ])

                // WHEN
                let result = model.hasAnySummaryError

                // THEN
                XCTAssertFalse(result)
            }
        }
    }

    // MARK: - Browser profiles

    func testWhenNoProfilesAreLoaded_selectedProfileIsNil() {
        model = DataImportViewModel(importSource: .safari, loadProfiles: { source in
            XCTAssertEqual(source, .safari)
            return .init(browser: source, profiles: [])
        })
        XCTAssertNil(model.selectedProfile)
    }

    func testWhenProfilesAreLoaded_defaultProfileIsSelected() {
        setupModel(with: .firefox, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])
        XCTAssertEqual(model.selectedProfile, .default(for: .firefox))
    }

    func testWhenInvalidProfilesArePresent_onlyValidProfilesShownAndFirstValidProfileSelected() {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else { continue }

            model = DataImportViewModel(importSource: source, loadProfiles: { browser in
                    .init(browser: browser, profiles: [
                        .default(for: browser),
                        .test(for: browser),
                        .test2(for: browser),
                        .test3(for: browser),
                    ]) { profile in
                        { // swiftlint:disable:this opening_brace
                            switch profile {
                            case .default(for: browser): .init(logins: .unavailable(path: "test"), bookmarks: .unavailable(path: "test"))
                            case .test(for: browser): .init(logins: .available, bookmarks: .unavailable(path: "test"))
                            case .test2(for: browser): .init(logins: .unavailable(path: "test"), bookmarks: .available)
                            default: .init(logins: .available, bookmarks: .available)
                            }
                        }
                    }
            })

            XCTAssertEqual(model.browserProfiles?.validImportableProfiles, [
                .test(for: browser),
                .test2(for: browser),
                .test3(for: browser),
            ], "\(browser)")
            XCTAssertEqual(model.selectedProfile, .test(for: browser), "\(browser)")
        }
    }

    func testWhenDefaultProfileIsInvalidAndOnlyOneValidProfileIsPresent_validProfileSelected() {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else { continue }

            model = DataImportViewModel(importSource: source, loadProfiles: { browser in
                    .init(browser: browser, profiles: [
                        .default(for: browser),
                        .test(for: browser),
                    ]) { profile in
                        { // swiftlint:disable:this opening_brace
                            switch profile {
                            case .default(for: browser): .init(logins: .unavailable(path: "test"), bookmarks: .unavailable(path: "test"))
                            default: .init(logins: .available, bookmarks: .available)
                            }
                        }
                    }
            })

            XCTAssertEqual(model.selectedProfile, .test(for: browser))
        }
    }

    func testWhenNoValidProfilesPresent_noProfilesShownAndDefaultProfileSelected() {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else { continue }

            model = DataImportViewModel(importSource: source, loadProfiles: { browser in
                    .init(browser: browser, profiles: [
                        .default(for: browser),
                        .test(for: browser),
                        .test2(for: browser),
                        .test3(for: browser),
                    ]) { profile in
                        { // swiftlint:disable:this opening_brace
                            switch profile {
                            case .default(for: browser): .init(logins: .unavailable(path: "test"), bookmarks: .unavailable(path: "test"))
                            case .test(for: browser): .init(logins: .unavailable(path: "test"), bookmarks: .unavailable(path: "test"))
                            case .test2(for: browser): .init(logins: .unavailable(path: "test"), bookmarks: .unavailable(path: "test"))
                            default: .init(logins: .unavailable(path: "test"), bookmarks: .unavailable(path: "test"))
                            }
                        }
                    }
            })

            XCTAssertEqual(model.browserProfiles?.validImportableProfiles, [], "\(browser)")
            XCTAssertEqual(model.selectedProfile, .default(for: browser), "\(browser)")
        }
    }

    func testWhenImportSourceChanged_AnotherDefaultProfileIsSelected() {
        setupModel(with: .firefox, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])
        model.selectedProfile = .test(for: .firefox)
        model.update(with: .chromium)
        XCTAssertEqual(model.selectedProfile, .default(for: .chrome))
    }

    func testWhenNoDefaultProfileIsLoaded_firstProfileIsSelected() {
        model = DataImportViewModel(importSource: .chrome, loadProfiles: { .init(browser: $0, profiles: [ .test(for: $0), .test2(for: $0) ]) })
        XCTAssertEqual(model.selectedProfile, .test(for: .chrome))
    }

    // MARK: - Buttons

    @MainActor
    func testWhenNextButtonIsClicked_screenForTheButtonIsShown() {
        setupModel(with: .safari)
        model.performAction(.next(.fileImport(dataType: .bookmarks)))
        XCTAssertEqual(model.screen, .fileImport(dataType: .bookmarks))
    }

    @MainActor
    func testWhenNoDataTypesSelected_actionButtonDisabled() {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            model = DataImportViewModel(importSource: source)

            XCTAssertEqual(model.selectedDataTypes, source.supportedDataTypes)
            for dataType in source.supportedDataTypes {
                model.setDataType(dataType, selected: false)
            }
            XCTAssertEqual(model.selectedDataTypes, [])

            XCTAssertEqual(model.buttons, [.cancel, .initiateImport(disabled: true)])
        }
    }

    @MainActor
    func testWhenCancelButtonClicked_dismissIsCalled() {
        model = DataImportViewModel(importSource: .safari)

        XCTAssertEqual(model.secondaryButton, .cancel)
        let e = expectation(description: "dismiss called")
        model.performAction(for: .cancel) {
            e.fulfill()
        }

        waitForExpectations(timeout: 0)
    }

    @MainActor
    func testWhenProfilesAreLoadedAndImporterCanImportStraightAway_buttonActionsAreCancelAndImport() {
        model = DataImportViewModel(importSource: .safari, loadProfiles: { .init(browser: $0, profiles: [.test(for: $0)]) }, dataImporterFactory: { _, _, _, _ in
            ImporterMock()
        })

        XCTAssertEqual(model.selectedDataTypes, [.bookmarks, .passwords])
        XCTAssertEqual(model.actionButton, .initiateImport(disabled: false))
        XCTAssertEqual(model.secondaryButton, .cancel)
    }

    @MainActor
    func testWhenProfilesAreLoadedAndImporterRequiresKeyChainPassword_buttonActionsAreCancelAndMoreInfo() {
        model = DataImportViewModel(importSource: .safari, loadProfiles: { .init(browser: $0, profiles: [.test(for: $0)]) }, dataImporterFactory: { _, _, _, _ in
            ImporterMock(keychainPasswordRequiredFor: [.passwords])
        })

        XCTAssertEqual(model.selectedDataTypes, [.bookmarks, .passwords])
        XCTAssertEqual(model.actionButton, .next(.moreInfo))
        XCTAssertEqual(model.secondaryButton, .cancel)

        model.performAction(.next(.moreInfo))

        XCTAssertEqual(model.screen, .moreInfo)
        XCTAssertEqual(model.actionButton, .initiateImport(disabled: false))
        XCTAssertEqual(model.secondaryButton, .back)

        model.performAction(.back)
        XCTAssertEqual(model.screen, Source.safari.initialScreen)
    }

    @MainActor
    func testWhenProfilesAreLoadedAndImporterRequiresKeyChainPasswordButPasswordsDataTypeNotSelected_buttonActionsAreCancelAndImport() {
        model = DataImportViewModel(importSource: .safari, loadProfiles: { .init(browser: $0, profiles: [.test(for: $0)]) }, dataImporterFactory: { _, _, _, _ in
            ImporterMock(keychainPasswordRequiredFor: [.passwords])
        })
        model.setDataType(.passwords, selected: false)

        XCTAssertEqual(model.actionButton, .initiateImport(disabled: false))
        XCTAssertEqual(model.secondaryButton, .cancel)
    }

    @MainActor
    func testWhenFileImportSourceSelected_buttonActionsAreCancelAndNone() {
        for source in Source.allCases where ThirdPartyBrowser.browser(for: source) == nil || source.isBrowser == false {
            model = DataImportViewModel(importSource: source, loadProfiles: {
                XCTAssertNotNil(ThirdPartyBrowser.browser(for: source), "Unexpected loadProfiles – \(source)")
                return .init(browser: $0, profiles: [.test(for: $0)])
            })

            XCTAssertEqual(model.screen, .fileImport(dataType: source.supportedDataTypes.first!, summary: []), "\(source)")
            XCTAssertEqual(model.selectedDataTypes, source.supportedDataTypes, "\(source)")
            XCTAssertNil(model.actionButton)
            XCTAssertEqual(model.secondaryButton, .cancel, "\(source)")
        }
    }

    @MainActor
    func testWhenNoProfilesAreLoaded_buttonActionsAreCancelAndProceedToFileImport() {
        model = DataImportViewModel(importSource: .firefox, loadProfiles: { .init(browser: $0, profiles: []) })

        XCTAssertEqual(model.selectedDataTypes, [.bookmarks, .passwords])
        XCTAssertEqual(model.actionButton, .next(.fileImport(dataType: .bookmarks)))
        XCTAssertEqual(model.secondaryButton, .cancel)
    }

    @MainActor
    func testWhenNoProfilesAreLoadedAndBookmarksDataTypeUnselected_fileImportDataTypeChanges() {
        model = DataImportViewModel(importSource: .firefox, loadProfiles: { .init(browser: $0, profiles: []) })

        model.setDataType(.bookmarks, selected: false)

        XCTAssertEqual(model.selectedDataTypes, [.passwords])
        XCTAssertEqual(model.actionButton, .next(.fileImport(dataType: .passwords)))
        XCTAssertEqual(model.secondaryButton, .cancel)
    }

    @MainActor
    func testWhenPasswordsDataTypeUnselected_fileImportDataTypeChanges() {
        model = DataImportViewModel(importSource: .firefox, loadProfiles: { .init(browser: $0, profiles: []) })

        model.setDataType(.passwords, selected: false)

        XCTAssertEqual(model.selectedDataTypes, [.bookmarks])
        XCTAssertEqual(model.actionButton, .next(.fileImport(dataType: .bookmarks)))
        XCTAssertEqual(model.secondaryButton, .cancel)
    }

    @MainActor
    func testWhenImportSourceChanges_selectedDataTypesAreReset() {
        setupModel(with: .safari, profiles: [BrowserProfile.test]) { _, _, _, _ in
            ImporterMock(importableTypes: [.passwords, .bookmarks], keychainPasswordRequiredFor: [.passwords])
        }

        model.setDataType(.bookmarks, selected: false)
        model.setDataType(.passwords, selected: false)

        model.update(with: .brave)

        XCTAssertEqual(model.selectedDataTypes, [.bookmarks, .passwords])
        XCTAssertEqual(model.actionButton, .next(.moreInfo))
        XCTAssertEqual(model.secondaryButton, .cancel)
    }

    @MainActor
    func testWhenImporterCannotImportPasswords_nextScreenIsFileImport() {
        model = DataImportViewModel(importSource: .yandex, loadProfiles: { .init(browser: $0, profiles: [.test(for: $0)]) }, dataImporterFactory: { _, _, _, _ in
            ImporterMock(importableTypes: [.bookmarks])
        })

        model.setDataType(.bookmarks, selected: false)

        XCTAssertEqual(model.actionButton, .next(.fileImport(dataType: .passwords)))
        XCTAssertEqual(model.secondaryButton, .cancel)
    }

    @MainActor
    func testWhenReadPermissionRequired_nextScreenIsReadPermission() {
        setupModel(with: .safari, profiles: [BrowserProfile.test]) { _, _, _, _ in
            ImporterMock { _, _ in
                [.passwords: SafariBookmarksReader.ImportError(type: .readPlist, underlyingError:
                                                                CocoaError(.fileReadNoPermission, userInfo: [kCFErrorURLKey as String: URL.testCSV]))]
            }
        }

        XCTAssertEqual(model.buttons, [.cancel, .initiateImport(disabled: false)])
        model.performAction(.initiateImport(disabled: false))

        let expectation = DataImportViewModel(importSource: .safari, screen: .getReadPermission(.testCSV))
        XCTAssertEqual(model.description, expectation.description)
    }

    // MARK: - Import from browser profile
    // MARK: Primary Password

    func testWhenImporterRequiresPrimaryPassword_passwordIsRequested() async throws {
        var e: XCTestExpectation!
        setupModel(with: .firefox, profiles: [BrowserProfile.test]) { _, _, _, p in
            ImporterMock(password: p, accessValidator: { importer, dataTypes in
                XCTAssertEqual(dataTypes, [.bookmarks, .passwords])
                if let password = importer.password {
                    XCTAssertEqual(password, p)
                    XCTAssertEqual(password, "password")
                    return [:]
                } else {
                    return [.passwords: FirefoxLoginReader.ImportError(type: .requiresPrimaryPassword, underlyingError: nil)]
                }
            }, importTask: self.importTask)
        } requestPrimaryPasswordCallback: { source in
            XCTAssertEqual(source, .firefox)
            e.fulfill()
            return "password"
        }

        e = expectation(description: "should request password")
        try await initiateImport(of: [.bookmarks, .passwords], from: .test(for: ThirdPartyBrowser.firefox), resultingWith: {
            return [
                .bookmarks: .success(.init(successful: 1, duplicate: 1, failed: 1)),
                .passwords: .success(.init(successful: 2, duplicate: 2, failed: 2)),
            ]
        }())
        await fulfillment(of: [e], timeout: 0)

        let expectation = DataImportViewModel(importSource: .firefox, screen: .summary([.bookmarks, .passwords]), summary: [.init(.bookmarks, .success(.init(successful: 1, duplicate: 1, failed: 1))), .init(.passwords, .success(.init(successful: 2, duplicate: 2, failed: 2)))])
        XCTAssertEqual(model.description, expectation.description)

    }

    func testWhenImporterRequiresPrimaryPasswordAndPasswordIsInvalid_passwordIsRequestedAgain() async throws {
        var e: XCTestExpectation!
        var e2: XCTestExpectation!
        setupModel(with: .firefox, profiles: [BrowserProfile.test]) { _, _, _, p in
            ImporterMock(password: p, accessValidator: { importer, _ in
                if importer.password != nil {
                    return [:]
                } else {
                    return [.passwords: FirefoxLoginReader.ImportError(type: .requiresPrimaryPassword, underlyingError: nil)]
                }
            }, importTask: self.importTask)
        } requestPrimaryPasswordCallback: { source in
            XCTAssertEqual(source, .firefox)
            if let e2 {
                e2.fulfill()
                return "password"
            } else {
                e.fulfill()
                return "invalid_password"
            }
        }

        e = expectation(description: "should request password")
        self.importTask = { dataTypes, _ in
            if e2 == nil {
                XCTAssertEqual(dataTypes, [.bookmarks, .passwords], "first data import should contain both data types")
                e2 = self.expectation(description: "should request password again")
                return [
                    .bookmarks: .success(.init(successful: 1, duplicate: 1, failed: 1)),
                    .passwords: .failure(FirefoxLoginReader.ImportError(type: .requiresPrimaryPassword, underlyingError: nil)),
                ]
            } else {
                XCTAssertEqual(dataTypes, [.passwords], "second data import should contain only failed data type (passwords)")
                return [
                    .passwords: .success(.init(successful: 2, duplicate: 2, failed: 2)),
                ]
            }
        }
        try await initiateImport(of: [.bookmarks, .passwords], from: .test(for: ThirdPartyBrowser.firefox))
        await fulfillment(of: [e, e2], timeout: 0)

        let expected = DataImportViewModel(importSource: .firefox, screen: .summary([.bookmarks, .passwords]), summary: [.init(.bookmarks, .success(.init(successful: 1, duplicate: 1, failed: 1))), .init(.passwords, .success(.init(successful: 2, duplicate: 2, failed: 2)))])
        XCTAssertEqual(model.description, expected.description)
    }

    func testWhenImporterRequiresPrimaryPasswordButRejected_initialStateRestored() async throws {
        let e = expectation(description: "should request password")
        setupModel(with: .firefox, profiles: [BrowserProfile.test]) { _, _, _, p in
            ImporterMock(password: p, accessValidator: { _, _ in
                [.passwords: FirefoxLoginReader.ImportError(type: .requiresPrimaryPassword, underlyingError: nil)]
            }, importTask: self.importTask)
        } requestPrimaryPasswordCallback: { _ in
            e.fulfill()
            return nil
        }

        try await initiateImport(of: [.bookmarks, .passwords], from: .test(for: ThirdPartyBrowser.firefox))
        await fulfillment(of: [e], timeout: 0)

        let expected = DataImportViewModel(importSource: .firefox, screen: Source.firefox.initialScreen)
        XCTAssertEqual(model.description, expected.description)
    }

    @MainActor
    func testWhenImporterRequiresKeychainPasswordButRejected_moreInfoScreenRestored() async throws {
        setupModel(with: .brave, profiles: [BrowserProfile.test]) { _, _, _, p in
            ImporterMock(password: p, keychainPasswordRequiredFor: [.passwords], accessValidator: { _, _ in
                [.passwords: ChromiumLoginReader.ImportError(type: .userDeniedKeychainPrompt)]
            }, importTask: self.importTask)
        }

        model.performAction(.next(.moreInfo))
        try await initiateImport(of: [.bookmarks, .passwords], from: .test(for: ThirdPartyBrowser.brave))

        let expected = DataImportViewModel(importSource: .brave, screen: .moreInfo)
        XCTAssertEqual(model.description, expected.description)
    }

    // MARK: Browser Sources: initial -> import -> bookmarks success…

    // initial -> import -> bookmarks success, passwords success -> summary
    func testWhenBrowserBookmarksImportSucceedsPasswordsImportSucceeds_summaryShown() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .success(.init(successful: 100, duplicate: 2, failed: 1)),
                .passwords: .success(.init(successful: 13, duplicate: 42, failed: 3)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .summary([.bookmarks, .passwords]), summary: [.init(.bookmarks, .success(.init(successful: 100, duplicate: 2, failed: 1))), .init(.passwords, .success(.init(successful: 13, duplicate: 42, failed: 3)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import -> bookmarks success, passwords failure -> file import
    func testWhenBrowserBookmarksImportSucceedsPasswordsImportFails_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .success(.init(successful: 10, duplicate: 0, failed: 0)),
                .passwords: .failure(Failure(.passwords, .decryptionError)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .passwords, summary: [.bookmarks]), summary: [.init(.bookmarks, .success(.init(successful: 10, duplicate: 0, failed: 0))), .init(.passwords, .failure(Failure(.passwords, .decryptionError)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import -> bookmarks success, no passwords imported -> file import
    func testWhenBrowserBookmarksImportSucceedsNoPasswords_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .success(.init(successful: 10, duplicate: 0, failed: 0)),
                .passwords: .success(.init(successful: 0, duplicate: 0, failed: 0)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .passwords, summary: [.bookmarks, .passwords]), summary: [.init(.bookmarks, .success(.init(successful: 10, duplicate: 0, failed: 0))), .init(.passwords, .success(.init(successful: 0, duplicate: 0, failed: 0)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import -> bookmarks success, no passwords file found -> file import
    func testWhenBrowserBookmarksImportSucceedsNoPasswordsFileError_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .success(.init(successful: 42, duplicate: 1, failed: 0)),
                .passwords: .failure(Failure(.passwords, .noData)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .passwords, summary: [.bookmarks]), summary: [.init(.bookmarks, .success(.init(successful: 42, duplicate: 1, failed: 0))), .init(.passwords, .failure(Failure(.passwords, .noData)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import -> bookmarks success, passwords (nil) -> boookmarks summary [Next]
    func testWhenBrowserBookmarksOnlyImportSucceeds_bookmarksSummaryShown() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .success(.init(successful: 42, duplicate: 1, failed: 3)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .summary([.bookmarks]), summary: [.init(.bookmarks, .success(.init(successful: 42, duplicate: 1, failed: 3)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    func testWhenFileImportOpenPanelIsRejected_fileImportScreenRestored() async throws {
        setupModel(with: .firefox, profiles: [BrowserProfile.test], screen: .fileImport(dataType: .bookmarks))

        openPanelCallback = { _ in
            nil
        }
        try await initiateImport(of: [.bookmarks], fromFile: .testHTML)

        let expectation = DataImportViewModel(importSource: .firefox, screen: .fileImport(dataType: .bookmarks))
        XCTAssertEqual(model.description, expectation.description)
    }

    // MARK: Browser Sources: initial -> import -> bookmarks failure…

    // initial -> import -> bookmarks failure, passwords success -> file import
    func testWhenBrowserPasswordsImportSucceedsBookmarksImportFails_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .failure(Failure(.bookmarks, .decryptionError)),
                .passwords: .success(.init(successful: 10, duplicate: 0, failed: 0)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .bookmarks, summary: [.passwords]), summary: [.init(.passwords, .success(.init(successful: 10, duplicate: 0, failed: 0))), .init(.bookmarks, .failure(Failure(.bookmarks, .decryptionError)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import -> bookmarks failure, no passwords imported -> file import
    func testWhenBrowserBookmarksImportFailsNoPasswords_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .failure(Failure(.bookmarks, .decryptionError)),
                .passwords: .success(.init(successful: 0, duplicate: 0, failed: 0)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .bookmarks, summary: [.passwords]), summary: [.init(.passwords, .success(.init(successful: 0, duplicate: 0, failed: 0))), .init(.bookmarks, .failure(Failure(.bookmarks, .decryptionError)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import -> bookmarks failure, passwords failure -> file import
    func testWhenBrowserBookmarksImportFailsPasswordsImportFails_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .failure(Failure(.bookmarks, .dataCorrupted)),
                .passwords: .failure(Failure(.passwords, .keychainError)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .bookmarks), summary: [.init(.bookmarks, .failure(Failure(.bookmarks, .dataCorrupted))), .init(.passwords, .failure(Failure(.passwords, .keychainError)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import -> bookmarks failure, no passwords file found -> file import
    func testWhenBrowserBookmarksImportFailsNoPasswordsFileError_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .failure(Failure(.bookmarks, .dataCorrupted)),
                .passwords: .failure(Failure(.passwords, .noData)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .bookmarks), summary: [.init(.bookmarks, .failure(Failure(.bookmarks, .dataCorrupted))), .init(.passwords, .failure(Failure(.passwords, .noData)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import -> bookmarks failure, passwords (nil) -> file import
    func testWhenBrowserBookmarksOnlyImportSucceeds_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .failure(Failure(.bookmarks, .dataCorrupted)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .bookmarks), summary: [.init(.bookmarks, .failure(Failure(.bookmarks, .dataCorrupted)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // MARK: Browser Sources: initial -> import -> no bookmarks…

    // initial -> import -> no bookmarks, passwords success -> file import
    func testWhenBrowserNoBookmarksPasswordsImportSucceeds_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .success(.init(successful: 0, duplicate: 0, failed: 0)),
                .passwords: .success(.init(successful: 42, duplicate: 1, failed: 1)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .bookmarks, summary: [.bookmarks, .passwords]), summary: [.init(.bookmarks, .success(.init(successful: 0, duplicate: 0, failed: 0))), .init(.passwords, .success(.init(successful: 42, duplicate: 1, failed: 1)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import -> no bookmarks, passwords failuire -> file import
    func testWhenBrowserNoBookmarksPasswordsImportFails_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .success(.init(successful: 0, duplicate: 0, failed: 0)),
                .passwords: .failure(Failure(.passwords, .decryptionError)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .bookmarks, summary: [.bookmarks]), summary: [.init(.bookmarks, .success(.init(successful: 0, duplicate: 0, failed: 0))), .init(.passwords, .failure(Failure(.passwords, .decryptionError)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import -> no bookmarks, no passwords -> file import
    func testWhenBrowserNoBookmarksNoPasswords_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .success(.init(successful: 0, duplicate: 0, failed: 0)),
                .passwords: .success(.init(successful: 0, duplicate: 0, failed: 0)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .bookmarks, summary: [.bookmarks, .passwords]), summary: [.init(.bookmarks, .success(.init(successful: 0, duplicate: 0, failed: 0))), .init(.passwords, .success(.init(successful: 0, duplicate: 0, failed: 0)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import -> no bookmarks, no passwords file found -> file import
    func testWhenBrowserNoBookmarksNoPasswordsFileFound_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .success(.init(successful: 0, duplicate: 0, failed: 0)),
                .passwords: .failure(Failure(.passwords, .noData)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .bookmarks, summary: [.bookmarks]), summary: [.init(.bookmarks, .success(.init(successful: 0, duplicate: 0, failed: 0))), .init(.passwords, .failure(Failure(.passwords, .noData)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import -> no bookmarks, passwords (nil) -> file import
    func testWhenBrowserNoBookmarksOnly_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .success(.init(successful: 0, duplicate: 0, failed: 0)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .bookmarks, summary: [.bookmarks]), summary: [.init(.bookmarks, .success(.init(successful: 0, duplicate: 0, failed: 0)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // MARK: Browser Sources: initial -> import -> no bookmarks file found…

    // initial -> import -> no bookmarks file found, passwords success -> file import
    func testWhenBrowserNoBookmarksFileFoundPasswordsImportSucceeds_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .failure(Failure(.bookmarks, .noData)),
                .passwords: .success(.init(successful: 42, duplicate: 1, failed: 1)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .bookmarks, summary: [.passwords]), summary: [.init(.passwords, .success(.init(successful: 42, duplicate: 1, failed: 1))), .init(.bookmarks, .failure(Failure(.bookmarks, .noData)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import -> no bookmarks file found, passwords failuire -> file import
    func testWhenBrowserNoBookmarksFileFoundPasswordsImportFails_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .failure(Failure(.bookmarks, .noData)),
                .passwords: .failure(Failure(.passwords, .decryptionError)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .bookmarks), summary: [.init(.bookmarks, .failure(Failure(.bookmarks, .noData))), .init(.passwords, .failure(Failure(.passwords, .decryptionError)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import -> no bookmarks file found, no passwords -> file import
    func testWhenBrowserNoBookmarksFileFoundNoPasswords_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .failure(Failure(.bookmarks, .noData)),
                .passwords: .success(.init(successful: 0, duplicate: 0, failed: 0)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .bookmarks, summary: [.passwords]), summary: [.init(.passwords, .success(.init(successful: 0, duplicate: 0, failed: 0))), .init(.bookmarks, .failure(Failure(.bookmarks, .noData)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import -> no bookmarks file found, no passwords file found -> file import
    func testWhenBrowserNoBookmarksFileFoundNoPasswordsFileFound_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .failure(Failure(.bookmarks, .noData)),
                .passwords: .failure(Failure(.passwords, .noData)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .bookmarks), summary: [.init(.bookmarks, .failure(Failure(.bookmarks, .noData))), .init(.passwords, .failure(Failure(.passwords, .noData)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import -> no bookmarks file found, passwords (nil) -> file import
    func testWhenBrowserNoBookmarksFileFoundOnly_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: source.supportedDataTypes, from: .test(for: browser), resultingWith: [
                .bookmarks: .failure(Failure(.bookmarks, .noData)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .bookmarks), summary: [.init(.bookmarks, .failure(Failure(.bookmarks, .noData)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // MARK: Browser Sources: initial -> import passwords…

    // initial -> import passwords -> passwords success -> summary
    func testWhenBrowserOnlySelectedPasswordsImportSucceeds_summaryShown() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: [.passwords], from: .test(for: browser), resultingWith: [
                .passwords: .success(.init(successful: 1, duplicate: 2, failed: 3)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .summary([.passwords]), summary: [.init(.passwords, .success(.init(successful: 1, duplicate: 2, failed: 3)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import passwords -> passwords failure -> summary
    func testWhenBrowserOnlySelectedPasswordsImportFails_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: [.passwords], from: .test(for: browser), resultingWith: [
                .passwords: .failure(Failure(.passwords, .dataCorrupted)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .passwords), summary: [.init(.passwords, .failure(Failure(.passwords, .dataCorrupted)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import passwords -> no passwords
    func testWhenBrowserOnlySelectedPasswordsResultsWithNoPasswords_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: [.passwords], from: .test(for: browser), resultingWith: [
                .passwords: .success(.init(successful: 0, duplicate: 0, failed: 0)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .passwords, summary: [.passwords]), summary: [.init(.passwords, .success(.init(successful: 0, duplicate: 0, failed: 0)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import passwords -> no passwords file found
    func testWhenBrowserOnlySelectedPasswordsImportResultsWithNoPasswordsFileFound_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: [.passwords], from: .test(for: browser), resultingWith: [
                .passwords: .failure(Failure(.passwords, .noData)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .passwords), summary: [.init(.passwords, .failure(Failure(.passwords, .noData)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // initial -> import passwords -> only file import supported for passwords -> [Next] -> file import
    @MainActor
    func testWhenBrowserOnlySelectedPasswordsCannotBeImported_manualImportSuggested() throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2], dataImporterFactory: { src, dataType, _, _ in
                XCTAssertEqual(src, source)
                XCTAssertNil(dataType)
                return ImporterMock(importableTypes: [.bookmarks])
            })

            model.selectedDataTypes = [.passwords]

            XCTAssertEqual(model.actionButton, .next(.fileImport(dataType: .passwords)), source.rawValue)
            XCTAssertEqual(model.secondaryButton, .cancel, source.rawValue)

            model.performAction(model.actionButton!)

            let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .passwords), summary: [])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // MARK: - File Import Sources

    // csv/html file import succeeds -> summary
    @MainActor
    func testWhenFileImportSourceImportSucceeds_summaryShown() async throws {
        for source in Source.allCases where source.initialScreen.isFileImport {
            setupModel(with: source)

            guard case .fileImport(dataType: let dataType, summary: []) = model.screen else {
                XCTFail("\(source): unexpected initial screen: \(model.screen)")
                continue
            }

            XCTAssertEqual([dataType], source.supportedDataTypes)
            XCTAssertEqual(model.selectedDataTypes, [dataType], source.rawValue)
            XCTAssertEqual(model.buttons, [.cancel], source.rawValue)

            try await initiateImport(of: [dataType], fromFile: dataType == .passwords ? .testCSV : .testHTML, resultingWith: [
                dataType: .success(.init(successful: 42, duplicate: 12, failed: 3)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .summary([dataType], isFileImport: true), summary: [.init(dataType, .success(.init(successful: 42, duplicate: 12, failed: 3)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // csv/html file import succeeds with 0 passwords/bookmarks imported -> summary
    @MainActor
    func testWhenFileImportSourceImportSucceedsWithNoDataFound_summaryShown() async throws {
        for source in Source.allCases where source.initialScreen.isFileImport {
            setupModel(with: source)

            guard case .fileImport(dataType: let dataType, summary: []) = model.screen else {
                XCTFail("\(source): unexpected initial screen: \(model.screen)")
                continue
            }

            XCTAssertEqual(model.selectedDataTypes, [dataType], source.rawValue)
            XCTAssertEqual(model.buttons, [.cancel], source.rawValue)

            try await initiateImport(of: [dataType], fromFile: dataType == .passwords ? .testCSV : .testHTML, resultingWith: [
                dataType: .success(.init(successful: 0, duplicate: 0, failed: 0)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .summary([dataType], isFileImport: true), summary: [.init(dataType, .success(.init(successful: 0, duplicate: 0, failed: 0)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // csv/html file import fails -> feedback
    @MainActor
    func testWhenFileImportSourceImportFails_feedbackScreenShown() async throws {
        for source in Source.allCases where source.initialScreen.isFileImport {
            setupModel(with: source)

            guard case .fileImport(dataType: let dataType, summary: []) = model.screen else {
                XCTFail("\(source): unexpected initial screen: \(model.screen)")
                continue
            }

            XCTAssertEqual(model.selectedDataTypes, [dataType], source.rawValue)
            XCTAssertEqual(model.buttons, [.cancel], source.rawValue)

            try await initiateImport(of: [dataType], fromFile: dataType == .passwords ? .testCSV : .testHTML, resultingWith: [
                dataType: .failure(Failure(dataType.importAction, .dataCorrupted)),
            ])

            let expectation = DataImportViewModel(importSource: source, screen: .feedback, summary: [.init(dataType, .failure(Failure(dataType.importAction, .dataCorrupted)))])
            XCTAssertEqual(model.description, expectation.description)
        }
    }

    // MARK: - File Import after failure (or nil result for a data type)

    // all possible import summaries for combining
    var bookmarksSummaries: [DataImportViewModel.DataTypeImportResult?] {
        // bookmarks import didn‘t happen (or skipped)
        [nil,
        // bookmarks import succeeded
        .init(.bookmarks, .success(.init(successful: 42, duplicate: 3, failed: 1))),
        // bookmarks import succeeded with no bookmarks imported
        .init(.bookmarks, .success(.init(successful: 0, duplicate: 0, failed: 0))),
        // bookmarks import failed with error
        .init(.bookmarks, .failure(Failure(.bookmarks, .dataCorrupted))),
        // bookmarks import failed with file not found
        bookmarkSummaryNoData]
    }

    private let bookmarkSummaryNoData: DataImportViewModel.DataTypeImportResult? = .init(.bookmarks, .failure(Failure(.bookmarks, .noData)))

    let bookmarksResults: [DataImportResult<DataTypeSummary>?] = [
        .failure(Failure(.bookmarks, .dataCorrupted)),
        .success(.init(successful: 5, duplicate: 4, failed: 3)),
        .success(.init(successful: 0, duplicate: 0, failed: 0)),
        nil, // skip
    ]

    var passwordsSummaries: [DataImportViewModel.DataTypeImportResult?] {
        // passwords import didn‘t happen (or skipped)
        [nil,
        // passwords import succeeded
        .init(.passwords, .success(.init(successful: 99, duplicate: 4, failed: 2))),
        // passwords import succeeded with no passwords imported
        .init(.passwords, .success(.init(successful: 0, duplicate: 0, failed: 0))),
        // passwords import failed with error
        .init(.passwords, .failure(Failure(.passwords, .keychainError))),
        // passwords import failed with file not found
        passwordSummaryNoData]
    }

    private let passwordSummaryNoData: DataImportViewModel.DataTypeImportResult? = .init(.passwords, .failure(Failure(.passwords, .noData)))

    let passwordsResults: [DataImportResult<DataTypeSummary>?] = [
        .failure(Failure(.passwords, .dataCorrupted)),
        .success(.init(successful: 6, duplicate: 3, failed: 1)),
        .success(.init(successful: 0, duplicate: 0, failed: 0)),
        nil, // skip
    ]

    @MainActor
    func testWhenBrowsersBookmarksFileImportSucceedsAndNoPasswordsFileImportNeeded_summaryShown() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker && source.supportedDataTypes.contains(.passwords) {
            for bookmarksSummary in bookmarksSummaries
            // initial bookmark import failed or ended with empty result
            where bookmarksSummary?.result.isSuccess == false || (try? bookmarksSummary?.result.get())?.isEmpty == true {

                for passwordsSummary in passwordsSummaries
                // passwords successfully imported
                where (try? passwordsSummary?.result.get().isEmpty) == false {

                    for result in bookmarksResults
                    // bookmarks file import successful (incl. empty), or skipped when initial result was empty
                    where result?.isSuccess == true || (result == nil && (try? bookmarksSummary?.result.get())?.isEmpty == true) {

                        // setup model with pre-failed bookmarks import
                        setupModel(with: source,
                                   profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2],
                                   screen: .fileImport(dataType: .bookmarks, summary: []),
                                   summary: [bookmarksSummary, passwordsSummary].compactMap { $0 })
                        var xctDescr = "bookmarksSummary: \(bookmarksSummary?.description ?? "<nil>") passwordsSummary: \(passwordsSummary?.description ?? "<nil>") result: \(result?.description ?? ".skip")"

                        // run File Import
                        let expectation: DataImportViewModel
                        if let result {
                            try await initiateImport(of: [.bookmarks], fromFile: .testHTML, resultingWith: [.bookmarks: result], xctDescr)
                            // expect Final Summary
                            expectation = DataImportViewModel(importSource: source, screen: .summary([.bookmarks], isFileImport: true), summary: [bookmarksSummary, passwordsSummary, .init(.bookmarks, result)].compactMap { $0 })

                            xctDescr = "\(source): " + xctDescr

                            XCTAssertEqual(model.description, expectation.description, xctDescr)
                            XCTAssertEqual(model.actionButton, .next(.shortcuts([.bookmarks])), xctDescr)
                            XCTAssertNil(model.secondaryButton, xctDescr)
                        }
                    }
                }
            }
        }
    }

    @MainActor
    func testWhenBrowsersOnlySelectedBookmarksFileImportSucceeds_summaryShown() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            for bookmarksSummary in bookmarksSummaries
            // initial bookmark import failed or ended with empty result
            where bookmarksSummary?.result.isSuccess == false || (try? bookmarksSummary?.result.get())?.isEmpty == true {

                for result in bookmarksResults
                // bookmarks file import successful (incl. empty)
                where result?.isSuccess == true {

                    // setup model with pre-failed bookmarks import
                    setupModel(with: source,
                               profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2],
                               screen: .fileImport(dataType: .bookmarks, summary: []),
                               summary: [bookmarksSummary].compactMap { $0 })

                    if source.supportedDataTypes.contains(.passwords) {
                        model.selectedDataTypes = [.bookmarks]
                    }

                    var xctDescr = "bookmarksSummary: \(bookmarksSummary?.description ?? "<nil>") result: \(result?.description ?? ".skip")"

                    // run File Import
                    try await initiateImport(of: [.bookmarks], fromFile: .testHTML, resultingWith: [.bookmarks: result!], xctDescr)

                    xctDescr = "\(source): " + xctDescr

                    // expect Final Summary
                    let expectation = DataImportViewModel(importSource: source, screen: .summary([.bookmarks], isFileImport: true), summary: [bookmarksSummary, result.map { .init(.bookmarks, $0) }].compactMap { $0 })
                    XCTAssertEqual(model.description, expectation.description, xctDescr)
                    XCTAssertEqual(model.actionButton, .next(.shortcuts([.bookmarks])), xctDescr)
                    XCTAssertNil(model.secondaryButton, xctDescr)
                }
            }
        }
    }

    @MainActor
    func testWhenBrowsersBookmarksFileImportFailsAndNoPasswordsFileImportNeeded_feedbackShown() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker && source.supportedDataTypes.contains(.passwords) {
            for bookmarksSummary in bookmarksSummaries
            // initial bookmark import failed and is not a `noData` error, or empty
            where (bookmarksSummary?.result.isSuccess == false && bookmarkSummaryNoData != bookmarksSummary)
            || (try? bookmarksSummary?.result.get())?.isEmpty == true {

                for passwordsSummary in passwordsSummaries
                // passwords successfully imported
                where (try? passwordsSummary?.result.get().isEmpty) == false {

                    for result in bookmarksResults
                    // bookmarks file import failed or skipped when initial result was a failure
                    where result?.isSuccess == false || (result == nil && bookmarksSummary?.result.isSuccess == false) {

                        // setup model with pre-failed bookmarks import
                        setupModel(with: source,
                                   profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2],
                                   screen: .fileImport(dataType: .bookmarks, summary: []),
                                   summary: [bookmarksSummary, passwordsSummary].compactMap { $0 })
                        var xctDescr = "bookmarksSummary: \(bookmarksSummary?.description ?? "<nil>") passwordsSummary: \(passwordsSummary?.description ?? "<nil>") result: \(result?.description ?? ".skip")"

                        // run File Import (or skip)
                        if let result {
                            try await initiateImport(of: [.bookmarks], fromFile: .testHTML, resultingWith: [.bookmarks: result], xctDescr)
                        } else {
                            XCTAssertEqual(model.actionButton, .skip)
                            model.performAction(.skip)
                        }

                        xctDescr = "\(source): " + xctDescr

                        // expect Report Feedback
                        let expectation = DataImportViewModel(importSource: source, screen: .feedback, summary: [bookmarksSummary, passwordsSummary, result.map { .init(.bookmarks, $0) }].compactMap { $0 })
                        XCTAssertEqual(model.description, expectation.description, xctDescr)
                        XCTAssertEqual(model.actionButton, .submit, xctDescr)
                        XCTAssertEqual(model.secondaryButton, .cancel, xctDescr)
                    }
                }
            }
        }
    }

    @MainActor
    func testWhenBrowsersBookmarksImportFailsNoDataAndFileImportSkippedAndNoPasswordsFileImportNeeded_shortcutsShown() throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker && source.supportedDataTypes.contains(.passwords) {

            let bookmarksSummary = bookmarkSummaryNoData

            for passwordsSummary in passwordsSummaries
            // passwords successfully imported
            where (try? passwordsSummary?.result.get().isEmpty) == false {

                // setup model with pre-failed bookmarks import
                setupModel(with: source,
                           profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2],
                           screen: .fileImport(dataType: .bookmarks, summary: []),
                           summary: [bookmarksSummary, passwordsSummary].compactMap { $0 })

                model.performAction(for: .skip) {}

                XCTAssertEqual(model.screen, .shortcuts([.passwords]))
            }
        }
    }

    @MainActor
    func testWhenBrowsersOnlySelectedBookmarksFileImportFails_feedbackShown() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            for bookmarksSummary in bookmarksSummaries
            // initial bookmark import failed or ended with empty result
            where bookmarksSummary?.result.isSuccess == false || (try? bookmarksSummary?.result.get())?.isEmpty == true {

                for result in bookmarksResults
                // bookmarks file import successful (incl. empty)
                where result?.isSuccess == false {

                    // setup model with pre-failed bookmarks import
                    setupModel(with: source,
                               profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2],
                               screen: .fileImport(dataType: .bookmarks, summary: []),
                               summary: [bookmarksSummary].compactMap { $0 })

                    if source.supportedDataTypes.contains(.passwords) {
                        model.selectedDataTypes = [.bookmarks]
                    }

                    var xctDescr = "bookmarksSummary: \(bookmarksSummary?.description ?? "<nil>") result: \(result?.description ?? ".skip")"

                    // run File Import
                    try await initiateImport(of: [.bookmarks], fromFile: .testHTML, resultingWith: [.bookmarks: result!], xctDescr)

                    xctDescr = "\(source): " + xctDescr

                    // expect Report Feedback
                    let expectation = DataImportViewModel(importSource: source, screen: .feedback, summary: [bookmarksSummary, result.map { .init(.bookmarks, $0) }].compactMap { $0 })
                    XCTAssertEqual(model.description, expectation.description, xctDescr)
                    XCTAssertEqual(model.actionButton, .submit, xctDescr)
                    XCTAssertEqual(model.secondaryButton, .cancel, xctDescr)
                }
            }
        }
    }

    @MainActor
    func testWhenBrowsersBookmarksFileImportFailsAndPasswordsFileImportIsNeeded_bookmarksSummaryWithNextButtonShown() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker && source.supportedDataTypes.contains(.passwords) {
            for bookmarksSummary in bookmarksSummaries
            // initial bookmark import failed or ended with empty result
            where bookmarksSummary?.result.isSuccess == false || (try? bookmarksSummary?.result.get())?.isEmpty == true {

                for passwordsSummary in passwordsSummaries
                // passwords failed to import, not imported or empty data
                where passwordsSummary?.result.isSuccess != true || (try? passwordsSummary?.result.get().isEmpty) == true {

                    for result in bookmarksResults
                    // any bookmarks file import result except Skip
                    where result != nil {

                        // setup model with pre-failed bookmarks import
                        setupModel(with: source,
                                   profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2],
                                   screen: .fileImport(dataType: .bookmarks, summary: []),
                                   summary: [bookmarksSummary, passwordsSummary].compactMap { $0 })
                        var xctDescr = "bookmarksSummary: \(bookmarksSummary?.description ?? "<nil>") passwordsSummary: \(passwordsSummary?.description ?? "<nil>") result: \(result?.description ?? ".skip")"

                        // run File Import (or skip)
                        try await initiateImport(of: [.bookmarks], fromFile: .testHTML, resultingWith: [.bookmarks: result!], xctDescr)

                        xctDescr = "\(source): " + xctDescr

                        // expect Bookmarks Import Summary screen
                        let expectation = DataImportViewModel(importSource: source, screen: .summary([.bookmarks], isFileImport: true), summary: [bookmarksSummary, passwordsSummary, result.map { .init(.bookmarks, $0) }].compactMap { $0 })
                        XCTAssertEqual(model.description, expectation.description, xctDescr)
                        // [Next] -> passwords file import screen
                        XCTAssertEqual(model.actionButton, .next(.fileImport(dataType: .passwords)), xctDescr)
                        XCTAssertNil(model.secondaryButton, xctDescr)
                    }
                }
            }
        }
    }

    @MainActor
    func testWhenBrowsersBookmarksFileImportSkippedAndPasswordsFileImportIsNeeded_passwordsFileImportShown() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker && source.supportedDataTypes.contains(.passwords) {
            for bookmarksSummary in bookmarksSummaries
            // initial bookmark import failed or ended with empty result
            where bookmarksSummary?.result.isSuccess == false || (try? bookmarksSummary?.result.get())?.isEmpty == true {

                for passwordsSummary in passwordsSummaries
                // passwords failed to import, not imported or empty data
                where passwordsSummary?.result.isSuccess != true || (try? passwordsSummary?.result.get().isEmpty) == true {

                    // setup model with pre-failed bookmarks import
                    setupModel(with: source,
                               profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2],
                               screen: .fileImport(dataType: .bookmarks, summary: []),
                               summary: [bookmarksSummary, passwordsSummary].compactMap { $0 })
                    var xctDescr = "bookmarksSummary: \(bookmarksSummary?.description ?? "<nil>") passwordsSummary: \(passwordsSummary?.description ?? "<nil>")"

                    // skip Bookmarks file import
                    XCTAssertEqual(model.actionButton, .skip)
                    model.performAction(.skip)

                    xctDescr = "\(source): " + xctDescr

                    // expect Bookmarks Import Summary screen
                    let expectation = DataImportViewModel(importSource: source, screen: .fileImport(dataType: .passwords), summary: [bookmarksSummary, passwordsSummary].compactMap { $0 })
                    XCTAssertEqual(model.description, expectation.description, xctDescr)
                    // if no failures: Cancel button is shown
                    if bookmarksSummary?.result.isSuccess != false && passwordsSummary?.result.isSuccess != false {
                        XCTAssertEqual(model.actionButton, .cancel, xctDescr)
                    } else {
                        XCTAssertEqual(model.actionButton, .skip, xctDescr)
                    }
                    XCTAssertNil(model.secondaryButton, xctDescr)
                }
            }
        }
    }

    // MARK: File import after passwords failure

    @MainActor
    func testWhenBrowsersPasswordsFileImportSucceeds_summaryShown() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker && source.supportedDataTypes.contains(.passwords) {
            for bookmarksSummary in bookmarksSummaries {

                for passwordsSummary in passwordsSummaries
                // passwords import failed or empty
                where passwordsSummary?.result.isSuccess == false || (try? passwordsSummary?.result.get().isEmpty) == false {

                    for bookmarksFileImportSummary in bookmarksSummaries
                    // if bookmarks result was failure - append successful bookmarks file import result
                    where (bookmarksSummary?.result.isSuccess == false && bookmarksFileImportSummary?.result.isSuccess == true)
                    // if bookmarks file import summary was successful and non empty - don‘t append bookmarks file import result
                    // or if bookmarks file import was empty - and bookmarks file import skipped
                    || (bookmarksSummary?.result.isSuccess == true && bookmarksFileImportSummary == nil) {

                        for result in passwordsResults
                        // passwords file import successful (incl. empty), or skipped when initial result was empty
                        where result?.isSuccess == true || (result == nil && (try? passwordsSummary?.result.get())?.isEmpty == true) {

                            // setup model with pre-failed passwords import
                            setupModel(with: source,
                                       profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2],
                                       screen: .fileImport(dataType: .passwords, summary: []),
                                       summary: [bookmarksSummary, passwordsSummary, bookmarksFileImportSummary].compactMap { $0 })
                            var xctDescr = "bookmarksSummary: \(bookmarksSummary?.description ?? "<nil>") passwordsSummary: \(passwordsSummary?.description ?? "<nil>"), bookmarksFileSummary: \(bookmarksFileImportSummary?.description ?? ".skip") result: \(result?.description ?? ".skip")"

                            // run File Import (or skip)
                            if let result {
                                try await initiateImport(of: [.passwords], fromFile: .testCSV, resultingWith: [.passwords: result], xctDescr)
                            } else {
                                XCTAssertEqual(model.actionButton, .skip)
                                model.performAction(.skip)
                            }

                            xctDescr = "\(source): " + xctDescr

                            // expect Final Summary
                            let expectation = DataImportViewModel(importSource: source, screen: .summary([.passwords], isFileImport: true), summary: [bookmarksSummary, passwordsSummary, bookmarksFileImportSummary, result.map { .init(.passwords, $0) }].compactMap { $0 })
                            XCTAssertEqual(model.description, expectation.description, xctDescr)
                            XCTAssertEqual(model.actionButton, .next(.shortcuts([.passwords])), xctDescr)
                            XCTAssertNil(model.secondaryButton, xctDescr)
                        }
                    }
                }
            }
        }
    }

    @MainActor
    func testWhenBrowsersOnlySelectedPasswordsFileImportSucceeds_summaryShown() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker && source.supportedDataTypes.contains(.passwords) {
            for passwordsSummary in passwordsSummaries
            // initial passwords import failed or ended with empty result
            where passwordsSummary?.result.isSuccess == false || (try? passwordsSummary?.result.get())?.isEmpty == true {

                for result in passwordsResults
                // passwords file import successful (incl. empty)
                where result?.isSuccess == true {

                    // setup model with pre-failed bookmarks import
                    setupModel(with: source,
                               profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2],
                               screen: .fileImport(dataType: .passwords, summary: []),
                               summary: [passwordsSummary].compactMap { $0 })

                    model.selectedDataTypes = [.passwords]

                    var xctDescr = "passwordsSummary: \(passwordsSummary?.description ?? "<nil>") result: \(result?.description ?? ".skip")"

                    // run File Import
                    try await initiateImport(of: [.passwords], fromFile: .testCSV, resultingWith: [.passwords: result!], xctDescr)

                    xctDescr = "\(source): " + xctDescr

                    // expect Final Summary
                    let expectation = DataImportViewModel(importSource: source, screen: .summary([.passwords], isFileImport: true), summary: [passwordsSummary, result.map { .init(.passwords, $0) }].compactMap { $0 })
                    XCTAssertEqual(model.description, expectation.description, xctDescr)
                    XCTAssertEqual(model.actionButton, .next(.shortcuts([.passwords])), xctDescr)
                    XCTAssertNil(model.secondaryButton, xctDescr)
                }
            }
        }
    }

    @MainActor
    func testWhenBrowsersPasswordsFileImportFails_feedbackShown() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker && source.supportedDataTypes.contains(.passwords) {
            for bookmarksSummary in bookmarksSummaries {

                for passwordsSummary in passwordsSummaries
                // passwords import failed and is not a `noData` error, or empty
                where (passwordsSummary?.result.isSuccess == false && passwordSummaryNoData != passwordsSummary)
                || (try? passwordsSummary?.result.get().isEmpty) == false {

                    for bookmarksFileImportSummary in bookmarksSummaries
                    // if bookmarks result was failure - append successful bookmarks file import result
                    where (bookmarksSummary?.result.isSuccess == false && bookmarksFileImportSummary?.result.isSuccess == true)
                    // if bookmarks file import summary was successful and non empty - don‘t append bookmarks file import result
                    // or if bookmarks file import was empty - and bookmarks file import skipped
                    || (bookmarksSummary?.result.isSuccess == true && bookmarksFileImportSummary == nil) {

                        for result in passwordsResults
                        // passwords file import failed or skipped when initial result was a failure
                        where result?.isSuccess == false || (result == nil && passwordsSummary?.result.isSuccess == false) {

                            // setup model with pre-failed passwords import
                            setupModel(with: source,
                                       profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2],
                                       screen: .fileImport(dataType: .passwords, summary: []),
                                       summary: [bookmarksSummary, passwordsSummary, bookmarksFileImportSummary].compactMap { $0 })
                            var xctDescr = "bookmarksSummary: \(bookmarksSummary?.description ?? "<nil>") passwordsSummary: \(passwordsSummary?.description ?? "<nil>"), bookmarksFileSummary: \(bookmarksFileImportSummary?.description ?? ".skip") result: \(result?.description ?? ".skip")"

                            // run File Import (or skip)
                            if let result {
                                try await initiateImport(of: [.passwords], fromFile: .testCSV, resultingWith: [.passwords: result], xctDescr)
                            } else {
                                XCTAssertEqual(model.actionButton, .skip)
                                model.performAction(.skip)
                            }

                            xctDescr = "\(source): " + xctDescr

                            // expect Report Feedback
                            let expectation = DataImportViewModel(importSource: source, screen: .feedback, summary: [bookmarksSummary, passwordsSummary, bookmarksFileImportSummary, result.map { .init(.passwords, $0) }].compactMap { $0 })
                            XCTAssertEqual(model.description, expectation.description, xctDescr)
                            XCTAssertEqual(model.actionButton, .submit, xctDescr)
                            XCTAssertEqual(model.secondaryButton, .cancel, xctDescr)
                        }
                    }
                }
            }
        }
    }

    @MainActor
    func testWhenBrowsersPasswordsImportFailNoDataAndFileImportSkipped_dialogDismissedOrShortcutsShown() throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker && source.supportedDataTypes.contains(.passwords) {
            for bookmarksSummary in bookmarksSummaries {

                let passwordsSummary = passwordSummaryNoData

                for bookmarksFileImportSummary in bookmarksSummaries
                // if bookmarks result was failure - append successful bookmarks file import result
                where (bookmarksSummary?.result.isSuccess == false && bookmarksFileImportSummary?.result.isSuccess == true)
                // if bookmarks file import summary was successful and non empty - don‘t append bookmarks file import result
                // or if bookmarks file import was empty - and bookmarks file import skipped
                || (bookmarksSummary?.result.isSuccess == true && bookmarksFileImportSummary == nil) {

                    // setup model with pre-failed passwords import
                    setupModel(with: source,
                               profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2],
                               screen: .fileImport(dataType: .passwords, summary: []),
                               summary: [bookmarksSummary, passwordsSummary, bookmarksFileImportSummary].compactMap { $0 })

                    if let result = bookmarksSummary?.result as? DataImportResult<DataTypeSummary>, result.isSuccess, let successful = try? result.get().successful, successful > 0 {
                        model.performAction(for: .skip) {}
                        XCTAssertEqual(model.screen, .shortcuts([.bookmarks]))
                    } else if let result = bookmarksFileImportSummary?.result as? DataImportResult<DataTypeSummary>, result.isSuccess, let successful = try? result.get().successful, successful > 0 {
                        model.performAction(for: .skip) {}
                        XCTAssertEqual(model.screen, .shortcuts([.bookmarks]))
                    } else {
                        let expectation = expectation(description: "dismissed")
                        model.performAction(for: .skip) {
                            expectation.fulfill()
                        }
                        waitForExpectations(timeout: 0)
                    }
                }
            }
        }
    }

    @MainActor
    func testWhenBrowsersOnlySelectedPasswordsFileImportFails_feedbackShown() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker && source.supportedDataTypes.contains(.passwords) {
            for passwordsSummary in passwordsSummaries
            // initial passwords import failed or ended with empty result
            where passwordsSummary?.result.isSuccess == false || (try? passwordsSummary?.result.get())?.isEmpty == true {

                for result in passwordsResults
                // passwords file import failed
                where result?.isSuccess == false {

                    // setup model with pre-failed bookmarks import
                    setupModel(with: source,
                               profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2],
                               screen: .fileImport(dataType: .passwords, summary: []),
                               summary: [passwordsSummary].compactMap { $0 })

                    model.selectedDataTypes = [.passwords]

                    var xctDescr = "passwordsSummary: \(passwordsSummary?.description ?? "<nil>") result: \(result?.description ?? ".skip")"

                    // run File Import
                    try await initiateImport(of: [.passwords], fromFile: .testCSV, resultingWith: [.passwords: result!], xctDescr)

                    xctDescr = "\(source): " + xctDescr

                    // expect Report Feedback
                    let expectation = DataImportViewModel(importSource: source, screen: .feedback, summary: [passwordsSummary, result.map { .init(.passwords, $0) }].compactMap { $0 })
                    XCTAssertEqual(model.description, expectation.description, xctDescr)
                    XCTAssertEqual(model.actionButton, .submit, xctDescr)
                    XCTAssertEqual(model.secondaryButton, .cancel, xctDescr)
                }
            }
        }
    }

    // MARK: - Feedback

    @MainActor
    func testFeedbackSending() {
        NSError.disableSwizzledDescription = true

        let summary: [DataImportViewModel.DataTypeImportResult] = [
            .init(.bookmarks, .success(.empty)),
            .init(.bookmarks, .failure(Failure(.passwords, .dataCorrupted))),
            .init(.passwords, .failure(Failure(.passwords, .keychainError))),
            .init(.passwords, .failure(Failure(.passwords, .dataCorrupted)))
        ]
        let e = expectation(description: "report sent")
        model = DataImportViewModel(importSource: .safari, screen: .feedback, summary: summary, reportSenderFactory: {
            { report in
                XCTAssertEqual(report.text, "Test text")
                for dataTypeSummary in summary {
                    if case .failure(let error) = dataTypeSummary.result {
                        XCTAssertTrue(report.error.localizedDescription.contains(error.localizedDescription))
                    }
                }
                XCTAssertEqual(report.importSourceDescription, Source.safari.importSourceName + " " + "\(SafariVersionReader.getMajorVersion() ?? 0)")
                XCTAssertEqual(report.appVersion, "\(AppVersion.shared.versionNumber)")
                XCTAssertEqual(report.osVersion, "\(ProcessInfo.processInfo.operatingSystemVersion)")
                XCTAssertEqual(report.retryNumber, 2)
                XCTAssertEqual(report.importSource, .safari)

                e.fulfill()
            }
        })

        XCTAssertEqual(model.buttons, [.cancel, .submit])

        model.reportModel.text = "Test text"

        let eDismissed = expectation(description: "dismissed")
        model.performAction(for: .submit) {
            eDismissed.fulfill()
        }
        waitForExpectations(timeout: 0)
    }

    // MARK: - Helpers

    var openPanelCallback: ((DataType) -> URL?)?

    func setupModel(with source: Source, profiles: [(ThirdPartyBrowser) -> BrowserProfile] = [], screen: DataImportViewModel.Screen? = nil, summary: [DataImportViewModel.DataTypeImportResult] = [], dataImporterFactory: DataImportViewModel.DataImporterFactory? = nil, requestPrimaryPasswordCallback: ((DataImportViewModel.Source) -> String?)? = nil) {
        model = DataImportViewModel(importSource: source, screen: screen, summary: summary, loadProfiles: { browser in
                .init(browser: browser, profiles: profiles.map { $0(browser) }) { _ in
                    { // swiftlint:disable:this opening_brace
                        .init(logins: .available, bookmarks: .available)
                    }
                }
        }, dataImporterFactory: dataImporterFactory ?? self.dataImporter, requestPrimaryPasswordCallback: requestPrimaryPasswordCallback ?? { _ in nil }, openPanelCallback: { self.openPanelCallback!($0) })
    }

    func selectProfile(_ profile: BrowserProfile, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(model.browserProfiles?.validImportableProfiles.contains(profile) == true, message().with("profile not available"), file: file, line: line)
        model.selectedProfile = profile
    }

    private func dataImporter(for source: DataImport.Source, fileDataType: DataImport.DataType?, url: URL, primaryPassword: String?) -> DataImporter {
        XCTAssertEqual(source, model.importSource)
        if case .fileImport(let dataType, summary: _) = model.screen {
            XCTAssertEqual(dataType, fileDataType)
        } else {
            XCTAssertNil(fileDataType)
            XCTAssertEqual(url, model.selectedProfile?.profileURL)
        }

        return ImporterMock(password: primaryPassword, importTask: self.importTask)
    }

    private var importTask: ((Set<DataImport.DataType>, DataImportProgressCallback) async -> DataImportSummary)!

    @MainActor
    func initiateImport(of dataTypes: Set<DataType>, from profile: BrowserProfile? = nil, fromFile url: URL? = nil, resultingWith result: DataImportSummary? = nil, file: StaticString = #filePath, line: UInt = #line, _ descr: String? = nil, progress progressUpdateCallback: ((DataImportProgressEvent) -> Void)? = nil) async throws {
        assert((profile != nil) != (url != nil), "must provide either profile or url")

        let source = model.importSource
        let message: () -> String = { "\(source): \(profile?.profileName ?? url!.path)".with(descr) }

        if [.profileAndDataTypesPicker, .moreInfo].contains(model.screen) {
            for dataType in DataType.allCases where model.selectedDataTypes.contains(dataType) != dataTypes.contains(dataType) {
                model.setDataType(dataType, selected: dataTypes.contains(dataType))
            }
            XCTAssertEqual(model.selectedDataTypes, dataTypes, message().with("selectedDataTypes"), file: file, line: line)

            if let profile {
                selectProfile(profile, message(), file: file, line: line)
            }
        } else {
            XCTAssertNil(profile, message().with("profile"), file: file, line: line)
        }

        if let result {
            self.importTask = { _, _ in result }
        }

        var model: DataImportViewModel = self.model
        if let url { // file import
            XCTAssertEqual(dataTypes.count, 1, message().with("actionButton"), file: file, line: line)
            if !source.isBrowser {
                XCTAssertNil(model.actionButton)
            } else if model.selectedDataTypes.isDisjoint(with: DataType.dataTypes(after: dataTypes.first!)),
                      model.summary(for: dataTypes.first!)?.isEmpty == true {
                // no more data types available and import result is .success(.empty)
                XCTAssertEqual(model.actionButton, .cancel, message().with("actionButton"), file: file, line: line)
            } else if model.selectedDataTypes.isDisjoint(with: DataType.dataTypes(after: dataTypes.first!)),
                      !model.summary.contains(where: { $0.result.isSuccess == false }) {
                // when no errors collected before - Cancel would be shown instead of Skip for Passwords Import
                XCTAssertEqual(model.actionButton, .cancel)
            } else if case .profileAndDataTypesPicker = model.importSource.initialScreen {
                XCTAssertEqual(model.actionButton, .skip, message().with("actionButton"), file: file, line: line)
            }

            if openPanelCallback == nil {
                openPanelCallback = { dataType in
                    XCTAssertEqual(dataType, dataTypes.first!, message().with("file import dataType"), file: file, line: line)
                    self.openPanelCallback = nil
                    return url
                }
            }
            model.selectFile()

        } else {
            XCTAssertEqual(model.actionButton, .initiateImport(disabled: false), message().with("actionButton"), file: file, line: line)
            model.performAction(.initiateImport(disabled: false))
        }
        self.model = model

        while let importProgress = self.model.importProgress {
            let taskStarted = expectation(description: "import task started")
            let taskCompleted = expectation(description: "import task completed")

            let task = Task<DataImportViewModel?, Never> {
                taskStarted.fulfill()

                for await event in importProgress {
                    switch event {
                    case .progress(let progressEvent):
                        progressUpdateCallback?(progressEvent)
                    case .completed(.success(let newModel)):
                        taskCompleted.fulfill()

                        return newModel
                    }
                }
                return nil
            }

            await Task.yield()
            self.model = try await task.value ?? { throw CancellationError() }()
            await fulfillment(of: [taskStarted, taskCompleted], timeout: 0.0)
        }
    }

}

private extension DataImport.BrowserProfile {
    static func test(for browser: ThirdPartyBrowser) -> Self {
        .init(browser: browser, profileURL: .profile(named: "Test Profile"))
    }
    static func test2(for browser: ThirdPartyBrowser) -> Self {
        .init(browser: browser, profileURL: .profile(named: "Test Profile 2"))
    }
    static func test3(for browser: ThirdPartyBrowser) -> Self {
        .init(browser: browser, profileURL: .profile(named: "Test Profile 3"))
    }
    static func `default`(for browser: ThirdPartyBrowser) -> Self {
        switch browser {
        case .firefox, .tor:
            .init(browser: browser, profileURL: .profile(named: DataImport.BrowserProfileList.Constants.firefoxDefaultProfileName))
        default:
            .init(browser: browser, profileURL: .profile(named: DataImport.BrowserProfileList.Constants.chromiumDefaultProfileName))
        }

    }
}

private struct Failure: DataImportError, CustomStringConvertible {

    enum OperationType: Int {
        case failure
    }

    var action: DataImportAction
    var type: OperationType = .failure

    var underlyingError: Error?

    var errorType: DataImport.ErrorType = .other

    init(_ action: DataImportAction, _ errorType: DataImport.ErrorType) {
        self.action = action
        self.errorType = errorType
    }

    var description: String {
        "Failure(.\(action.rawValue), .\(errorType))"
    }

}

private class ImporterMock: DataImporter {

    var password: String?

    var importableTypes: [DataImport.DataType]

    var keychainPasswordRequiredFor: Set<DataImport.DataType>

    init(password: String? = nil, importableTypes: [DataImport.DataType] = [.bookmarks, .passwords], keychainPasswordRequiredFor: Set<DataImport.DataType> = [], accessValidator: ((ImporterMock, Set<DataImport.DataType>) -> [DataImport.DataType: any DataImportError]?)? = nil, importTask: ((Set<DataImport.DataType>, DataImportProgressCallback) async -> DataImportSummary)? = nil) {
        self.password = password
        self.importableTypes = importableTypes
        self.keychainPasswordRequiredFor = keychainPasswordRequiredFor
        self.accessValidator = accessValidator
        self.importTask = importTask
    }
    func requiresKeychainPassword(for selectedDataTypes: Set<DataImport.DataType>) -> Bool {
        selectedDataTypes.intersects(keychainPasswordRequiredFor)
    }

    var accessValidator: ((ImporterMock, Set<DataImport.DataType>) -> [DataImport.DataType: any DataImportError]?)?

    func validateAccess(for types: Set<DataImport.DataType>) -> [DataImport.DataType: any DataImportError]? {
        accessValidator?(self, types)
    }

    var importTask: ((Set<DataImport.DataType>, DataImportProgressCallback) async -> DataImportSummary)?

    func importData(types: Set<DataImport.DataType>) -> DataImportTask {
        .detachedWithProgress { [importTask=importTask!]updateProgress in
            await importTask(types, updateProgress)
        }
    }

}

extension DataImportViewModel {
    @MainActor mutating func performAction(_ buttonType: ButtonType) {
        performAction(for: buttonType, dismiss: { assertionFailure("Unexpected dismiss") })
    }
}

extension DataImportViewModel: CustomStringConvertible {
    public var description: String {
        "DataImportViewModel(importSource: .\(importSource.rawValue), screen: \(screen)\(!summary.isEmpty ? ", summary: \(summary)" : ""))"
    }
}

extension DataImportViewModel.Screen: CustomStringConvertible {
    public var description: String {
        switch self {
        case .profileAndDataTypesPicker: ".profileAndDataTypesPicker"
        case .moreInfo: ".moreInfo"
        case .getReadPermission(let url): "getReadPermission(\(url.path))"
        case .fileImport(dataType: let dataType, summary: let summaryDataTypes): ".fileImport(dataType: .\(dataType)\(!summaryDataTypes.isEmpty ? ", summary: [\(summaryDataTypes.map { "." + $0.rawValue }.sorted().joined(separator: ", "))]" : ""))"
        case .summary(let dataTypes, isFileImport: false):
            ".summary([\(dataTypes.map { "." + $0.rawValue }.sorted().joined(separator: ", "))])"
        case .summary(let dataTypes, isFileImport: true):
            ".summary([\(dataTypes.map { "." + $0.rawValue }.sorted().joined(separator: ", "))], isFileImport: true)"
        case .feedback: ".feedback"
        case .shortcuts: ".shortcuts"
        }
    }
}

extension DataImportViewModel.ButtonType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .next(let screen): ".next(\(screen))"
        case .initiateImport(disabled: let disabled): ".initiateImport\(disabled ? "(disabled)" : "")"
        case .skip: ".skip"
        case .cancel: ".cancel"
        case .back: ".back"
        case .done: ".done"
        case .submit: ".submit"
        }
    }
}

extension DataImportViewModel.DataTypeImportResult: CustomStringConvertible {
    public var description: String {
        ".init(.\(dataType), \(result))"
    }
}

extension DataImport.DataTypeSummary: CustomStringConvertible {
    public var description: String {
        ".init(successful: \(successful), duplicate: \(duplicate), failed: \(failed))"
    }
}

private extension String {
    func with(_ addition: String?) -> String {
        guard !self.isEmpty else { return addition ?? ""}
        guard let addition, !addition.isEmpty else { return self }
        return self + " - " + addition
    }
}

private extension URL {
    static let mockURL = URL(fileURLWithPath: "/Users/Dax/Library/ApplicationSupport/BrowserCompany/Browser/")

    static let testCSV = URL(fileURLWithPath: "/Users/Dax/Downloads/passwords.csv")
    static let testHTML = URL(fileURLWithPath: "/Users/Dax/Downloads/bookmarks.html")

    static func profile(named name: String) -> URL {
        return mockURL.appendingPathComponent(name)
    }
}
