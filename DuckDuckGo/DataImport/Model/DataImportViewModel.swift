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
import UniformTypeIdentifiers
import PixelKit
import os.log
import BrowserServicesKit

struct DataImportViewModel {

    typealias Source = DataImport.Source
    typealias BrowserProfileList = DataImport.BrowserProfileList
    typealias BrowserProfile = DataImport.BrowserProfile
    typealias DataType = DataImport.DataType
    typealias DataTypeSummary = DataImport.DataTypeSummary

    @UserDefaultsWrapper(key: .homePageContinueSetUpImport, defaultValue: nil)
    var successfulImportHappened: Bool?

    let availableImportSources: [DataImport.Source]
    /// Browser to import data from
    let importSource: Source
    /// BrowserProfileList loader (factory method) - used
    private let loadProfiles: (ThirdPartyBrowser) -> BrowserProfileList
    /// Loaded BrowserProfileList
    let browserProfiles: BrowserProfileList?

    typealias DataImporterFactory = @MainActor (Source, DataType?, URL, /* primaryPassword: */ String?) -> DataImporter
    /// Factory for a DataImporter for importSource
    private let dataImporterFactory: DataImporterFactory

    /// Show a main password input dialog callback
    private let requestPrimaryPasswordCallback: @MainActor (Source) -> String?

    /// Show Open Panel to choose CSV/HTML file
    private let openPanelCallback: @MainActor (DataType) -> URL?

    typealias ReportSenderFactory = () -> (DataImportReportModel) -> Void
    /// Factory for a DataImporter for importSource
    private let reportSenderFactory: ReportSenderFactory

    private let onFinished: () -> Void

    private let onCancelled: () -> Void

    enum Screen: Hashable {
        case profileAndDataTypesPicker
        case moreInfo
        case getReadPermission(URL)
        case fileImport(dataType: DataType, summary: Set<DataType> = [])
        case summary(Set<DataType>, isFileImport: Bool = false)
        case feedback
        case shortcuts(Set<DataType>)

        var isFileImport: Bool {
            if case .fileImport = self { true } else { false }
        }

        var isGetReadPermission: Bool {
            if case .getReadPermission = self { true } else { false }
        }

