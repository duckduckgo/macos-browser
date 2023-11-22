//
//  FileImportView.swift
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
import SwiftUI
import UniformTypeIdentifiers

struct FileImportView: View {

    let source: DataImport.Source
    let dataType: DataImport.DataType
    let action: () -> Void
    let onFileDrop: (URL) -> Void
    private let instructions: [[FileImportInstructionsItem]]

    private var isButtonDisabled: Bool

    init(source: DataImport.Source, dataType: DataImport.DataType, isButtonDisabled: Bool, action: (() -> Void)? = nil, onFileDrop: ((URL) -> Void)? = nil) {
        self.source = source
        self.dataType = dataType
        self.action = action ?? {}
        self.onFileDrop = onFileDrop ?? { _ in }
        self.instructions = Self.instructions(for: source, dataType: dataType)
        self.isButtonDisabled = isButtonDisabled
    }

    // swiftlint:disable:next function_body_length
    private static func instructions(for source: DataImport.Source, dataType: DataImport.DataType) -> [[FileImportInstructionsItem]] {
        buildInstructions {
            switch (source, dataType) {
            case (.brave, .passwords),
                (.chrome, .passwords),
                (.chromium, .passwords),
                (.coccoc, .passwords),
                (.edge, .passwords),
                (.vivaldi, .passwords),
                (.opera, .passwords),
                (.operaGX, .passwords):

                1; "Open **\(source.importSourceName)**"
                2; "In a fresh tab, click \(Image(.menuVertical16)) then **\(source == .chrome ? "Google " : "")Password Manager  → Settings**"
                3; "Find “Export Passwords” and click **Download File**"
                4; "Save the passwords file someplace you can find it (e.g. Desktop)"
                5; .button("Select Passwords CSV File…")

            case (.yandex, .passwords):
                1; "Open **Yandex**"
                2; "Click \(Image(.menuHamburger16)) to open the application menu then click **Passwords and cards**"
                3; "Click \(Image(.menuVertical16)) then **Export passwords**"
                4; "Choose **To a text file (not secure)** and click **Export**"
                5; "Save the passwords file someplace you can find it (e.g. Desktop)"
                6; .button("Select Passwords CSV File…")

            case (.brave, .bookmarks),
                (.chrome, .bookmarks),
                (.chromium, .bookmarks),
                (.coccoc, .bookmarks),
                (.edge, .bookmarks),
                (.vivaldi, .bookmarks),
                (.opera, .bookmarks),
                (.operaGX, .bookmarks):
                1; "Open **\(source.importSourceName)**"
                2; "Use the Menu Bar to select **Bookmarks → Bookmark Manager**"
                3; "Click \(Image(.menuVertical16)) then **Export Bookmarks**"
                4; "Save the file someplace you can find it (e.g., Desktop)"
                5; .button("Select Bookmarks HTML File…")

            case (.yandex, .bookmarks):
                1; "Open **\(source.importSourceName)**"
                2; "Use the Menu Bar to select **Favorites → Bookmark Manager**"
                3; "Click \(Image(.menuVertical16)) then **Export bookmarks to HTML file**"
                4; "Save the file someplace you can find it (e.g., Desktop)"
                5; .button("Select Bookmarks HTML File…")
            case (.safari, .passwords), (.safariTechnologyPreview, .passwords):
                1; "Open **Safari**"
                2; "Select **File → Export → Passwords**"
                3; "Save the passwords file someplace you can find it (e.g. Desktop)"
                4; .button("Select Passwords CSV File…")

            case (.safari, .bookmarks), (.safariTechnologyPreview, .bookmarks):
                1; "Open **Safari**"
                2; "Select **File → Export → Bookmarks**"
                3; "Save the passwords file someplace you can find it (e.g. Desktop)"
                4; .button("Select Bookmarks HTML File…")

            case (.firefox, .passwords):
                1; "Open **\(source.importSourceName)**"
                2; "Click \(Image(.menuHamburger16)) to open the application menu then click **Passwords**"
                3; "Click \(Image(.menuVertical16)) then **Export Logins…**"
                4; "Save the passwords file someplace you can find it (e.g. Desktop)"
                5; .button("Select Passwords CSV File…")

            case (.firefox, .bookmarks), (.tor, .bookmarks):
                1; "Open **\(source.importSourceName)**"
                2; "Use the Menu Bar to select **Bookmarks → Manage Bookmarks**"
                3; "Click \(Image(.importExport16)) then **Export bookmarks to HTML…**"
                4; "Save the file someplace you can find it (e.g., Desktop)"
                5; .button("Select Bookmarks HTML File…")

            case (.onePassword8, .passwords):
                1; "Open and unlock **\(source.importSourceName)**"
                2; "Select **File → Export** from the Menu Bar and choose the account you want to export"
                3; "Enter your 1Password account password"
                4; "Select the File Format: **CSV (Logins and Passwords only)**"
                5; "Click Export Data and save the file someplace you can find it (e.g. Desktop)"
                6; .button("Select 1Password CSV File…")
            case (.onePassword7, .passwords):
                1; "Open and unlock **\(source.importSourceName)**"
                2; "Select the vault you want to Export (You cannot export from “All Vaults.”)"
                3; "Select **File → Export → All Items** from the Menu Bar"
                4; "Enter your 1Password master or account password"
                5; "Select the File Format: **iCloud Keychain (.csv)**"
                6; "Save the passwords file someplace you can find it (e.g. Desktop)"
                7; .button("Select 1Password CSV File…")
            case (.bitwarden, .passwords):
                1; "Open and unlock **\(source.importSourceName)**"
                2; "Select **File → Export vault** from the Menu Bar"
                3; "Select the File Format: **.csv**"
                4; "Enter your Bitwarden Master password"
                5; "Click \(Image(systemName: "square.and.arrow.down")) and save the file someplace you can find it (e.g. Desktop)"
                6; .button("Select Bitwarden CSV File…")

            case (.lastPass, .passwords):
                1; "Click on the **\(source.importSourceName)** icon in your browser and enter your master password"
                2; "Select **Open My Vault**"
                3; "From the sidebar select **Advanced Options → Export**"
                4; "Enter your LastPass master password"
                5; "Select the File Format: Comma Delimited Text (.csv)"
                6; .button("Select LastPass CSV File…")
            case (.csv, .passwords):
                """
                The CSV importer will try to match column headers to their position.
                If there is no header, it supports two formats:
                """
                1; "URL, Username, Password"
                2; "Title, URL, Username, Password";

                .button("Select Passwords CSV File…")

            case (.bookmarksHTML, .bookmarks):
                1; "Open your old browser"
                2; "Click \(Image(.menuHamburger16)) then select **Bookmarks → Bookmark Manager**"
                3; "Click \(Image(.menuVertical16)) then **Export bookmarks to HTML…**"
                4; "Save the file someplace you can find it (e.g., Desktop)"
                5; .button("Select Bookmarks HTML File…")

            case (.bookmarksHTML, .passwords),
                (.tor, .passwords),
                (.onePassword7, .bookmarks),
                (.onePassword8, .bookmarks),
                (.bitwarden, .bookmarks),
                (.lastPass, .bookmarks),
                (.csv, .bookmarks):
                {
                    assertionFailure("Invalid source/dataType")
                    return ""
                }()
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            {
                switch dataType {
                case .bookmarks:
                    Text("Import Bookmarks")
                case .passwords:
                    Text("Import Passwords")
                }
            }().font(.headline)

            ForEach(instructions.indices, id: \.self) { i in
                HStack(spacing: 4) {
                    ForEach(instructions[i].indices, id: \.self) { j in
                        switch instructions[i][j] {
                        case .number(let number):
                            CircleNumberView(number: number)
                        case .text(let localizedStringKey):
                            Text(localizedStringKey)
                        case .button(let localizedTitleKey):
                            Button(localizedTitleKey, action: action)
                                .onDrop(of: dataType.allowedFileTypes, isTargeted: nil, perform: onDrop)
                                .disabled(isButtonDisabled)
                        }
                    }
                }
            }
        }
    }

    private func onDrop(_ providers: [NSItemProvider], _ location: CGPoint) -> Bool {
        let allowedTypeIdentifiers = providers.reduce(into: Set<String>()) {
            $0.formUnion($1.registeredTypeIdentifiers)
        }.intersection(dataType.allowedFileTypes.map(\.identifier))

        guard let typeIdentifier = allowedTypeIdentifiers.first,
              let provider = providers.first(where: {
                  $0.hasItemConformingToTypeIdentifier(typeIdentifier)
              }) else {
            os_log(.error, log: .dataImportExport, "invalid type identifiers: \(allowedTypeIdentifiers)")
            return false
        }

        provider.loadItem(forTypeIdentifier: typeIdentifier) { data, error in
            guard let data else {
                os_log(.error, log: .dataImportExport, "error loading \(typeIdentifier): \(error?.localizedDescription ?? "?")")
                return
            }
            let url: URL
            switch data {
            case let value as URL:
                url = value
            case let data as Data:
                guard let value = URL(dataRepresentation: data, relativeTo: nil) else {
                    os_log(.error, log: .dataImportExport, "could not decode data: \(data.debugDescription)")
                    return
                }
                url = value
            default:
                os_log(.error, log: .dataImportExport, "unsupported data: \(data)")
                return
            }

            onFileDrop(url)
        }

        return true
    }

}

struct CircleNumberView: View {

