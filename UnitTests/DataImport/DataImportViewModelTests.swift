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

@MainActor
final class DataImportViewModelTests: XCTestCase {

    typealias Source = DataImport.Source
    typealias BrowserProfileList = DataImport.BrowserProfileList
    typealias BrowserProfile = DataImport.BrowserProfile
    typealias DataType = DataImport.DataType

    var model: DataImportViewModel!

    override func setUp() {
        model = nil
        importTask = nil

        // TODO: remove me
        OSLog.loggingCategories.insert(OSLog.AppCategories.dataImportExport.rawValue)
    }

    func setupModel(with source: Source, profiles: [(ThirdPartyBrowser) -> BrowserProfile], screen: DataImportViewModel.Screen? = nil, summary: DataImportViewModel.DataImportViewSummary = .init()) {
        model = DataImportViewModel(importSource: source, screen: screen, summary: summary, loadProfiles: { browser in
            .init(browser: browser, profiles: profiles.map { $0(browser) }) { profile in
                {
                    // TODO: unavailability; test invalid profiles
                    .init(logins: .available, bookmarks: .available)
                }
            }
        }, dataImporterFactory: dataImporter)
    }

    func selectProfile(_ profile: BrowserProfile, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(model.browserProfiles?.validImportableProfiles.contains(profile) == true, message().with("profile"), file: file, line: line)
        model.selectedProfile = profile
    }

    func initiateImport(of dataTypes: Set<DataType>, from profile: BrowserProfile? = nil, fromFile url: URL? = nil, resultingWith getResult: @escaping @autoclosure () -> DataImportSummary, file: StaticString = #filePath, line: UInt = #line, progress progressUpdateCallback: ((DataImportProgressEvent) -> Void)? = nil) async throws {
        assert((profile != nil) != (url != nil), "must provide either profile or url")

        let source = model.importSource
        let message: () -> String = { "\(source): \(profile?.profileName ?? url!.path)" }

        for dataType in DataType.allCases where model.selectedDataTypes.contains(dataType) != dataTypes.contains(dataType) {
            model.setDataType(dataType, selected: dataTypes.contains(dataType))
        }
        XCTAssertEqual(model.selectedDataTypes, dataTypes, message().with("selectedDataTypes"), file: file, line: line)

        if let profile {
            selectProfile(profile, message(), file: file, line: line)
        }

        self.importTask = { _ in getResult() }
// TODO: test cancel/back
        var model: DataImportViewModel = self.model
        if let url {
            XCTAssertEqual(model.actionButton, .initiateImport(disabled: true), message().with("actionButton"), file: file, line: line)
            model.initiateImport(fileURL: url)
        } else {
            XCTAssertEqual(model.actionButton, .initiateImport(disabled: false), message().with("actionButton"), file: file, line: line)
            model.performAction(.initiateImport(disabled: false))
        }
        self.model = model

        struct NoProgress: Error {}
        guard let importProgress = model.importProgress else { XCTAssertNotNil(model.importProgress, message().with("importProgress"), file: file, line: line); throw NoProgress() }

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

        await fulfillment(of: [taskStarted, taskCompleted], timeout: 0.5)

        self.model = try await task.value ?? { throw CancellationError() }()
    }

    func expect(_ screen: DataImportViewModel.Screen, actionButton: DataImportViewModel.ButtonType? = nil, secondaryButton: DataImportViewModel.ButtonType? = nil, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {

        XCTAssertEqual(model.screen, screen, message().with("screen"), file: file, line: line)
        XCTAssertEqual(model.actionButton, actionButton, message().with("actionButton"), file: file, line: line)
        XCTAssertEqual(model.secondaryButton, secondaryButton, message().with("secondaryButton"), file: file, line: line)
        XCTAssertNil(model.importProgress, message().with("importProgress"), file: file, line: line)

        // auto test cancel/back/done
        for button in Set([actionButton, secondaryButton]).intersection(model.buttons).compactMap({ $0 }) {
            var model = model!
            switch button {
            case .cancel, .done:
                let e = expectation(description: message().with("dismiss called"))
                model.performAction(for: button, dismiss: {
                    e.fulfill()
                })
                waitForExpectations(timeout: 0)

            case .back:
                let initialSource = model.importSource
                let initialProfiles = model.browserProfiles
                let initialProfile = model.selectedProfile
                let initialScreen = initialSource.initialScreen
                model.performAction(button)
                XCTAssertEqual(model.screen, initialScreen, message().with("Back - initialScreen"), file: file, line: line)
                XCTAssertEqual(model.browserProfiles?.profiles, initialProfiles?.profiles, message().with("Back - initialProfiles"), file: file, line: line)
                XCTAssertEqual(model.selectedProfile, initialProfile, message().with("Back - initialProfile"), file: file, line: line)
            case .submit:
                // TODO: test submit
                fatalError()
            default:
                break
            }
        }

        // TODO:
    }

    func testWhenBrowserPasswordsImportFails_manualImportSuggested() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])
