//
//  DataImportView.swift
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
import SwiftUI

@MainActor
struct DataImportView: ModalView {

    @Environment(\.dismiss) private var dismiss

    @State var model = DataImportViewModel()

    struct ProgressState {
        let text: String?
        let fraction: Double?
        let updated: CFTimeInterval
    }
    @State private var progress: ProgressState?

#if DEBUG || REVIEW
    @State private var debugViewDisabled: Bool = false
#endif

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            viewHeader()
                .padding(.top, 20)
                .padding(.leading, 20)
                .padding(.trailing, 20)

            viewBody()
                .padding(.leading, 20)
                .padding(.trailing, 20)
                .padding(.bottom, 32)

            // if import in progress…
            if let importProgress = model.importProgress {
                progressView(importProgress)
                    .padding(.leading, 20)
                    .padding(.trailing, 20)
                    .padding(.bottom, 8)
            }

            Divider()

            viewFooter()
                .padding(.top, 16)
                .padding(.bottom, 16)
                .padding(.trailing, 20)

#if DEBUG || REVIEW
            if !debugViewDisabled {
                debugView()
            }
#endif
        }
        .font(.system(size: 13))
        .frame(width: 512)
        .fixedSize()
    }

    private func viewHeader() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(UserText.importDataTitle)
                .bold()
                .padding(.bottom, 16)

            // browser to import data from picker popup
            if case .feedback = model.screen {} else {
                DataImportSourcePicker(importSources: model.availableImportSources, selectedSource: model.importSource) { importSource in
                    model.update(with: importSource)
                }
                .disabled(model.isImportSourcePickerDisabled)
                .padding(.bottom, 24)
            }
        }
    }

    private func viewBody() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // body
            switch model.screen {
            case .profileAndDataTypesPicker:
                // Browser Profile picker
                if model.browserProfiles?.validImportableProfiles.count ?? 0 > 1 {
                    DataImportProfilePicker(profileList: model.browserProfiles,
                                            selectedProfile: $model.selectedProfile)
                    .disabled(model.isImportSourcePickerDisabled)
                    .padding(.bottom, 24)
                }

                // Bookmarks/Passwords checkboxes
                DataImportTypePicker(viewModel: $model)
                    .disabled(model.isImportSourcePickerDisabled)

            case .moreInfo:
                // you will be asked for your keychain password blah blah...
                BrowserImportMoreInfoView(source: model.importSource)

            case .getReadPermission(let url):
                // give request to Safari folder, select Bookmarks.plist using open panel
                RequestFilePermissionView(source: model.importSource, url: url, requestDataDirectoryPermission: SafariDataImporter.requestDataDirectoryPermission) { _ in

                    model.initiateImport()
                }

            case .fileImport(let dataType, summary: let summaryTypes):
                if !summaryTypes.isEmpty {
                    DataImportSummaryView(model, dataTypes: summaryTypes)
                        .padding(.bottom, 24)
                }

                // if no data to import
                if model.summary(for: dataType)?.isEmpty == true
                    || model.error(for: dataType)?.errorType == .noData {

                    DataImportNoDataView(source: model.importSource, dataType: dataType)
                        .padding(.bottom, 24)

                // if browser importer failed - display error message
                } else if model.error(for: dataType) != nil {
                    DataImportErrorView(source: model.importSource, dataType: dataType)
                        .padding(.bottom, 24)
                }

                // manual file import instructions for CSV/HTML
                FileImportView(source: model.importSource, dataType: dataType, isButtonDisabled: model.isSelectFileButtonDisabled) {
                    model.selectFile()
                } onFileDrop: { url in
                    model.initiateImport(fileURL: url)
                }

            case .summary(let dataTypes, let isFileImport):
                DataImportSummaryView(model, dataTypes: dataTypes, isFileImport: isFileImport)

            case .feedback:
                DataImportSummaryView(model)
                .padding(.bottom, 20)

                ReportFeedbackView(model: $model.reportModel)
            }
        }
    }

    private func progressView(_ progress: TaskProgress<DataImportViewModel, Never, DataImportProgressEvent>) -> some View {
        // Progress bar with label: Importing [bookmarks|passwords]…
        ProgressView(value: self.progress?.fraction) {
            Text(self.progress?.text ?? "")
        }
        .task {
            // when model.importProgress async sequence not nil
            // receive progress updates events and update model on completion
            await handleImportProgress(progress)
        }
    }

    // under line buttons
    private func viewFooter() -> some View {
        HStack(spacing: 8) {
            Spacer()

            ForEach(model.buttons.indices, id: \.self) { idx in
                Button {
                    model.performAction(for: model.buttons[idx],
                                        dismiss: dismiss.callAsFunction)
                } label: {
                    Text(model.buttons[idx].title(dataType: model.screen.fileImportDataType))
                        .frame(minWidth: 80 - 16 - 1)
                }
                .keyboardShortcut(model.buttons[idx].shortcut)
                .disabled(model.buttons[idx].isDisabled)
            }
        }
    }

    private func handleImportProgress(_ progress: TaskProgress<DataImportViewModel, Never, DataImportProgressEvent>) async {
        // receive import progress update events
        // the loop is completed on the import task
        // cancellation/completion or on did disappear
        for await event in progress {
            switch event {
            case .progress(let progress):
                let currentTime = CACurrentMediaTime()
                // throttle progress updates
                if (self.progress?.updated ?? 0) < currentTime - 0.2 {
                    self.progress = .init(text: progress.description,
                                          fraction: progress.fraction,
                                          updated: currentTime)
                }

                // update view model on completion
            case .completed(.success(let newModel)):
                self.model = newModel
            }
        }
    }

