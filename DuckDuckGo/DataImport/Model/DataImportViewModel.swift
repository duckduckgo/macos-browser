//
//  DataImportViewModel.swift
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

import AppKit
import Common
import Foundation
import UniformTypeIdentifiers

struct DataImportViewModel {

    typealias Source = DataImport.Source
    typealias BrowserProfileList = DataImport.BrowserProfileList
    typealias BrowserProfile = DataImport.BrowserProfile
    typealias DataType = DataImport.DataType

    @UserDefaultsWrapper(key: .homePageContinueSetUpImport, defaultValue: nil)
    var successfulImportHappened: Bool?

    /// Browser to import data from
    let importSource: Source
    /// BrowserProfileList loader (factory method) - used
    private let loadProfiles: (ThirdPartyBrowser) -> BrowserProfileList
    /// Loaded BrowserProfileList
    let browserProfiles: BrowserProfileList?

    typealias DataImporterFactory = @MainActor (Source, DataType?, URL, /* primaryPassword: */ String?) -> DataImporter
    /// Factory for a DataImporter for importSource
    private let dataImporterFactory: DataImporterFactory

    /// Show a master password input dialog callback
    private let requestPrimaryPasswordCallback: @MainActor (Source) -> String?

    /// Show Open Panel to choose CSV/HTML file
    private let openPanelCallback: @MainActor (DataType) -> URL?

    typealias ReportSenderFactory = () -> (DataImportReportModel) -> Void
    /// Factory for a DataImporter for importSource
    private let reportSenderFactory: ReportSenderFactory

    private func log(_ message: @autoclosure () -> String) {
        if OSLog.dataImportExport != .disabled {
            os_log(log: .dataImportExport, message())
        } else if NSApp.runType == .xcPreviews {
            print(message())
        }
    }

    enum Screen: Hashable {
        case profileAndDataTypesPicker
        case moreInfo
        case getReadPermission(URL)
        case fileImport(dataType: DataType, summary: Set<DataType> = [])
        case summary(Set<DataType>)
        case noData(DataType)
        case feedback

        var isFileImport: Bool {
            if case .fileImport = self { true } else { false }
        }
        var fileImportDataType: DataType? {
            switch self {
            case .fileImport(dataType: let dataType, summary: _),
                 .noData(let dataType):
                return dataType
            default:
                return nil
            }
        }
    }
    /// Currently displayed screen
    private(set) var screen: Screen

    /// selected Browser Profile (if any)
    var selectedProfile: BrowserProfile?
    /// selected Data Types to import (bookmarks/passwords)
    var selectedDataTypes: Set<DataType> = []

    /// data import concurrency Task launched in `initiateImport`
    /// used to cancel import and in `importProgress` to trace import progress and import completion
    private var importTask: DataImportTask?

    struct DataTypeImportResult: Equatable {
        let dataType: DataImport.DataType
        let result: DataImportResult<DataImport.DataTypeSummary>
        init(_ dataType: DataImport.DataType, _ result: DataImportResult<DataImport.DataTypeSummary>) {
            self.dataType = dataType
            self.result = result
        }
    }

    /// collected import summary for current import operation per selected import source
    private(set) var summary: [DataTypeImportResult]

    private var userReportText: String = ""

#if DEBUG || REVIEW

    enum ImportError: DataImportError {
        enum OperationType: Int {
            case imp
        }

        var type: OperationType { .imp }
        var action: DataImportAction { .generic }
        var underlyingError: Error? {
            if case .err(let err) = self {
                return err
            }
            return nil
        }
        var errorType: DataImport.ErrorType { .noData }

        case err(Error)
    }

    var testImportFailureReasons = [DataType: DataImport.ErrorType]()

#endif