// TODO: tor does not support passwords
            try await initiateImport(of: [.bookmarks, .passwords], from: .test(for: browser), resultingWith: [
                .bookmarks: .success(.init(successful: 10, duplicate: 0, failed: 0)),
                .passwords: .failure(MockImportError(action: .passwords, errorType: .decryptionError))
            ])

            expect(.error(dataType: .passwords, errorType: .decryptionError), actionButton: .manualImport, secondaryButton: .skip, "\(source)")
        }
    }

    func testWhenManualImportChosenForPasswords_csvFileImportScreenIsShown() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2], screen: .error(dataType: .passwords, errorType: .decryptionError), summary: [
                .init(.bookmarks, .success(.init(successful: 10, duplicate: 0, failed: 0))),
                .init(.passwords, .failure(MockImportError(action: .passwords, errorType: .decryptionError)))
            ])

            model.performAction(.manualImport)
            // TODO: tor does not support passwords
            expect(.fileImport(.passwords), actionButton: .skip, secondaryButton: .back, "\(source)")
        }
    }

//        try await testBranch {
//            try await initiateImport(of: [.passwords], fromFile: .testCSV, resultingWith: [
//                .passwords: .success(.init(successful: 1, duplicate: 2, failed: 42)) // TODO: failure alternative
//            ])
//            expect(.summary, actionButton: .done, secondaryButton: .done, "\(source) - Manual Import - Success")
//
//        } alternative: {
//            model.performAction(.skip)
//            expect(.summary, actionButton: .done, secondaryButton: .back, "\(source) - Manual Import - Skip")
//        }
//
//    } alternative: {
//        model.performAction(.skip)
//        expect(.summary, actionButton: .done, secondaryButton: .back, "\(source) - Skip")
//    }


    func testBrowserDataImport() async throws {
        for source in Source.allCases where source.initialScreen == .profileAndDataTypesPicker {
            guard let browser = ThirdPartyBrowser.browser(for: source) else {
                XCTFail("no ThirdPartyBrowser for \(source)")
                continue
            }

            setupModel(with: source, profiles: [BrowserProfile.test, BrowserProfile.default, BrowserProfile.test2])

            try await initiateImport(of: [.bookmarks, .passwords], from: .test(for: browser), resultingWith: [
                .bookmarks: .success(.init(successful: 0, duplicate: 0, failed: 0)),
                .passwords: .success(.init(successful: 0, duplicate: 0, failed: 0))
            ])

            expect(.error(dataType: .bookmarks, errorType: .noData), actionButton: .manualImport, secondaryButton: .skip, "\(source)")
        }
    }

    func testGenericDataImport() async {
        for source in Source.allCases where ThirdPartyBrowser.browser(for: source) == nil || source.initialScreen != .profileAndDataTypesPicker {
            model = DataImportViewModel(importSource: source, loadProfiles: { XCTFail("Unexpected loadProfiles"); return .init(browser: $0, profiles: []) }, dataImporterFactory: dataImporter)
            XCTAssertEqual(source.supportedDataTypes.count, 1)
            expect(.fileImport(source.supportedDataTypes.first!), actionButton: .initiateImport(disabled: true), secondaryButton: .cancel)


        }
    }
// TODO: test skip
    // MARK: - Tests

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