#if DEBUG || REVIEW
    private func debugView() -> some View {

        VStack(alignment: .leading, spacing: 10) {
            Divider()

            HStack {
                Text("REVIEW:" as String).bold()
                    .padding(.top, 10)
                    .padding(.leading, 20)
                Spacer()
                if case .normal = NSApp.runType {
                    Button {
                        debugViewDisabled.toggle()
                    } label: {
                        Image(.closeLarge)
                    }
                        .buttonStyle(.borderless)
                        .padding(.trailing, 20)
                }
            }

            ForEach(DataImport.DataType.allCases.filter(model.selectedDataTypes.contains), id: \.self) { selectedDataType in
                failureReasonPicker(for: selectedDataType)
                    .padding(.leading, 20)
                    .padding(.trailing, 20)
            }
        }
        .padding(.bottom, 10)
        .background(Color(NSColor(red: 1, green: 0, blue: 0, alpha: 0.2)))
    }

    private var noFailure: String { "No failure" }
    private var zeroSuccess: String { "Success (0 imported)" }
    private var allFailureReasons: [String?] {
        [noFailure, zeroSuccess, nil] + DataImport.ErrorType.allCases.map { $0.rawValue }
    }

    private func failureReasonPicker(for dataType: DataImport.DataType) -> some View {
        Picker(selection: Binding {
            allFailureReasons.firstIndex(where: { failureReason in
                model.testImportResults[dataType]?.error?.errorType.rawValue == failureReason
                || (failureReason == zeroSuccess && model.testImportResults[dataType] == .success(.empty))
                || (failureReason == noFailure && model.testImportResults[dataType] == nil)
            })!
        } set: { newValue in
            let reason = allFailureReasons[newValue]!
            switch reason {
            case noFailure: model.testImportResults[dataType] = nil
            case zeroSuccess: model.testImportResults[dataType] = .success(.empty)
            default:
                let errorType = DataImport.ErrorType(rawValue: reason)!
                let error = DataImportViewModel.TestImportError(action: dataType.importAction, errorType: errorType)
                model.testImportResults[dataType] = .failure(error)
            }
        }) {
            ForEach(allFailureReasons.indices, id: \.self) { idx in
                if let failureReason = allFailureReasons[idx] {
                    Text(failureReason)
                } else {
                    Divider()
                }
            }
        } label: {
            Text("\(dataType.displayName) import error:" as String)
                .frame(width: 150, alignment: .leading)
        }
    }
#endif

}

extension DataImportProgressEvent {

    var fraction: Double? {
        switch self {
        case .initial:
            nil
        case .importingBookmarks(numberOfBookmarks: _, fraction: let fraction):
            fraction
        case .importingPasswords(numberOfPasswords: _, fraction: let fraction):
            fraction
        case .done:
            nil
        }
    }

    var description: String? {
        switch self {
        case .initial:
            nil
        case .importingBookmarks(numberOfBookmarks: let num, fraction: _):
            UserText.importingBookmarks(num)
        case .importingPasswords(numberOfPasswords: let num, fraction: _):
            UserText.importingPasswords(num)
        case .done:
            nil
        }
    }

}

extension DataImportViewModel.ButtonType {

    var shortcut: KeyboardShortcut? {
        switch self {
        case .next: .defaultAction
        case .initiateImport: .defaultAction
        case .skip: .cancelAction
        case .cancel: .cancelAction
        case .back: nil
        case .done: .defaultAction
        case .submit: .defaultAction
        }
    }

}

extension DataImportViewModel.ButtonType {