        var fileImportDataType: DataType? {
            switch self {
            case .fileImport(dataType: let dataType, summary: _):
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
        let result: DataImportResult<DataTypeSummary>
        init(_ dataType: DataImport.DataType, _ result: DataImportResult<DataTypeSummary>) {
            self.dataType = dataType
            self.result = result
        }

        static func == (lhs: DataTypeImportResult, rhs: DataTypeImportResult) -> Bool {
            lhs.dataType == rhs.dataType &&
            lhs.result.description == rhs.result.description
        }
    }

    /// collected import summary for current import operation per selected import source
    private(set) var summary: [DataTypeImportResult]

    private var userReportText: String = ""

#if DEBUG || REVIEW

    // simulated test import failure
    struct TestImportError: DataImportError {
        enum OperationType: Int {
            case imp
        }
        var type: OperationType { .imp }
        var action: DataImportAction
        var underlyingError: Error? { CocoaError(.fileReadUnknown) }
        var errorType: DataImport.ErrorType
    }

    var testImportResults = [DataType: DataImportResult<DataTypeSummary>]()

#endif

    let isPasswordManagerAutolockEnabled: Bool

    init(importSource: Source? = nil,
         screen: Screen? = nil,
         availableImportSources: [DataImport.Source] = DataImport.Source.allCases.filter { $0.canImportData },
         preferredImportSources: [Source] = [.chrome, .firefox, .safari],
         summary: [DataTypeImportResult] = [],
         isPasswordManagerAutolockEnabled: Bool = AutofillPreferences().isAutoLockEnabled,
         loadProfiles: @escaping (ThirdPartyBrowser) -> BrowserProfileList = { $0.browserProfiles() },
         dataImporterFactory: @escaping DataImporterFactory = dataImporter,
         requestPrimaryPasswordCallback: @escaping @MainActor (Source) -> String? = Self.requestPrimaryPasswordCallback,
         openPanelCallback: @escaping @MainActor (DataType) -> URL? = Self.openPanelCallback,
         reportSenderFactory: @escaping ReportSenderFactory = { FeedbackSender().sendDataImportReport },
         onFinished: @escaping () -> Void = {},
         onCancelled: @escaping () -> Void = {}) {

        self.availableImportSources = availableImportSources
        let importSource = importSource ?? preferredImportSources.first(where: { availableImportSources.contains($0) }) ?? .csv

        self.importSource = importSource
        self.loadProfiles = loadProfiles
        self.dataImporterFactory = dataImporterFactory

        self.screen = screen ?? importSource.initialScreen

        self.browserProfiles = ThirdPartyBrowser.browser(for: importSource).map(loadProfiles)
        self.selectedProfile = browserProfiles?.defaultProfile

        self.selectedDataTypes = importSource.supportedDataTypes

        self.summary = summary
        self.isPasswordManagerAutolockEnabled = isPasswordManagerAutolockEnabled

        self.requestPrimaryPasswordCallback = requestPrimaryPasswordCallback
        self.openPanelCallback = openPanelCallback
        self.reportSenderFactory = reportSenderFactory
        self.onFinished = onFinished
        self.onCancelled = onCancelled

        PixelExperiment.fireOnboardingImportRequestedPixel()
    }

    /// Import button press (starts browser data import)
    @MainActor
    mutating func initiateImport(primaryPassword: String? = nil, fileURL: URL? = nil) {
        guard let url = fileURL ?? selectedProfile?.profileURL else {
            assertionFailure("URL not provided")
            return
        }
        assert(actionButton == .initiateImport(disabled: false) || screen.fileImportDataType != nil || screen.isGetReadPermission)

        // are we handling file import or browser selected data types import?
        let dataType: DataType? = self.screen.fileImportDataType
        // either import only data type for file import
        let dataTypes = dataType.map { [$0] }
            // or all the selected data types subtracting the ones that are already imported
            ?? selectedDataTypes.subtracting(self.summary.filter { $0.result.isSuccess }.map(\.dataType))
        let importer = dataImporterFactory(importSource, dataType, url, primaryPassword)

        Logger.dataImportExport.debug("import \(dataTypes) at \"\(url.path)\" using \(type(of: importer))")

        // validate file access/encryption password requirement before starting import
        if let errors = importer.validateAccess(for: dataTypes),
           handleErrors(errors) == true {
            return
        }

#if DEBUG || REVIEW
        // simulated test import failures
        guard dataTypes.compactMap({ testImportResults[$0] }).isEmpty else {
            importTask = .detachedWithProgress { [testImportResults] _ in
                var result = DataImportSummary()
                let selectedDataTypesWithoutFailureReasons = dataTypes.intersection(importer.importableTypes).subtracting(testImportResults.keys)
                var realSummary = DataImportSummary()
                if !selectedDataTypesWithoutFailureReasons.isEmpty {
                    realSummary = await importer.importData(types: selectedDataTypesWithoutFailureReasons).task.value
                }
                for dataType in dataTypes {
                    if let importResult = testImportResults[dataType] {
                        result[dataType] = importResult
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

        Logger.dataImportExport.debug("merging summary \(summary)")

        // append successful import results first keeping the original DataType sorting order
        self.summary.append(contentsOf: DataType.allCases.compactMap { dataType in
            (try? summary[dataType]?.get()).map {
                .init(dataType, .success($0))
            }
        })

        // if there‘s read permission/primary password requested - request it and reinitiate import
        if handleErrors(summary.compactMapValues { $0.error }) { return }

        var nextScreen: Screen?
        // merge new import results into the model import summary keeping the original DataType sorting order
        for (dataType, result) in DataType.allCases.compactMap({ dataType in summary[dataType].map { (dataType, $0) } }) {
            let sourceVersion = importSource.installedAppsMajorVersionDescription(selectedProfile: selectedProfile)
            switch result {
            case .success(let dataTypeSummary):
                // if a data type can‘t be imported (Yandex/Passwords) - switch to its file import displaying successful import results
                if dataTypeSummary.isEmpty, !(screen.isFileImport && screen.fileImportDataType == dataType), nextScreen == nil {
                    nextScreen = .fileImport(dataType: dataType, summary: Set(summary.filter({ $0.value.isSuccess }).keys))
                }
                PixelKit.fire(GeneralPixel.dataImportSucceeded(action: .init(dataType), source: importSource, sourceVersion: sourceVersion))
            case .failure(let error):
                // successful imports are appended above
                self.summary.append( .init(dataType, result) )

                // show file import screen when import fails or no bookmarks|passwords found
                if !(screen.isFileImport && screen.fileImportDataType == dataType), nextScreen == nil {
                    // switch to file import of the failed data type displaying successful import results
                    nextScreen = .fileImport(dataType: dataType, summary: Set(summary.filter({ $0.value.isSuccess }).keys))
                }
                PixelKit.fire(GeneralPixel.dataImportFailed(source: importSource, sourceVersion: sourceVersion, error: error))
            }
        }

        if let nextScreen {
            Logger.dataImportExport.debug("mergeImportSummary: next screen: \(String(describing: nextScreen))")
            self.screen = nextScreen
        } else if screenForNextDataTypeRemainingToImport(after: DataType.allCases.last(where: summary.keys.contains)) == nil, // no next data type manual import screen
           // and there should be failed data types (and non-recovered)
           selectedDataTypes.contains(where: { dataType in self.summary.last(where: { $0.dataType == dataType })?.result.error != nil }) {
            Logger.dataImportExport.debug("mergeImportSummary: feedback")
            // after last failed datatype show feedback
            self.screen = .feedback
        } else if self.screen.isFileImport, let dataType = self.screen.fileImportDataType {
            Logger.dataImportExport.debug("mergeImportSummary: file import summary(\(dataType))")
            self.screen = .summary([dataType], isFileImport: true)
        } else if screenForNextDataTypeRemainingToImport(after: DataType.allCases.last(where: summary.keys.contains)) == nil { // no next data type manual import screen
            let allKeys = self.summary.reduce(into: Set()) { $0.insert($1.dataType) }
            Logger.dataImportExport.debug("mergeImportSummary: final summary(\(Set(allKeys)))")
            self.screen = .summary(allKeys)
        } else {
            Logger.dataImportExport.debug("mergeImportSummary: intermediary summary(\(Set(summary.keys)))")
            self.screen = .summary(Set(summary.keys))
        }

        if self.areAllSelectedDataTypesSuccessfullyImported {
            successfulImportHappened = true
            NotificationCenter.default.post(name: .dataImportComplete, object: nil)
        }
    }

    /// handle recoverable errors (request primary password or file permission)
    @MainActor
    private mutating func handleErrors(_ summary: [DataType: any DataImportError]) -> Bool {
        for error in summary.values {
            switch error {
            // chromium user denied keychain prompt error
            case let error as ChromiumLoginReader.ImportError where error.type == .userDeniedKeychainPrompt:
                PixelKit.fire(GeneralPixel.passwordImportKeychainPromptDenied)
                // stay on the same screen
                return true

            // firefox passwords db is main-password protected: request password
            case let error as FirefoxLoginReader.ImportError where error.type == .requiresPrimaryPassword:

                Logger.dataImportExport.debug("primary password required")
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
                Logger.dataImportExport.debug("file read no permission for \(url.path)")

                if url != selectedProfile?.profileURL.appendingPathComponent(SafariDataImporter.bookmarksFileName) {
                    PixelKit.fire(GeneralPixel.dataImportFailed(source: importSource, sourceVersion: importSource.installedAppsMajorVersionDescription(selectedProfile: selectedProfile), error: importError))
                }
                screen = .getReadPermission(url)
                return true

            default: continue
            }
        }
        return false
    }

    /// Skip button press
    @MainActor mutating func skipImportOrDismiss(using dismiss: @escaping () -> Void) {
        if let screen = screenForNextDataTypeRemainingToImport(after: screen.fileImportDataType) {
            // skip to next non-imported data type
            self.screen = screen
        } else if selectedDataTypes.first(where: {
            let error = error(for: $0)
            return error != nil && error?.errorType != .noData
        }) != nil {
            // errors occurred during import: show feedback screen
            self.screen = .feedback
        } else {
            // When we skip a manual import, and there are no next non-imported data types,
            // if some data was successfully imported we present the shortcuts screen, otherwise we dismiss
            var dataTypes: Set<DataType> = []

            // Filter out only the successful results with a positive count of successful summaries
            for dataTypeImportResult in summary {
                guard case .success(let summary) = dataTypeImportResult.result, summary.successful > 0 else {
                    continue
                }
                dataTypes.insert(dataTypeImportResult.dataType)
            }

            if !dataTypes.isEmpty {
                self.screen = .shortcuts(dataTypes)
            } else {
                self.dismiss(using: dismiss)
            }
        }
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
        CSVImporter(fileURL: url, loginImporter: SecureVaultLoginImporter(loginImportState: AutofillLoginImportState()), defaultColumnPositions: .init(source: source), reporter: SecureVaultReporter.shared)

    case .brave, .chrome, .chromium, .coccoc, .edge, .opera, .operaGX, .vivaldi:
        ChromiumDataImporter(profile: profile,
                             loginImporter: SecureVaultLoginImporter(loginImportState: AutofillLoginImportState()),
                             bookmarkImporter: CoreDataBookmarkImporter(bookmarkManager: LocalBookmarkManager.shared))
    case .yandex:
        YandexDataImporter(profile: profile,
                           bookmarkImporter: CoreDataBookmarkImporter(bookmarkManager: LocalBookmarkManager.shared))
    case .firefox, .tor:
        FirefoxDataImporter(profile: profile,
                            primaryPassword: primaryPassword,
                            loginImporter: SecureVaultLoginImporter(loginImportState: AutofillLoginImportState()),
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

    func summary(for dataType: DataType) -> DataTypeSummary? {
        if case .success(let summary) = self.summary.last(where: { $0.dataType == dataType })?.result {
            return summary
        }
        return nil
    }

    func isDataTypeSuccessfullyImported(_ dataType: DataType) -> Bool {
        summary(for: dataType) != nil
    }

    private func screenForNextDataTypeRemainingToImport(after currentDataType: DataType? = nil) -> Screen? {
        // keep the original sort order among all data types or only after current data type
        for dataType in (currentDataType.map { DataType.dataTypes(after: $0) } ?? DataType.allCases[0...]) where selectedDataTypes.contains(dataType) {
            // if some of selected data types failed to import or not imported yet
            switch summary.last(where: { $0.dataType == dataType })?.result {
            case .success(let summary) where summary.isEmpty:
                return .fileImport(dataType: dataType)
            case .failure(let error) where error.errorType == .noData:
                return .fileImport(dataType: dataType)
            case .failure, .none:
                return .fileImport(dataType: dataType)
            case .success:
                continue
            }
        }
        return nil
    }

    func error(for dataType: DataType) -> (any DataImportError)? {
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

    var hasAnySummaryError: Bool {
        !summary.allSatisfy { $0.result.isSuccess }
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
                    Logger.dataImportExport.debug("progress: \(String(describing: update))")
                    return .progress(update)
                    // on completion returns new DataImportViewModel with merged import summary
                case .completed(.success(let summary)):
                    onFinished()
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
            where selectedDataTypes.subtracting(DataType.dataTypes(before: dataType, inclusive: true)).isEmpty
            // and no failures recorded - otherwise will skip to Feedback
            && !summary.contains(where: { !$0.result.isSuccess }):
            // no other data types to skip:
            return .cancel
        case .fileImport:
            return .skip

        case .summary(let dataTypes, isFileImport: _):
            if let screen = screenForNextDataTypeRemainingToImport(after: DataType.allCases.last(where: dataTypes.contains)) {
                return .next(screen)
            } else {
                return .next(.shortcuts(dataTypes))
            }

        case .feedback:
            return .submit
        case .shortcuts:
            return .done
        }
    }

    var secondaryButton: ButtonType? {
        if importTask == nil {
            switch screen {
            case importSource.initialScreen, .feedback:
                return .cancel
            case .moreInfo, .getReadPermission:
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
        self = .init(importSource: importSource, isPasswordManagerAutolockEnabled: isPasswordManagerAutolockEnabled, loadProfiles: loadProfiles, dataImporterFactory: dataImporterFactory, requestPrimaryPasswordCallback: requestPrimaryPasswordCallback, reportSenderFactory: reportSenderFactory, onFinished: onFinished, onCancelled: onCancelled)
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
            skipImportOrDismiss(using: dismiss)

        case .cancel:
            importTask?.cancel()
            onCancelled()
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

        Logger.dataImportExport.debug("dismiss")
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
            DataImportReportModel(importSource: importSource,
                                  importSourceVersion: importSource.installedAppsMajorVersionDescription(selectedProfile: selectedProfile),
                                  error: summarizedError,
                                  text: userReportText,
                                  retryNumber: retryNumber)
        }
        set {
            userReportText = newValue.text
        }
    }

}