//    func testWhenNextButtonIsClicked_screenForTheButtonIsShown() {
//        model = DataImportViewModel(importSource: .safari)
//        model.performAction(.next(.fileImport(.bookmarks)))
//        XCTAssertEqual(model.screen, .fileImport(.bookmarks))
//    }
//
//    // MARK: Browser profiles
//
//    func testWhenNoProfilesAreLoaded_selectedProfileIsNil() {
//        model = DataImportViewModel(importSource: .safari, loadProfiles: { source in
//            XCTAssertEqual(source, .safari)
//            return .init(browser: source, profiles: [])
//        })
//        XCTAssertNil(model.selectedProfile)
//    }
//
//    func testWhenProfilesAreLoaded_DefaultProfileIsSelected() {
//        model = DataImportViewModel(importSource: .firefox, loadProfiles: { source in
//            XCTAssertEqual(source, .firefox)
//            return .init(browser: source, profiles: [.test(for: source), .default(for: source)])
//        })
//        XCTAssertEqual(model.selectedProfile, .default(for: .firefox))
//    }
//
//    func testWhenImportSourceChanged_AnotherDefaultProfileIsSelected() {
//        model = DataImportViewModel(importSource: .firefox, loadProfiles: { .init(browser: $0, profiles: [ .test(for: $0), .default(for: $0) ]) })
//        model.update(with: .chromium)
//        XCTAssertEqual(model.selectedProfile, .default(for: .chrome))
//    }
//
//    func testWhenNoDefaultProfileIsLoaded_firstProfileIsSelected() {
//        model = DataImportViewModel(importSource: .chrome, loadProfiles: { .init(browser: $0, profiles: [ .test(for: $0), .test2(for: $0) ]) })
//        XCTAssertEqual(model.selectedProfile, .test(for: .chrome))
//    }
//    // TODO: test switching from all generic to all browser and from all browsers to all generic and from all browsers to all browsers and from all generics to all generics
//
//    // MARK: Import from browser profile
//
//    // MARK: Buttons
//    // TODO: when importer.importableTypes does not contain as selected type next screen should be file import
//    func testWhenProfilesAreLoadedAndImporterCanImportStraightAway_buttonActionsAreCancelAndImport() {
//        model = DataImportViewModel(importSource: .safari, loadProfiles: { .init(browser: $0, profiles: [.test(for: $0)]) }, dataImporterFactory: { _, _, _, _ in
//            ImporterMock()
//        })
//
//        XCTAssertEqual(model.selectedDataTypes, [.bookmarks, .passwords])
//        XCTAssertFalse(model.isActionButtonDisabled)
//        XCTAssertEqual(model.actionButton, .initiateImport)
//        XCTAssertEqual(model.secondaryButton, .cancel)
//        XCTAssertFalse(model.isSecondaryButtonDisabled)
//    }
//
//    func testWhenProfilesAreLoadedAndImporterRequiresKeyChainPassword_buttonActionsAreCancelAndMoreInfo() {
//        model = DataImportViewModel(importSource: .safari, loadProfiles: { .init(browser: $0, profiles: [.test(for: $0)]) }, dataImporterFactory: { _, _, _, _ in
//            ImporterMock(keychainPasswordRequiredFor: [.passwords])
//        })
//
//        XCTAssertEqual(model.selectedDataTypes, [.bookmarks, .passwords])
//        XCTAssertFalse(model.isActionButtonDisabled)
//        XCTAssertEqual(model.actionButton, .next(.moreInfo))
//        XCTAssertEqual(model.secondaryButton, .cancel)
//        XCTAssertFalse(model.isSecondaryButtonDisabled)
//    }
//
//    func testWhenProfilesAreLoadedAndImporterRequiresKeyChainPasswordButPasswordsDataTypeNotSelected_buttonActionsAreCancelAndImport() {
//        model = DataImportViewModel(importSource: .safari, loadProfiles: { .init(browser: $0, profiles: [.test(for: $0)]) }, dataImporterFactory: { _, _, _, _ in
//            ImporterMock(keychainPasswordRequiredFor: [.passwords])
//        })
//        model.setDataType(.passwords, selected: false)
//
//        XCTAssertFalse(model.isActionButtonDisabled)
//        XCTAssertEqual(model.actionButton, .initiateImport)
//        XCTAssertEqual(model.secondaryButton, .cancel)
//        XCTAssertFalse(model.isSecondaryButtonDisabled)
//    }
//
//    func testWhenNoBrowserForImportSource_buttonActionsAreCancelAndNone() {
//        for source in Source.allCases where ThirdPartyBrowser.browser(for: source) == nil {
//            model = DataImportViewModel(importSource: source, loadProfiles: {
//                XCTFail("Unexpected loadProfiles")
//                return .init(browser: $0, profiles: [.test(for: $0)])
//            })
//
//            XCTAssertEqual(model.selectedDataTypes, source.supportedDataTypes, "\(source)")
//            XCTAssertNil(model.actionButton)
//            XCTAssertEqual(model.secondaryButton, .cancel, "\(source)")
//            XCTAssertFalse(model.isSecondaryButtonDisabled, "\(source)")
//        }
//    }
//
//    func testWhenNoProfilesAreLoaded_buttonActionsAreCancelAndProceedToFileImport() {
//        model = DataImportViewModel(importSource: .firefox, loadProfiles: { .init(browser: $0, profiles: []) })
//
//        XCTAssertEqual(model.selectedDataTypes, [.bookmarks, .passwords])
//        XCTAssertFalse(model.isActionButtonDisabled)
//        XCTAssertEqual(model.actionButton, .next(.fileImport(.bookmarks)))
//        XCTAssertEqual(model.secondaryButton, .cancel)
//        XCTAssertFalse(model.isSecondaryButtonDisabled)
//    }
//
//    func testWhenNoProfilesAreLoadedAndBookmarksDataTypeUnselected_fileImportDataTypeChanges() {
//        model = DataImportViewModel(importSource: .firefox, loadProfiles: { .init(browser: $0, profiles: []) })
//
//        model.setDataType(.bookmarks, selected: false)
//
//        XCTAssertEqual(model.selectedDataTypes, [.passwords])
//        XCTAssertEqual(model.actionButton, .next(.fileImport(.passwords)))
//        XCTAssertFalse(model.isActionButtonDisabled)
//        XCTAssertEqual(model.secondaryButton, .cancel)
//        XCTAssertFalse(model.isSecondaryButtonDisabled)
//    }
//
//    func testWhenPasswordsDataTypeUnselected_fileImportDataTypeChanges() {
//        model = DataImportViewModel(importSource: .firefox, loadProfiles: { .init(browser: $0, profiles: []) })
//
//        model.setDataType(.passwords, selected: false)
//
//        XCTAssertEqual(model.selectedDataTypes, [.bookmarks])
//        XCTAssertEqual(model.actionButton, .next(.fileImport(.bookmarks)))
//        XCTAssertFalse(model.isActionButtonDisabled)
//        XCTAssertEqual(model.secondaryButton, .cancel)
//        XCTAssertFalse(model.isSecondaryButtonDisabled)
//    }
//
//    func testWhenNoDataTypeSelected_actionButtonDisabled() {
//        model = DataImportViewModel(importSource: .safari)
//
//        model.setDataType(.bookmarks, selected: false)
//        model.setDataType(.passwords, selected: false)
//
//        XCTAssertEqual(model.selectedDataTypes, [])
//        XCTAssertEqual(model.actionButton, .initiateImport)
//        XCTAssertTrue(model.isActionButtonDisabled)
//        XCTAssertEqual(model.secondaryButton, .cancel)
//        XCTAssertFalse(model.isSecondaryButtonDisabled)
//    }
//
//    func testWhenImportSourceChanges_selectedDataTypesAreReset() {
//        model = DataImportViewModel(importSource: .safari)
//
//        model.setDataType(.bookmarks, selected: false)
//        model.setDataType(.passwords, selected: false)
//
//        model.update(with: .brave)
//
//        XCTAssertEqual(model.selectedDataTypes, [.bookmarks, .passwords])
//        XCTAssertFalse(model.isActionButtonDisabled)
//        XCTAssertEqual(model.actionButton, .next(.fileImport(.bookmarks)))
//        XCTAssertEqual(model.secondaryButton, .cancel)
//        XCTAssertFalse(model.isSecondaryButtonDisabled)
//    }
//
//    func testWhenBookmarksImportFails_failureMessageIsShown() async throws {
//        model = DataImportViewModel(importSource: .safari, loadProfiles: { .init(browser: $0, profiles: [.test(for: $0)]) }, dataImporterFactory: self.dataImporter)
//
//        let model = try await initiateImport { _ in
//            // TODO: test [:]
//            // TODO: test bookmarks .success with 0 bookmarks
//            return [.bookmarks: .failure(MockImportError(action: .bookmarks, errorType: .decryptionError)),
//                    .passwords: .failure(MockImportError(action: .passwords, errorType: .decryptionError))]
//        }
//
//        XCTAssertEqual(model.importSource, .safari)
//        XCTAssertEqual(model.summary, [
//            .init(.bookmarks, .failure(MockImportError(action: .bookmarks))),
//            .init(.passwords, .failure(MockImportError(action: .passwords))),
//        ])
//        XCTAssertEqual(model.screen, .error(dataType: .bookmarks, errorType: .decryptionError))
//        XCTAssertEqual(model.actionButton, .manualImport)
//        XCTAssertFalse(model.isActionButtonDisabled)
//        XCTAssertEqual(model.secondaryButton, .skip)
//        XCTAssertFalse(model.isSecondaryButtonDisabled)
//    }
//
//    func testWhenBookmarksImportFailsAndSkipButtonIsClicked_passwordsImportFailureMessageIsShown() async throws {
//        model = DataImportViewModel(importSource: .safari, loadProfiles: { .init(browser: $0, profiles: [.test(for: $0)]) }, dataImporterFactory: self.dataImporter)
//
//        let m1 = try await initiateImport { _ in
//            return [.bookmarks: .failure(MockImportError(action: .bookmarks, errorType: .decryptionError)),
//                    .passwords: .failure(MockImportError(action: .passwords, errorType: .keychainError))]
//        }
//        model = m1
//
//        model.performAction(.skip)
//
//        XCTAssertEqual(model.importSource, .safari)
//        XCTAssertEqual(model.summary, [
//            .init(.bookmarks, .failure(MockImportError(action: .bookmarks))),
//            .init(.passwords, .failure(MockImportError(action: .passwords))),
//        ])
//        XCTAssertEqual(model.screen, .error(dataType: .passwords, errorType: .keychainError))
//        XCTAssertEqual(model.actionButton, .manualImport)
//        XCTAssertFalse(model.isActionButtonDisabled)
//        XCTAssertEqual(model.secondaryButton, .skip)
//        XCTAssertFalse(model.isSecondaryButtonDisabled)
//    }
//
//    func testWhenBookmarksImportFailsAndManualImportButtonIsClicked_passwordsImportFailureMessageIsShown() async throws {
//        model = DataImportViewModel(importSource: .safari, loadProfiles: { .init(browser: $0, profiles: [.test(for: $0)]) }, dataImporterFactory: self.dataImporter)
//
//        let m1 = try await initiateImport { _ in
//            return [.bookmarks: .failure(MockImportError(action: .bookmarks, errorType: .decryptionError)),
//                    .passwords: .failure(MockImportError(action: .passwords, errorType: .keychainError))]
//        }
//        model = m1
//
//        model.performAction(.skip)
//
//        XCTAssertEqual(model.importSource, .safari)
//        XCTAssertEqual(model.summary, [
//            .init(.bookmarks, .failure(MockImportError(action: .bookmarks))),
//            .init(.passwords, .failure(MockImportError(action: .passwords))),
//        ])
//        XCTAssertEqual(model.screen, .error(dataType: .passwords, errorType: .keychainError))
//        XCTAssertEqual(model.actionButton, .manualImport)
//        XCTAssertFalse(model.isActionButtonDisabled)
//        XCTAssertEqual(model.secondaryButton, .skip)
//        XCTAssertFalse(model.isSecondaryButtonDisabled)
//    }

    // TODO: .bkm: .success, .passwd: .fail -> skip
    // TODO: .bkm: .fail, .passwd: .success -> skip
    // TODO: .bkm: .success, .passwd: .fail -> manual
    // TODO: .bkm: .fail, .passwd: .success -> manual

    // TODO: test progress
    func whenRequiresPrimaryPassword_passwordIsRequested() {

    }

    func testImport() {

    }

    func testFailureImportFileSucceeds() {

    }

    func testFailureImportFileFails() {

    }

    func test2xFailureImportFileSucceedsPasswordsFails() {

    }

    func test2xFailureImportFileSucceedsBookmarksFails() {

    }

    // TODO: and other combination: table of truth

    // TODO: when import source changes selected profile is reset
    // TODO: when import source changes user report text is preserved
    // TODO: when another error after back reported error is updated

    // MARK: - Helpers

    private var importTask: ((DataImportProgressCallback) async -> DataImportSummary)!

    private func dataImporter(for source: DataImport.Source, fileDataType: DataImport.DataType?, url: URL, primaryPassword: String?) -> DataImporter {
        XCTAssertEqual(source, model.importSource)
        if case .fileImport(let dataType) = model.screen {
            XCTAssertEqual(dataType, fileDataType)
        } else {
            XCTAssertNil(fileDataType)
            XCTAssertEqual(url, model.selectedProfile?.profileURL)
        }

        return ImporterMock(password: primaryPassword, importTask: self.importTask)
    }

    func expectButtons<T>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) where T : Equatable {

    }

}

