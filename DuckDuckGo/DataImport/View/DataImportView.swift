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

extension DataImportView {

    @MainActor
    static func show(completion: (() -> Void)? = nil) {
        guard let window = WindowControllersManager.shared.lastKeyMainWindowController?.window else { return }

        if !window.isKeyWindow {
            window.makeKeyAndOrderFront(nil)
        }

        let sheetWindow = SheetHostingWindow(rootView: DataImportView())

        window.beginSheet(sheetWindow, completionHandler: completion.map { completion in
            { _ in
                completion()
            }
        })
    }

}

struct DataImportView: View {

    @Environment(\.dismiss) private var dismiss

    @State var viewModel = DataImportViewModel()

    @State private var progressText: String?
    @State private var progressFraction: Double?

    private func feedbackComment() -> Binding<String> {
        Binding {
            guard case .feedback(let comment) = viewModel.screen else {
                assertionFailure("wrong screen")
                return ""
            }
            return comment
        } set: {
            viewModel.updateFeedbackComment($0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Import Browser Data")
                .font(.headline)
            Spacer().frame(height: 10)

            // browser to import data from picker popup
            if case .feedback = viewModel.screen {} else {
                DataImportSourcePicker(selectedSource: viewModel.importSource) { importSource in
                    viewModel.update(with: importSource)
                }
                .disabled(viewModel.isImportSourcePickerDisabled)
            }

            Spacer().frame(height: 16)

            // body
            switch viewModel.screen {
            case .profileAndDataTypesPicker:
                // Browser Profile picker
                DataImportProfilePicker(profileList: viewModel.browserProfiles,
                                        selectedProfile: $viewModel.selectedProfile)
                    .disabled(viewModel.isImportSourcePickerDisabled)

                Spacer().frame(height: 16)

                // Bookmarks/Passwords checkboxes
                DataImportTypePicker(viewModel: $viewModel)
                    .disabled(viewModel.isImportSourcePickerDisabled)

            case .moreInfo:
                // you will be asked for your keychain password blah blah...
                BrowserImportMoreInfoView(source: viewModel.importSource)

            case .getReadPermission(let url):
                // give request to Safari folder, select Bookmarks.plist using open panel
                RequestFilePermissionView(source: viewModel.importSource, url: url, requestDataDirectoryPermission: SafariDataImporter.requestDataDirectoryPermission) { _ in

                    viewModel.initiateImport()
                }

            case .fileImport(let dataType):
                // if browser importer failed - display error message
                if viewModel.hasDataTypeImportFailed(dataType) {
                    Text("We were unable to import directly from \(viewModel.importSource.importSourceName).")
                        .font(.headline)
                    Spacer().frame(height: 8)
                    Text("Let’s try doing it manually. It won’t take long.")
                    Spacer().frame(height: 24)
                }

                // manual file import instructions for CSV/HTML
                FileImportView(source: viewModel.importSource, dataType: dataType, isButtonDisabled: viewModel.isSelectFileButtonDisabled) {
                    viewModel.selectFile()
                }

            case .fileImportSummary(let dataType):
                // present file impoter import summary for one data type
                Text("\(dataType.displayName) Import Complete")
                    .font(.headline)
                Spacer().frame(height: 12)
                DataImportSummaryView(summary: (
                    try? viewModel.summary.last(where: {
                        $0.dataType == dataType
                    })?.result.get()
                ).map { [dataType: $0] } ?? [:])

            case .summary:
                // total import summary
                Text("Import Complete")
                    .font(.headline)
                Spacer().frame(height: 12)

                // import completed
                DataImportSummaryView(summary: viewModel.summary.reduce(into: [:]) {
                    $0[$1.dataType] = try? $1.result.get()
                })

            case .feedback:
                ReportFeedbackView(text: feedbackComment(), 
                                   retryNumber: viewModel.summary.reduce(into: [:]) {
                                       // get maximum number of failures per data type
                                       $0[$1.dataType, default: 0] += $1.result.isSuccess ? 0 : 1
                                   }.values.max() ?? 0,
                                   importSource: viewModel.importSource,
                                   error: viewModel.summarizedError)
            }

            // Import in progress…
            if let importProgress = viewModel.importProgress {
                Spacer().frame(height: 24)

                // Progress bar with label: Importing [bookmarks|passwords]…
                ProgressView(value: progressFraction) {
                    Text(progressText ?? "")
                }
                .task {
                    // when viewModel.importProgress async sequence not nil
                    // receive progress updates events and update model on completion
                    await handleImportProgress(importProgress)
                }

            }

            Spacer().frame(height: 32)
            Divider()
            Spacer().frame(height: 24)

            // under line buttons
            HStack {
                Spacer()

                ForEach(viewModel.buttons, id: \.type) { button in
                    Button(button.type.title) {
                        viewModel.performAction(for: button.type, dismiss: dismiss.callAsFunction)
                    }
                    .keyboardShortcut(button.type.shortcut)
                    .disabled(button.isDisabled)
                }
            }
        }
        .padding(EdgeInsets(top: 20, leading: 20, bottom: 16, trailing: 20))
        .frame(width: 512)
        .fixedSize()
    }

    private func handleImportProgress(_ progress: TaskProgress<DataImportViewModel, Never, DataImportProgressEvent>) async {
        // receive import progress update events
        // the loop is completed on the import task
        // cancellation/completion or on did disappear
        for await event in progress {
            switch event {
            case .progress(let progress):
                progressText = progress.description
                progressFraction = progress.fraction

            // update view model on completion
            case .completed(.success(let viewModel)):
                self.viewModel = viewModel
            }
        }
    }

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

#Preview { {

    final class PreviewPreferences: ObservableObject {
        @Published var shouldBookmarkImportFail = false
        @Published var shouldPasswordsImportFail = false
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
            var source: DataImport.Source { .chrome }
            var action: DataImportAction { .generic }
            var underlyingError: Error? {
                if case .err(let err) = self {
                    return err
                }
                return nil
            }

            case err(Error)
        }
        let source: DataImport.Source
        var dataType: DataImport.DataType?
        var importableTypes: [DataImport.DataType] {
            [.safari, .yandex].contains(source) && dataType == nil ? [.bookmarks] : [.bookmarks, .passwords]
        }

        func validateAccess(for types: Set<DataImport.DataType>) -> [DataImport.DataType: any DataImportError]? {
            source == .firefox && types.contains(.passwords) ? [.passwords: FirefoxLoginReader.ImportError(source: .firefox, type: .requiresPrimaryPassword, underlyingError: nil)] : nil
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
                        if (type == .bookmarks && PreviewPreferences.shared.shouldBookmarkImportFail)
                            || (type == .passwords && PreviewPreferences.shared.shouldPasswordsImportFail) {
                            result[type] = .failure(ImportError.err(MockError()))
                        } else {
                            result[type] = .success(.init(successful: Int.random(in: 0..<100000), duplicate: Int.random(in: 0..<100000), failed: Int.random(in: 0..<100000)))
                        }
                    }
                    return result

                } catch {
                    print("import cancelled", error)
                    return types.reduce(into: [:]) { $0[$1] = .failure(ImportError.err(error)) }
                }
            }
        }
    }

    let viewModel = DataImportViewModel(importSource: .chrome) { browser in
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
                  profileURL: URL(fileURLWithPath: "/test/Profile 2")),
        ])
    } dataImporterFactory: { source, type, _, _ in
        return MockDataImporter(source: source, dataType: type)
    } requestPrimaryPasswordCallback: { _ in
        print("primary password requested")
        return "password"
    } openPanelCallback: { _ in
        URL(fileURLWithPath: "/test/path")
    } feedbackSenderFactory: { 
        { feedback in
            print("send feedback:", feedback)
        }
    }

    struct PreviewPreferencesView: View {
        @ObservedObject var prefs = PreviewPreferences.shared

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Bookmarks import should fail", isOn: $prefs.shouldBookmarkImportFail)
                Toggle("Passwords import should fail", isOn: $prefs.shouldPasswordsImportFail)
                Toggle("Display progress", isOn: $prefs.shouldDisplayProgress)
            }
            .padding(EdgeInsets(top: 0, leading: 20, bottom: 10, trailing: 10))
        }
    }

    return VStack {
        DataImportView(viewModel: viewModel)
            // swiftlint:disable:next force_cast
            .environment(\EnvironmentValues.presentationMode as! WritableKeyPath,
                          Binding<PresentationMode> { print("DISMISS!") })

        VStack(alignment: .leading, spacing: 10) {
            Spacer()
            Divider().frame(width: 512)
            PreviewPreferencesView()

        }.background(Color(NSColor(red: 1, green: 0, blue: 0, alpha: 0.3)))
    }
    .frame(minHeight: 500)

}() }
