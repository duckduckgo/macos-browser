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

    typealias FeedbackSenderFactory = () -> (Feedback) -> Void
    /// Factory for a DataImporter for importSource
    private let feedbackSenderFactory: FeedbackSenderFactory

    enum Screen: Hashable {
        case profileAndDataTypesPicker
        case moreInfo
        case getReadPermission(URL)
        case fileImport(DataType)
        case fileImportSummary(DataType)
        case summary
        case feedback(String = "")

        var fileImportDataType: DataType? {
            if case .fileImport(let dataType) = self { return dataType }
            return nil
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

    typealias DataImportViewSummary = [(dataType: DataImport.DataType, result: DataImportResult<DataImport.DataTypeSummary>)]
    /// collected import summary for current import operation per selected import source
    private(set) var summary = DataImportViewSummary()

    init(importSource: Source? = nil,
         loadProfiles: @escaping (ThirdPartyBrowser) -> BrowserProfileList = { $0.browserProfiles() },
         dataImporterFactory: @escaping DataImporterFactory = dataImporter,
         requestPrimaryPasswordCallback: @escaping @MainActor (Source) -> String? = Self.requestPrimaryPasswordCallback,
         openPanelCallback: @escaping @MainActor (DataType) -> URL? = Self.openPanelCallback,
         feedbackSenderFactory: @escaping FeedbackSenderFactory = { FeedbackSender().sendFeedback }) {

        let importSource = importSource ?? ThirdPartyBrowser.installedBrowsers.first?.importSource ?? .csv

        self.importSource = importSource
        self.loadProfiles = loadProfiles
        self.dataImporterFactory = dataImporterFactory

        self.screen = importSource.initialScreen

        self.browserProfiles = ThirdPartyBrowser.browser(for: importSource).map(loadProfiles)
        self.selectedProfile = browserProfiles?.defaultProfile

        self.selectedDataTypes = importSource.supportedDataTypes
        self.requestPrimaryPasswordCallback = requestPrimaryPasswordCallback

        self.openPanelCallback = openPanelCallback
        self.feedbackSenderFactory = feedbackSenderFactory
    }

    /// Import button press (starts browser data import)
    @MainActor
    mutating func initiateImport(primaryPassword: String? = nil, fileURL: URL? = nil) {
        guard let url = fileURL ?? selectedProfile?.profileURL else {
            assertionFailure("URL not provided")
            return
        }

        // are we handling file import or browser selected data types import?
        let dataType: DataType? = self.screen.fileImportDataType
        let dataTypes = dataType.map { [$0] } ?? selectedDataTypes
        let importer = dataImporterFactory(importSource, dataType, url, primaryPassword)

        os_log(.debug, log: .dataImportExport, "import \(dataTypes) at \"\(url.path)\" using \(type(of: importer))")

        // validate file access/encryption password requirement before starting import
        if let errors = importer.validateAccess(for: dataTypes),
           handleErrors(errors) == true {
            return
        }

        importTask = importer.importData(types: dataTypes)
    }

    /// Called with data import task result to update the state by merging the summary with an existing summary
    @MainActor
    private mutating func mergeImportSummary(with summary: DataImportSummary) {
        self.importTask = nil

        os_log(.debug, log: .dataImportExport, "merging summary \(summary)")

        if handleErrors(summary.compactMapValues { $0.error }) { return }

        // merge new import results into the model import summary
        for (dataType, result) in summary {
            self.summary.append( (dataType, result) )

            if case .failure(let error) = result {
                Pixel.fire(.dataImportFailed(error))
            }
        }

        if self.areAllSelectedDataTypesSuccessfullyImported {
            NotificationCenter.default.post(name: .dataImportComplete, object: nil)
        }

        self.screen = nextScreen()
        os_log(.debug, log: .dataImportExport, "next screen: \(screen)")
    }

    /// handle recoverable errors (request primary password or file permission)
    @MainActor
    private mutating func handleErrors(_ summary: [DataType: any DataImportError]) -> Bool {
        for error in summary.values {
            switch error {
            // firefox passwords db is master-password protected: request password
            case let error as FirefoxLoginReader.ImportError where error.type == .requiresPrimaryPassword:

                os_log(.debug, log: .dataImportExport, "primary password required")
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
                os_log(.debug, log: .dataImportExport, "file read no permission for \(url.path)")
                screen = .getReadPermission(url)
                return true

            default: continue
            }
        }
        return false
    }

    /// returns next screen after import competion (or after Skip button press)
    private func nextScreen(skip: Bool = false) -> Screen {
        switch screen {
        case .profileAndDataTypesPicker, .moreInfo, .getReadPermission:
            if let dataType = nextDataTypeRemainingToImport() {
                return .fileImport(dataType)
            }

        case .fileImport(let dataType),
             .fileImportSummary(let dataType):
            // all remaining DataTypes in fixed sort order after current file import data type
            if let nextDataType = nextDataTypeRemainingToImport(after: dataType) {
                // show File Import summary if there‘s next File Import ahead
                if case .fileImport = screen,
                   // and not the Skip button was pressed
                   !skip,
                   // and file import operation was successful
                   // - otherwise will display report afterwards
                    isDataTypeSuccessfullyImported(dataType) {
                    return .fileImportSummary(dataType)
                }
                return .fileImport(nextDataType)
            }

        case .summary, .feedback:
            break
        }
        // all done
        for (_, result) in summary {
            if case .failure = result {
                return .feedback()
            }
        }
        return .summary
    }

    /// Skip button press
    @MainActor private mutating func skipImport() {
        self.screen = nextScreen(skip: true)
    }

    /// Select CSV/HTML file for import button press
    @MainActor mutating func selectFile() {
        guard case .fileImport(let dataType) = screen else {
            assertionFailure("Expected File Import")
            return
        }
        guard let url = openPanelCallback(dataType) else { return }

        self.initiateImport(fileURL: url)
    }

    func submitReport() {
        guard case .feedback(let comment) = screen else {
            assertionFailure("wrong screen \(screen)")
            return
        }
        let sendFeedback = feedbackSenderFactory()
        sendFeedback(Feedback(category: .dataImport,
                              // TODO: import source version
                              comment: comment.trimmingWhitespace() + "\n\n---\n\n" + summarizedError.localizedDescription,
                              appVersion: "\(AppVersion.shared.versionNumber)",
                              osVersion: "\(ProcessInfo.processInfo.operatingSystemVersion)"))
    }

}

@MainActor
private func dataImporter(for source: DataImport.Source, fileDataType: DataImport.DataType?, url: URL, primaryPassword: String?) -> DataImporter {

    switch source {
    case .bookmarksHTML,
        _ where fileDataType == .bookmarks:

        BookmarkHTMLImporter(fileURL: url, bookmarkImporter: CoreDataBookmarkImporter(bookmarkManager: LocalBookmarkManager.shared))

    case .onePassword8, .onePassword7, .bitwarden, .lastPass, .csv,
        _ where fileDataType == .passwords:
        CSVImporter(fileURL: url, loginImporter: SecureVaultLoginImporter(), defaultColumnPositions: .init(source: source))

    case .brave, .chrome, .chromium, .coccoc, .edge, .opera, .operaGX, .vivaldi:
        ChromiumDataImporter(source: source,
                             profileURL: url,
                             loginImporter: SecureVaultLoginImporter(),
                             bookmarkImporter: CoreDataBookmarkImporter(bookmarkManager: LocalBookmarkManager.shared))
    case .yandex:
        YandexDataImporter(profileURL: url,
                           bookmarkImporter: CoreDataBookmarkImporter(bookmarkManager: LocalBookmarkManager.shared))
    case .firefox, .tor:
        FirefoxDataImporter(source: source,
                            profileURL: url,
                            primaryPassword: primaryPassword,
                            loginImporter: SecureVaultLoginImporter(),
                            bookmarkImporter: CoreDataBookmarkImporter(bookmarkManager: LocalBookmarkManager.shared),
                            faviconManager: FaviconManager.shared)
    case .safari, .safariTechnologyPreview:
        SafariDataImporter(source: source,
                           profileURL: url,
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
                .operaGX, .safari, .safariTechnologyPreview, .tor, .vivaldi,
                .yandex:
            return .profileAndDataTypesPicker
        case .onePassword8, .onePassword7, .bitwarden, .lastPass, .csv:
            return .fileImport(.passwords)
        case .bookmarksHTML:
            return .fileImport(.bookmarks)
        }
    }

}

extension DataImport.DataType {

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

    private func nextDataTypeRemainingToImport(after currentDataType: DataType? = nil) -> DataType? {
        // keep the original sort order
        (currentDataType.map { DataType.dataTypes(after: $0) } ?? DataType.allCases[0...]) // among all data types or only after some?
        .first(where: { dataType in
            // if some of selected data types failed to import or not imported yet
            selectedDataTypes.contains(dataType) && !isDataTypeSuccessfullyImported(dataType)
        })
    }

    private func isDataTypeSuccessfullyImported(_ dataType: DataType) -> Bool {
        summary.reversed().contains(where: { (summaryDataType, result) in
            dataType == summaryDataType && result.isSuccess
        })
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
        for (summaryDataType, result) in summary.reversed() where summaryDataType == dataType {
            switch result {
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
                    os_log(.debug, log: .dataImportExport, "progress: \(update)")
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
        case next(Screen), initiateImport, skip, cancel, back, done, submit
    }

    @MainActor var actionButton: ButtonType? {
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
                    return .initiateImport
                }
                // use CSV/HTML file import
                return .next(.fileImport(type))
            }

            if importer.requiresKeychainPassword(for: selectedDataTypes) {
                return .next(.moreInfo)
            }
            return .initiateImport

        case .moreInfo, .getReadPermission:
            return .initiateImport

        case .fileImport:
            if case .summary = nextScreen(skip: true) {
                return secondaryButton == .back ? .cancel : nil
            }
            return .skip

        case .fileImportSummary:
            if case .summary = nextScreen() {
                return .done
            }
            return .next(nextScreen())

        case .summary:
            return .done

        case .feedback:
            return .submit
        }
    }

    @MainActor var isActionButtonDisabled: Bool {
        guard importTask == nil else { return true }

        switch actionButton {
        case .next:
            return false
        case .initiateImport:
            if case .getReadPermission = screen {
                return true
            } else if selectedDataTypes.isEmpty {
                return true
            }
        default: break
        }
        return false
    }

    var secondaryButton: ButtonType? {
        if importTask == nil {
            switch screen {
            case importSource.initialScreen, .feedback:
                return .cancel
            default:
                return .back
            }
        } else {
            return .cancel
        }
    }
    var isSecondaryButtonDisabled: Bool {
        false
    }

    @MainActor
    var buttons: [(type: ButtonType, isDisabled: Bool)] {
        [
            secondaryButton.map { (type: $0, isDisabled: isSecondaryButtonDisabled) },
            actionButton.map { (type: $0, isDisabled: isActionButtonDisabled) },
        ].compactMap { $0 }
    }

    mutating func update(with importSource: Source) {
        self = .init(importSource: importSource, loadProfiles: loadProfiles, dataImporterFactory: dataImporterFactory, requestPrimaryPasswordCallback: requestPrimaryPasswordCallback, feedbackSenderFactory: feedbackSenderFactory)
    }

    @MainActor
    mutating func performAction(for buttonType: ButtonType, dismiss: @escaping () -> Void) {
        let dismissView = { [summary] in
            // send `bookmarkPromptShouldShow` notification after dismiss if at least one bookmark was imported
            if summary.reduce(into: 0, { $0 += $1.dataType == .bookmarks ? (try? $1.result.get().successful) ?? 0 : 0 }) > 0 {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .bookmarkPromptShouldShow, object: nil)
                }
            }

            dismiss()
        }

        switch buttonType {
        case .next(let screen):
            self.screen = screen
        case .back:
            // reset to initial screen
            screen = importSource.initialScreen
            summary.removeAll()

        case .initiateImport:
            initiateImport()
        case .skip:
            skipImport()

        case .cancel:
            // TODO: cancel importer adding to database on Task cancel
            importTask?.cancel()
            dismissView()

        case .submit:
            submitReport()
            dismissView()
        case .done:
            dismissView()
        }
    }

    @MainActor
    private func mergingImportSummary(_ summary: DataImportSummary) -> Self {
        var newState = self
        newState.mergeImportSummary(with: summary)
        return newState
    }

    mutating func updateFeedbackComment(_ comment: String) {
        self.screen = .feedback(comment)
    }

}

extension DataImportViewModel.ButtonType {

    var title: String {
        switch self {
        case .next:
            UserText.next
        case .initiateImport:
            UserText.initiateImport
        case .skip:
            UserText.skipImport
        case .cancel:
            UserText.cancel
        case .back:
            UserText.navigateBack
        case .done:
            UserText.done
        case .submit:
            UserText.submitReport
        }
    }

}