    init(importSource: Source? = nil,
         screen: Screen? = nil,
         availableImportSources: @autoclosure () -> Set<Source> = Set(ThirdPartyBrowser.installedBrowsers.map(\.importSource)),
         preferredImportSources: [Source] = [.chrome, .firefox, .safari],
         summary: [DataTypeImportResult] = [],
         loadProfiles: @escaping (ThirdPartyBrowser) -> BrowserProfileList = { $0.browserProfiles() },
         dataImporterFactory: @escaping DataImporterFactory = dataImporter,
         requestPrimaryPasswordCallback: @escaping @MainActor (Source) -> String? = Self.requestPrimaryPasswordCallback,
         openPanelCallback: @escaping @MainActor (DataType) -> URL? = Self.openPanelCallback,
         reportSenderFactory: @escaping ReportSenderFactory = { FeedbackSender().sendDataImportReport }) {

        lazy var availableImportSources = availableImportSources()
        let importSource = importSource ?? preferredImportSources.first(where: { availableImportSources.contains($0) }) ?? .csv

        self.importSource = importSource
        self.loadProfiles = loadProfiles
        self.dataImporterFactory = dataImporterFactory

        self.screen = screen ?? importSource.initialScreen

        self.browserProfiles = ThirdPartyBrowser.browser(for: importSource).map(loadProfiles)
        self.selectedProfile = browserProfiles?.defaultProfile

        self.selectedDataTypes = importSource.supportedDataTypes

        self.summary = summary

        self.requestPrimaryPasswordCallback = requestPrimaryPasswordCallback
        self.openPanelCallback = openPanelCallback
        self.reportSenderFactory = reportSenderFactory
    }

    /// Import button press (starts browser data import)
    @MainActor
    mutating func initiateImport(primaryPassword: String? = nil, fileURL: URL? = nil) {
        guard let url = fileURL ?? selectedProfile?.profileURL else {
            assertionFailure("URL not provided")
            return
        }
        assert(actionButton == .initiateImport(disabled: false) || screen.fileImportDataType != nil)

        // are we handling file import or browser selected data types import?
        let dataType: DataType? = self.screen.fileImportDataType
        let dataTypes = dataType.map { [$0] } ?? selectedDataTypes
        let importer = dataImporterFactory(importSource, dataType, url, primaryPassword)

        log("import \(dataTypes) at \"\(url.path)\" using \(type(of: importer))")

        // validate file access/encryption password requirement before starting import
        if let errors = importer.validateAccess(for: dataTypes),
           handleErrors(errors) == true {
            return
        }

        // simulated test import failures
#if DEBUG || REVIEW
        struct TestImportError: DataImportError {
            enum OperationType: Int {
                case imp
            }
            var type: OperationType { .imp }
            var action: DataImportAction
            var underlyingError: Error? { CocoaError(.fileReadUnknown) }
            var errorType: DataImport.ErrorType
        }

        guard dataTypes.compactMap({ testImportFailureReasons[$0] }).isEmpty else {
            importTask = .detachedWithProgress { [testImportFailureReasons] progressUpdate in
                var result = DataImportSummary()
                let selectedDataTypesWithoutFailureReasons = dataTypes.intersection(importer.importableTypes).subtracting(testImportFailureReasons.keys)
                var realSummary = DataImportSummary()
                if !selectedDataTypesWithoutFailureReasons.isEmpty {
                    realSummary = await importer.importData(types: selectedDataTypesWithoutFailureReasons).task.value
                }
                for dataType in dataTypes {
                    if let failureReason = testImportFailureReasons[dataType] {
                        result[dataType] = .failure(TestImportError(action: .init(dataType), errorType: failureReason))
                    } else {
                        result[dataType] = realSummary[dataType]
                    }
                }
                return result
            }
            return
        }
#endif
        importTask = importer.importData(types: dataTypes)
    }