    func title(dataType: DataImport.DataType?) -> String {
        switch self {
        case .next:
            UserText.next
        case .initiateImport:
            UserText.initiateImport
        case .skip:
            switch dataType {
            case .bookmarks:
                UserText.skipBookmarksImport
            case .passwords:
                UserText.skipPasswordsImport
            case nil:
                UserText.skip
            }
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

#Preview { {

    final class PreviewPreferences: ObservableObject {
        @Published var shouldDisplayProgress = false
        static let shared = PreviewPreferences()
    }

    final class MockDataImporter: DataImporter {

        struct MockError: Error { }

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
        let source: DataImport.Source
        var dataType: DataImport.DataType?
        var importableTypes: [DataImport.DataType] {
            [.safari, .yandex].contains(source) && dataType == nil ? [.bookmarks] : [.bookmarks, .passwords]
        }

        func validateAccess(for types: Set<DataImport.DataType>) -> [DataImport.DataType: any DataImportError]? {
            source == .firefox && types.contains(.passwords) ? [.passwords: FirefoxLoginReader.ImportError(type: .requiresPrimaryPassword, underlyingError: nil)] : nil
        }

        func requiresKeychainPassword(for selectedDataTypes: Set<DataImport.DataType>) -> Bool {
            source == .chrome && selectedDataTypes.contains(.passwords) ? true : false
        }

        init(source: DataImport.Source, dataType: DataImport.DataType? = nil) {
            self.source = source
            self.dataType = dataType
        }

        // swiftlint:disable:next function_body_length
        func importData(types: Set<DataImport.DataType>) -> DataImportTask {
            .detachedWithProgress(.initial) { progressUpdate in
                func makeProgress(_ op: (Double) throws -> Void) async throws {
                    guard PreviewPreferences.shared.shouldDisplayProgress else { return }
                    let n = 20
                    for i in 0..<n {
                        let ticksInS = 1.0 / Double(n)
                        try op(Double(i) / ticksInS)
                        try await Task.sleep(interval: ticksInS)
                    }
                }
                print("importing 1")
                do {
                    if types.contains(.bookmarks) {
                        try await makeProgress { fraction in
                            try progressUpdate(
                                .importingBookmarks(
                                    numberOfBookmarks: nil,
                                    fraction: fraction
                                )
                            )
                        }

                        try await makeProgress { fraction in
                            try progressUpdate(
                                .importingBookmarks(
                                    numberOfBookmarks: 42,
                                    fraction: fraction
                                )
                            )
                        }
                    }

                    if types.contains(.passwords) {
                        print("importing 3")
                        try await makeProgress { fraction in
                            try progressUpdate(
                                .importingPasswords(
                                    numberOfPasswords: nil,
                                    fraction: fraction
                                )
                            )
                        }
                        print("importing 4")
                        try await makeProgress { fraction in
                            try progressUpdate(
                                .importingPasswords(
                                    numberOfPasswords: 2442,
                                    fraction: fraction
                                )
                            )
                        }
                    }
                    print("importing done")
                    try progressUpdate(
                        .done
                    )

                    var result = DataImportSummary()
                    for type in types {
                        result[type] = .success(.init(successful: Int.random(in: 0..<100000), duplicate: 0, failed: 0))
                    }
                    return result

                } catch {
                    print("import cancelled", error)
                    return types.reduce(into: [:]) { $0[$1] = .failure(ImportError.err(error)) }
                }
            }
        }
    }

    let viewModel = DataImportViewModel(importSource: .bookmarksHTML, availableImportSources: DataImport.Source.allCases) { browser in
        guard case .chrome = browser else {
            print("empty profiles")
            return .init(browser: browser, profiles: [])
        }
        print("chrome profiles")
        return .init(browser: browser, profiles: [
            .init(browser: .chrome,
                  profileURL: URL(fileURLWithPath: "/test/Default Profile")),
            .init(browser: .chrome,
                  profileURL: URL(fileURLWithPath: "/test/Profile 1")),
            .init(browser: .chrome,
                  profileURL: URL(fileURLWithPath: "/test/Profile 2"))
        ], validateProfileData: { _ in { .init(logins: .available, bookmarks: .available) } // swiftlint:disable:this opening_brace
        })
    } dataImporterFactory: { source, type, _, _ in
        return MockDataImporter(source: source, dataType: type)
    } requestPrimaryPasswordCallback: { _ in
        print("primary password requested")
        return "password"
    } openPanelCallback: { _ in
        URL(fileURLWithPath: "/test/path")
    } reportSenderFactory: {
        { feedback in
            print("send feedback:", feedback)
        }
    }

    struct PreviewPreferencesView: View {
        @ObservedObject var prefs = PreviewPreferences.shared

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Toggle("Display progress", isOn: $prefs.shouldDisplayProgress)
                        .padding(.leading, 20)
                        .padding(.bottom, 20)
                    Spacer()
                }
            }
            .frame(width: 512)
            .background(Color(NSColor(red: 1, green: 0, blue: 0, alpha: 0.2)))
        }
    }

    return VStack(alignment: .leading, spacing: 0) {
        DataImportView(model: viewModel)
            // swiftlint:disable:next force_cast
            .environment(\EnvironmentValues.presentationMode as! WritableKeyPath,
                          Binding<PresentationMode> {
                print("DISMISS!")
            })

        PreviewPreferencesView()
        Spacer()
    }
    .frame(minHeight: 666)

}() }