    let number: Int

    var body: some View {
        Circle()
            .fill(.globalBackground)
            .frame(width: 20, height: 20)
            .overlay(
                Text("\(number)")
                    .foregroundColor(.onboardingActionButton)
                    .font(.headline)
            )
    }

}

// MARK: - Preview

#Preview {
    FileImportView(source: .bitwarden, dataType: .passwords, isButtonDisabled: false)
        .frame(width: 512 - 20)

}

// MARK: - instructions builder helper

private enum FileImportInstructionsItem {
    case number(Int)
    case text(LocalizedStringKey)
    case button(LocalizedStringKey)
}

@resultBuilder
private struct FileImportInstructionsBuilder {
    static func buildBlock(_ components: [FileImportInstructionsItem]...) -> [FileImportInstructionsItem] {
        return components.flatMap { $0 }
    }

    static func buildOptional(_ components: [FileImportInstructionsItem]?) -> [FileImportInstructionsItem] {
        return components ?? []
    }

    static func buildEither(first component: [FileImportInstructionsItem]) -> [FileImportInstructionsItem] {
        component
    }

    static func buildEither(second component: [FileImportInstructionsItem]) -> [FileImportInstructionsItem] {
        component
    }

    static func buildLimitedAvailability(_ component: [FileImportInstructionsItem]) -> [FileImportInstructionsItem] {
        component
    }