    /// Called with data import task result to update the state by merging the summary with an existing summary
    @MainActor
    private mutating func mergeImportSummary(with summary: DataImportSummary) {
        self.importTask = nil

        log("merging summary \(summary)")

        if handleErrors(summary.compactMapValues { $0.error }) { return }

        var nextScreen: Screen?
        // merge new import results into the model import summary
        for (dataType, result) in DataType.allCases.compactMap({ dataType in summary[dataType].map { (dataType, $0) } }) {
            self.summary.append( .init(dataType, result) )

            switch result {
            case .success(let summary):
                if summary.successful == 0 && summary.duplicate == 0 && summary.failed == 0, nextScreen == nil {
                    nextScreen = .noData(dataType)
                }
            case .failure(let error):
                if case .noData = error.errorType, nextScreen == nil {
                    nextScreen = .noData(dataType)
                }
                Pixel.fire(.dataImportFailed(source: importSource, error: error))
            }
        }

        if let nextScreen {
            self.screen = nextScreen
        } else if screenForNextDataTypeRemainingToImport(after: DataType.allCases.last(where: summary.keys.contains)) == nil, // no next data type manual import screen
           // and there should be failed data types (and non-recovered)
           selectedDataTypes.contains(where: { dataType in self.summary.last(where: { $0.dataType == dataType })?.result.error != nil }) {
            // after last failed datatype show feedback
            self.screen = .feedback
        } else {
            self.screen = .summary(Set(summary.keys))
        }

        if self.areAllSelectedDataTypesSuccessfullyImported {
            successfulImportHappened = true
            NotificationCenter.default.post(name: .dataImportComplete, object: nil)
        }

        log("next screen: \(screen)")
    }

    /// handle recoverable errors (request primary password or file permission)
    @MainActor
    private mutating func handleErrors(_ summary: [DataType: any DataImportError]) -> Bool {
        for error in summary.values {
            switch error {
            // chromium user denied keychain prompt error
            case let error as ChromiumLoginReader.ImportError where error.type == .userDeniedKeychainPrompt:
                // stay on the same screen
                return true

            // firefox passwords db is master-password protected: request password
            case let error as FirefoxLoginReader.ImportError where error.type == .requiresPrimaryPassword:

                log("primary password required")
                // stay on the same screen but request password synchronously
                if let password = self.requestPrimaryPasswordCallback(importSource) {
                    self.initiateImport(primaryPassword: password)
                }
                return true

            // no file read permission error: user must grant permission
            case let importError where (importError.underlyingError as? CocoaError)?.code == .fileReadNoPermission:
                guard let error = importError.underlyingError as? CocoaError,
                      let url = error.filePath.map(URL.init(fileURLWithPath:)) ?? error.url else {
                    assertionFailure("No url")
                    break
                }
                log("file read no permission for \(url.path)")
                screen = .getReadPermission(url)
                return true

            default: continue
            }
        }
        return false
    }

    /// Skip button press
    @MainActor mutating func skipImport() {
        if let screen = screenForNextDataTypeRemainingToImport(after: screen.fileImportDataType) {
            // skip to next non-imported data type
            self.screen = screen
        } else if selectedDataTypes.first(where: { error(for: $0) != nil }) != nil {
            // errors occurred during import: show feedback screen
            self.screen = .feedback
        } else {
            // display total summary
            self.screen = .summary(selectedDataTypes)
        }
    }

    /// Open Manual File Import screen action
    mutating func manualImport(dataType: DataType) {
        screen = .fileImport(dataType: dataType)
    }

    /// Select CSV/HTML file for import button press
    @MainActor mutating func selectFile() {
        guard let dataType = screen.fileImportDataType else {
            assertionFailure("Expected File Import")
            return
        }
        guard let url = openPanelCallback(dataType) else { return }

        self.initiateImport(fileURL: url)
    }

    mutating func goBack() {
        // reset to initial screen
        screen = importSource.initialScreen
        summary.removeAll()
    }

    func submitReport() {
        let sendReport = reportSenderFactory()
        sendReport(reportModel)
    }

}