private class ImporterMock: DataImporter {

    var password: String?

    var importableTypes: [DataImport.DataType]

    var keychainPasswordRequiredFor: Set<DataImport.DataType>

    init(password: String? = nil, importableTypes: [DataImport.DataType] = [.bookmarks, .passwords], keychainPasswordRequiredFor: Set<DataImport.DataType> = [], accessValidator: ((Set<DataImport.DataType>) -> [DataImport.DataType: any DataImportError]?)? = nil, importTask: ((DataImportProgressCallback) async -> DataImportSummary)? = nil) {
        self.password = password
        self.importableTypes = importableTypes
        self.keychainPasswordRequiredFor = keychainPasswordRequiredFor
        self.accessValidator = accessValidator
        self.importTask = importTask
    }
    func requiresKeychainPassword(for selectedDataTypes: Set<DataImport.DataType>) -> Bool {
        selectedDataTypes.intersects(keychainPasswordRequiredFor)
    }

    var accessValidator: ((Set<DataImport.DataType>) -> [DataImport.DataType: any DataImportError]?)?

    func validateAccess(for types: Set<DataImport.DataType>) -> [DataImport.DataType : any DataImportError]? {
        accessValidator?(types)
    }

    var importTask: ((DataImportProgressCallback) async -> DataImportSummary)?