    static func buildArray(_ components: [[FileImportInstructionsItem]]) -> [FileImportInstructionsItem] {
        components.flatMap { $0 }
    }

    static func buildExpression(_ expression: [FileImportInstructionsItem]) -> [FileImportInstructionsItem] {
        return expression
    }

    static func buildExpression(_ value: Int) -> [FileImportInstructionsItem] {
        return [.number(value)]
    }

    static func buildExpression(_ value: LocalizedStringKey) -> [FileImportInstructionsItem] {
        return [.text(value)]
    }

    static func buildExpression(_ value: FileImportInstructionsItem) -> [FileImportInstructionsItem] {
        return [value]
    }

    static func buildExpression(_ expression: Void) -> [FileImportInstructionsItem] {
        return []
    }

}

private func buildInstructions(@FileImportInstructionsBuilder builder: () -> [FileImportInstructionsItem]) -> [[FileImportInstructionsItem]] {
    let items = builder()

    // zip [1, "text 1", 2, "text 2", "text 3"] to [[1, "text 1"], [2, "text 2"], ["text 3"]]
    var result: [[FileImportInstructionsItem]] = []
    var currentNumber: Int?

    for item in items {
        switch item {
        case .number(let num):
            currentNumber = num
        case .text, .button:
            if let currentNumber {
                result.append([.number(currentNumber), item])
            } else {
                result.append([item])
            }
            currentNumber = nil
        }
    }

    return result
}