@MainActor
private func dataImporter(for source: DataImport.Source, fileDataType: DataImport.DataType?, url: URL, primaryPassword: String?) -> DataImporter {

    var profile: DataImport.BrowserProfile {
        let browser = ThirdPartyBrowser.browser(for: source) ?? {
            assertionFailure("Trying to get browser name for file import source \(source)")
            return .chrome
        }()
        return DataImport.BrowserProfile(browser: browser, profileURL: url)
    }
    return switch source {
    case .bookmarksHTML,
         /* any */_ where fileDataType == .bookmarks:

        BookmarkHTMLImporter(fileURL: url, bookmarkImporter: CoreDataBookmarkImporter(bookmarkManager: LocalBookmarkManager.shared))

    case .onePassword8, .onePassword7, .bitwarden, .lastPass, .csv,
         /* any */_ where fileDataType == .passwords:
        CSVImporter(fileURL: url, loginImporter: SecureVaultLoginImporter(), defaultColumnPositions: .init(source: source))

    case .brave, .chrome, .chromium, .coccoc, .edge, .opera, .operaGX, .vivaldi:
        ChromiumDataImporter(profile: profile,
                             loginImporter: SecureVaultLoginImporter(),
                             bookmarkImporter: CoreDataBookmarkImporter(bookmarkManager: LocalBookmarkManager.shared))
    case .yandex:
        YandexDataImporter(profile: profile,
                           bookmarkImporter: CoreDataBookmarkImporter(bookmarkManager: LocalBookmarkManager.shared))
    case .firefox, .tor:
        FirefoxDataImporter(profile: profile,
                            primaryPassword: primaryPassword,
                            loginImporter: SecureVaultLoginImporter(),
                            bookmarkImporter: CoreDataBookmarkImporter(bookmarkManager: LocalBookmarkManager.shared),
                            faviconManager: FaviconManager.shared)
    case .safari, .safariTechnologyPreview:
        SafariDataImporter(profile: profile,
                           bookmarkImporter: CoreDataBookmarkImporter(bookmarkManager: LocalBookmarkManager.shared))
    }
}

private var isOpenPanelShownFirstTime = true
private var openPanelDirectoryURL: URL? {
    // only show Desktop once per launch, then open the last user-selected dir
    if isOpenPanelShownFirstTime {
        isOpenPanelShownFirstTime = false
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    } else {
        return nil
    }
}

extension DataImport.Source {

    var initialScreen: DataImportViewModel.Screen {
        switch self {
        case .brave, .chrome, .chromium, .coccoc, .edge, .firefox, .opera,
             .operaGX, .safari, .safariTechnologyPreview, .tor, .vivaldi, .yandex:
            return .profileAndDataTypesPicker
        case .onePassword8, .onePassword7, .bitwarden, .lastPass, .csv:
            return .fileImport(dataType: .passwords)
        case .bookmarksHTML:
            return .fileImport(dataType: .bookmarks)
        }
    }

}

extension DataImport.DataType {

    static func dataTypes(before dataType: DataImport.DataType, inclusive: Bool) -> [Self].SubSequence {
        let index = Self.allCases.firstIndex(of: dataType)!
        if inclusive {
            return Self.allCases[...index]
        } else {
            return Self.allCases[..<index]
        }
    }

    static func dataTypes(after dataType: DataImport.DataType) -> [Self].SubSequence {
        let nextIndex = Self.allCases.firstIndex(of: dataType)! + 1
        return Self.allCases[nextIndex...]
    }

    var allowedFileTypes: [UTType] {
        switch self {
        case .bookmarks: [.html]
        case .passwords: [.commaSeparatedText]
        }
    }

}

extension DataImportViewModel {

    private var areAllSelectedDataTypesSuccessfullyImported: Bool {
        selectedDataTypes.allSatisfy(isDataTypeSuccessfullyImported)
    }

    private func isDataTypeSuccessfullyImported(_ dataType: DataType) -> Bool {
        summary.reversed().contains(where: { dataTypeImportResult in
            dataType == dataTypeImportResult.dataType && dataTypeImportResult.result.isSuccess
        })
    }