    func importData(types: Set<DataImport.DataType>) -> DataImportTask {
        .detachedWithProgress { [importTask=importTask!]updateProgress in
            await importTask(updateProgress)
        }
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

private extension DataImport.BrowserProfile {
    static func test(for browser: ThirdPartyBrowser) -> Self {
        .init(browser: browser, profileURL: .profile(named: "Test Profile"))
    }
    static func test2(for browser: ThirdPartyBrowser) -> Self {
        .init(browser: browser, profileURL: .profile(named: "Test Profile 2"))
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

private struct MockImportError: DataImportError, CustomStringConvertible {

    enum OperationType: Int {
        case failure
    }

    var action: DataImportAction
    var type: OperationType = .failure

    var underlyingError: Error?

    var errorType: DataImport.ErrorType = .other

    var description: String {
        "Error(\(type.rawValue): \(errorType))"
    }
}

extension DataImportViewModel.ButtonType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .next(let screen): "next(\(screen))"
        case .initiateImport(disabled: let disabled): "initiateImport\(disabled ? "(disabled)" : "")"
        case .skip: "skip"
        case .cancel: "cancel"
        case .back: "back"
        case .done: "done"
        case .submit: "submit"
        case .manualImport: "manualImport"
        }
    }
}

extension DataImportViewModel.Screen: CustomStringConvertible {
    public var description: String {
        switch self {
        case .profileAndDataTypesPicker: "profileAndDataTypesPicker"
        case .moreInfo: "moreInfo"
        case .getReadPermission(let url): "getReadPermission(\(url.path))"
        case .error(dataType: let dataType, errorType: let errorType): "error(\(dataType): \(errorType))"
        case .fileImport(let dataType): "fileImport(\(dataType))"
        case .fileImportSummary(let dataType): "fileImportSummary(\(dataType))"
        case .summary: "summary"
        case .feedback: "feedback"
        }
    }
}

private extension String {

    func with(_ addition: String) -> String {
        guard !self.isEmpty else { return addition }
        return self + " - " + addition
    }

}

extension DataImportViewModel {
    @MainActor mutating func performAction(_ buttonType: ButtonType) {
        performAction(for: buttonType, dismiss: { assertionFailure("Unexpected dismiss") })
    }
}