    private func screenForNextDataTypeRemainingToImport(after currentDataType: DataType? = nil) -> Screen? {
        // keep the original sort order among all data types or only after current data type
        for dataType in (currentDataType.map { DataType.dataTypes(after: $0) } ?? DataType.allCases[0...]) where selectedDataTypes.contains(dataType) {
            // if some of selected data types failed to import or not imported yet
            switch summary.last(where: { $0.dataType == dataType })?.result {
            case .success(let summary) where summary.successful == 0 && summary.duplicate == 0 && summary.failed == 0:
                return .noData(dataType)
            case .failure(let error) where error.errorType == .noData:
                return .noData(dataType)
            case .failure, .none:
                return .fileImport(dataType: dataType)
            case .success:
                continue
            }
        }
        return nil
    }

    private func error(for dataType: DataType) -> (any DataImportError)? {
        if case .failure(let error) = summary.last(where: { $0.dataType == dataType })?.result {
            return error
        }
        return nil
    }

    private struct DataImportViewSummarizedError: LocalizedError {
        let errors: [any DataImportError]

        var errorDescription: String? {
            errors.enumerated().map {
                "\($0.offset + 1): \($0.element.localizedDescription)"
            }.joined(separator: "\n")
        }
    }

    var summarizedError: LocalizedError {
        let errors = summary.compactMap { $0.result.error }
        if errors.count == 1 {
            return errors[0]
        }
        return DataImportViewSummarizedError(errors: errors)
    }

    func hasDataTypeImportFailed(_ dataType: DataType) -> Bool {
        var failureFound = false
        for dataTypeImportResult in summary.reversed() where dataTypeImportResult.dataType == dataType {
            switch dataTypeImportResult.result {
            case .success:
                return false
            case .failure:
                failureFound = true
            }
        }
        return failureFound
    }

    private static func requestPrimaryPasswordCallback(_ source: DataImport.Source) -> String? {
        let alert = NSAlert.passwordRequiredAlert(source: source)
        let response = alert.runModal()

        guard case .alertFirstButtonReturn = response,
              let password = (alert.accessoryView as? NSSecureTextField)?.stringValue else { return nil }

        return password
    }

    private static func openPanelCallback(for dataType: DataImport.DataType) -> URL? {
        let panel = NSOpenPanel(allowedFileTypes: dataType.allowedFileTypes,
                                directoryURL: openPanelDirectoryURL)
        guard case .OK = panel.runModal(),
              let url = panel.url else { return nil }

        return url
    }

    var isImportSourcePickerDisabled: Bool {
        importSource.initialScreen != screen || importTask != nil
    }

    // AsyncStream of Data Import task progress events
    var importProgress: TaskProgress<Self, Never, DataImportProgressEvent>? {
        guard let importTask else { return nil }
        return AsyncStream {
            for await event in importTask.progress {
                switch event {
                case .progress(let update):
                    log("progress: \(update)")
                    return .progress(update)
                    // on completion returns new DataImportViewModel with merged import summary
                case .completed(.success(let summary)):
                    return await .completed(.success(self.mergingImportSummary(summary)))
                }
            }
            return nil
        }
    }

    enum ButtonType: Hashable {
        case next(Screen)
        case initiateImport(disabled: Bool)
        case skip
        case cancel
        case back
        case done
        case submit

        var isDisabled: Bool {
            switch self {
            case .initiateImport(disabled: let disabled):
                return disabled
            case .next, .skip, .done, .cancel, .back, .submit:
                return false
            }
        }
    }

    @MainActor var actionButton: ButtonType? {
        func initiateImport() -> ButtonType {
            .initiateImport(disabled: selectedDataTypes.isEmpty || importTask != nil)
        }

        switch screen {
        case .profileAndDataTypesPicker:
            guard let importer = selectedProfile.map({
                dataImporterFactory(/* importSource: */ importSource,
                                    /* dataType: */ nil,
                                    /* profileURL: */ $0.profileURL,
                                    /* primaryPassword: */ nil)
            }),
                  selectedDataTypes.intersects(importer.importableTypes) else {
                // no profiles found
                // or selected data type not supported by selected browser data importer
                guard let type = DataType.allCases.filter(selectedDataTypes.contains).first else {
                    // disabled Import button
                    return initiateImport()
                }
                // use CSV/HTML file import
                return .next(.fileImport(dataType: type))
            }

            if importer.requiresKeychainPassword(for: selectedDataTypes) {
                return .next(.moreInfo)
            }
            return initiateImport()

        case .moreInfo:
            return initiateImport()

        case .getReadPermission:
            return .initiateImport(disabled: true)

        case .fileImport where screen == importSource.initialScreen:
            // no default action for File Import sources
            return nil
        case .fileImport(dataType: let dataType, summary: _)
            // exlude all skipped datatypes that are ordered before
            where selectedDataTypes.subtracting(DataType.dataTypes(before: dataType, inclusive: true)).isEmpty:
            // no other data types to skip:
            return .cancel
        case .fileImport, .noData:
            return .skip

        case .summary(let dataTypes):
            if let screen = screenForNextDataTypeRemainingToImport(after: DataType.allCases.last(where: dataTypes.contains)) {
                return .next(screen)
            } else {
                return .done
            }

        case .feedback:
            return .submit
        }
    }

    var secondaryButton: ButtonType? {
        if importTask == nil {
            switch screen {
            case importSource.initialScreen, .feedback:
                return .cancel
            case .moreInfo, .getReadPermission, .noData:
                return .back
            default:
                return nil
            }
        } else {
            return .cancel
        }
    }

    var isSelectFileButtonDisabled: Bool {
        importTask != nil
    }

    @MainActor var buttons: [ButtonType] {
        [secondaryButton, actionButton].compactMap { $0 }
    }

    mutating func update(with importSource: Source) {
        self = .init(importSource: importSource, loadProfiles: loadProfiles, dataImporterFactory: dataImporterFactory, requestPrimaryPasswordCallback: requestPrimaryPasswordCallback, reportSenderFactory: reportSenderFactory)
    }

    @MainActor
    mutating func performAction(for buttonType: ButtonType, dismiss: @escaping () -> Void) {
        assert(buttons.contains(buttonType))

        switch buttonType {
        case .next(let screen):
            self.screen = screen
        case .back:
            goBack()

        case .initiateImport:
            initiateImport()

        case .skip:
            skipImport()

        case .cancel:
            importTask?.cancel()
            self.dismiss(using: dismiss)

        case .submit:
            submitReport()
            self.dismiss(using: dismiss)
        case .done:
            self.dismiss(using: dismiss)
        }
    }

    private mutating func dismiss(using dismiss: @escaping () -> Void) {
        // send `bookmarkPromptShouldShow` notification after dismiss if at least one bookmark was imported
        if summary.reduce(into: 0, { $0 += $1.dataType == .bookmarks ? (try? $1.result.get().successful) ?? 0 : 0 }) > 0 {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .bookmarkPromptShouldShow, object: nil)
            }
        }

        dismiss()
        if case .xcPreviews = NSApp.runType {
            self.update(with: importSource) // reset
        }
    }

    @MainActor
    private func mergingImportSummary(_ summary: DataImportSummary) -> Self {
        var newState = self
        newState.mergeImportSummary(with: summary)
        return newState
    }

    private var retryNumber: Int {
        summary.reduce(into: [:]) {
            // get maximum number of failures per data type
            $0[$1.dataType, default: 0] += $1.result.isSuccess ? 0 : 1
        }.values.max() ?? 0
    }

    var reportModel: DataImportReportModel {
        get {
            DataImportReportModel(importSource: importSource, error: summarizedError, text: userReportText, retryNumber: retryNumber)
        } set {
            userReportText = newValue.text
        }
    }

}
