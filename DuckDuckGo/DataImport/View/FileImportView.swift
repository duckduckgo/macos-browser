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

    private var isButtonDisabled: Bool

    init(source: DataImport.Source, dataType: DataImport.DataType, isButtonDisabled: Bool, action: (() -> Void)? = nil, onFileDrop: ((URL) -> Void)? = nil) {
        self.source = source
        self.dataType = dataType
        self.action = action ?? {}
        self.onFileDrop = onFileDrop ?? { _ in }
        self.isButtonDisabled = isButtonDisabled
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

            InstructionsView(fontName: "SF Pro Text", fontSize: 13) {

                switch (source, dataType) {
                case (.chrome, .passwords):
                    NSLocalizedString("import.csv.instructions.chrome", value: """
                    %d Open **%s**
                    %d In a fresh tab, click %@ then **Google Password Manager → Settings**
                    %d Find “Export Passwords” and click **Download File**
                    %d Save the passwords file someplace you can find it (e.g. Desktop)
                    %d %@
                    """, comment: """
                    Instructions to import Passwords as CSV from Google Chrome browser.
                    %d is a step number; %s is a Browser name; %@ is for a button image to click
                    **bold text**; _italic text_
                    """)
                    source.importSourceName
                    NSImage.menuVertical16
                    button("Select Passwords CSV File…")

                case (.brave, .passwords),
                    (.chromium, .passwords),
                    (.coccoc, .passwords),
                    (.edge, .passwords),
                    (.vivaldi, .passwords),
                    (.opera, .passwords),
                    (.operaGX, .passwords):

                    NSLocalizedString("import.csv.instructions.chromium", value: """
                    %d Open **%s**
                    %d In a fresh tab, click %@ then **Password Manager → Settings**
                    %d Find “Export Passwords” and click **Download File**
                    %d Save the passwords file someplace you can find it (e.g. Desktop)
                    %d %@
                    """, comment: """
                    Instructions to import Passwords as CSV from Chromium-based browsers.
                    %d is a step number; %s is a Browser name; %@ is for a button image to click
                    **bold text**; _italic text_
                    """)
                    source.importSourceName
                    NSImage.menuVertical16
                    button("Select Passwords CSV File…")

                case (.yandex, .passwords):
                    NSLocalizedString("import.csv.instructions.yandex", value: """
                    %d Open **Yandex**
                    %d Click %@ to open the application menu then click **Passwords and cards**
                    %d Click %@ then **Export passwords**
                    %d Choose **To a text file (not secure)** and click **Export**
                    %d Save the passwords file someplace you can find it (e.g. Desktop)
                    %d %@
                    """, comment: """
                    Instructions to import Passwords as CSV from Yandex Browser.
                    %d is a step number; %@ is for a button image to click
                    **bold text**; _italic text_
                    """)
                    NSImage.menuHamburger16
                    NSImage.menuVertical16
                    button("Select Passwords CSV File…")

                case (.brave, .bookmarks),
                    (.chrome, .bookmarks),
                    (.chromium, .bookmarks),
                    (.coccoc, .bookmarks),
                    (.edge, .bookmarks),
                    (.vivaldi, .bookmarks),
                    (.opera, .bookmarks),
                    (.operaGX, .bookmarks):
                    NSLocalizedString("import.html.instructions.chromium", value: """
                    %d Open **%s**
                    %d Use the Menu Bar to select **Bookmarks → Bookmark Manager**
                    %d Click %@ then **Export Bookmarks**
                    %d Save the file someplace you can find it (e.g., Desktop)
                    %d %@
                    """, comment: """
                    Instructions to import Bookmarks exported as HTML from Chromium-based browsers.
                    %d is a step number; %s is a Browser name; %@ is for a button image to click
                    **bold text**; _italic text_
                    """)
                    source.importSourceName
                    NSImage.menuVertical16
                    button("Select Bookmarks HTML File…")

                case (.yandex, .bookmarks):
                    NSLocalizedString("import.html.instructions.yandex", value: """
                    %d Open **%s**
                    %d Use the Menu Bar to select **Favorites → Bookmark Manager**
                    %d Click %@ then **Export bookmarks to HTML file**
                    %d Save the file someplace you can find it (e.g., Desktop)
                    %d %@
                    """, comment: """
                    Instructions to import Bookmarks exported as HTML from Yandex Browser.
                    %d is a step number; %s is a Browser name; %@ is for a button image to click
                    **bold text**; _italic text_
                    """)
                    source.importSourceName
                    NSImage.menuVertical16
                    button("Select Bookmarks HTML File…")

                case (.safari, .passwords), (.safariTechnologyPreview, .passwords):
                    NSLocalizedString("import.csv.instructions.safari", value: """
                    %d Open **Safari**
                    %d Select **File → Export → Passwords**
                    %d Save the passwords file someplace you can find it (e.g. Desktop)
                    %d %@
                    """, comment: """
                    Instructions to import Passwords as CSV from Safari.
                    %d is a step number; %@ is for a button image to click
                    **bold text**; _italic text_
                    """)

                    button("Select Passwords CSV File…")

                case (.safari, .bookmarks), (.safariTechnologyPreview, .bookmarks):
                    NSLocalizedString("import.html.instructions.safari", value: """
                    %d Open **Safari**
                    %d Select **File → Export → Bookmarks**
                    %d Save the passwords file someplace you can find it (e.g. Desktop)
                    %d %@
                    """, comment: """
                    Instructions to import Bookmarks exported as HTML from Safari.
                    %d is a step number; %@ is for a button image to click
                    **bold text**; _italic text_
                    """)
                    button("Select Bookmarks HTML File…")

                case (.firefox, .passwords):
                    NSLocalizedString("import.csv.instructions.firefox", value: """
                    %d Open **%s**
                    %d Click %@ to open the application menu then click **Passwords**
                    %d Click %@ then **Export Logins…**
                    %d Save the passwords file someplace you can find it (e.g. Desktop)
                    %d %@
                    """, comment: """
                    Instructions to import Passwords as CSV from Firefox.
                    %d is a step number; %s is a Browser name; %@ is for a button image to click
                    **bold text**; _italic text_
                    """)
                    source.importSourceName
                    NSImage.menuHamburger16
                    NSImage.menuVertical16
                    button("Select Passwords CSV File…")

                case (.firefox, .bookmarks), (.tor, .bookmarks):
                    NSLocalizedString("import.html.instructions.firefox", value: """
                    %d Open **%s**
                    %d Use the Menu Bar to select **Bookmarks → Manage Bookmarks**
                    %d Click %@ then **Export bookmarks to HTML…**
                    %d Save the file someplace you can find it (e.g., Desktop)
                    %d %@
                    """, comment: """
                    Instructions to import Bookmarks exported as HTML from Firefox based browsers.
                    %d is a step number; %s is a Browser name; %@ is for a button image to click
                    **bold text**; _italic text_
                    """)
                    source.importSourceName
                    NSImage.importExport16
                    button("Select Bookmarks HTML File…")

                case (.onePassword8, .passwords):
                    NSLocalizedString("import.csv.instructions.onePassword8", value: """
                    %d Open and unlock **%s**
                    %d Select **File → Export** from the Menu Bar and choose the account you want to export
                    %d Enter your 1Password account password
                    %d Select the File Format: **CSV (Logins and Passwords only)**
                    %d Click Export Data and save the file someplace you can find it (e.g. Desktop)
                    %d %@
                    """, comment: """
                    Instructions to import Passwords as CSV from 1Password 8.
                    %d is a step number; %s is 1Password app name; %@ is for a button image to click
                    **bold text**; _italic text_
                    """)
                    source.importSourceName
                    button("Select 1Password CSV File…")

                case (.onePassword7, .passwords):
                    NSLocalizedString("import.csv.instructions.onePassword7", value: """
                    %d Open and unlock **%s**
                    %d Select the vault you want to Export (You cannot export from “All Vaults.”)
                    %d Select **File → Export → All Items** from the Menu Bar
                    %d Enter your 1Password master or account password
                    %d Select the File Format: **iCloud Keychain (.csv)**
                    %d Save the passwords file someplace you can find it (e.g. Desktop)
                    %d %@
                    """, comment: """
                    Instructions to import Passwords as CSV from 1Password 7.
                    %d is a step number; %s is 1Password app name; %@ is for a button image to click
                    **bold text**; _italic text_
                    """)
                    source.importSourceName
                    button("Select 1Password CSV File…")

                case (.bitwarden, .passwords):
                    NSLocalizedString("import.csv.instructions.bitwarden", value: """
                    %d Open and unlock **%s**
                    %d Select **File → Export vault** from the Menu Bar
                    %d Select the File Format: **.csv**
                    %d Enter your Bitwarden Master password
                    %d Click %@ and save the file someplace you can find it (e.g. Desktop)
                    %d %@
                    """, comment: """
                    Instructions to import Passwords as CSV from Bitwarden.
                    %d is a step number; %s is Bitwarden app name; %@ is for a button image to click
                    **bold text**; _italic text_
                    """)
                    source.importSourceName
                    NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: nil) ?? .downloads
                    button("Select Bitwarden CSV File…")

                case (.lastPass, .passwords):
                    NSLocalizedString("import.csv.instructions.lastpass", value: """
                    %d Click on the **%s** icon in your browser and enter your master password
                    %d Select **Open My Vault**
                    %d From the sidebar select **Advanced Options → Export**
                    %d Enter your LastPass master password
                    %d Select the File Format: **Comma Delimited Text (.csv)**
                    %d %@
                    """, comment: """
                    Instructions to import Passwords as CSV from LastPass.
                    %d is a step number; %s is LastPass app name; %@ is for a button image to click
                    **bold text**; _italic text_
                    """)
                    source.importSourceName
                    button("Select LastPass CSV File…")

                case (.csv, .passwords):
                    NSLocalizedString("import.csv.instructions.generic", value: """
                    The CSV importer will try to match column headers to their position.
                    If there is no header, it supports two formats:
                    %d URL, Username, Password
                    %d Title, URL, Username, Password
                    %@
                    """, comment: """
                    Instructions to import a generic CSV passwords file.
                    %d is a step number; %@ is for a button image to click
                    **bold text**; _italic text_
                    """)

                    button("Select Passwords CSV File…")

                case (.bookmarksHTML, .bookmarks):
                    NSLocalizedString("import.html.instructions.generic", value: """
                    %d Open your old browser
                    %d Click %@ then select **Bookmarks → Bookmark Manager**
                    %d Click %@ then **Export bookmarks to HTML…**
                    %d Save the file someplace you can find it (e.g., Desktop)
                    %d %@
                    """, comment: """
                    Instructions to import a generic HTML Bookmarks file.
                    %d is a step number; %@ is for a button image to click
                    **bold text**; _italic text_
                    """)
                    NSImage.menuHamburger16
                    NSImage.menuVertical16
                    button("Select Bookmarks HTML File…")

                case (.bookmarksHTML, .passwords),
                    (.tor, .passwords),
                    (.onePassword7, .bookmarks),
                    (.onePassword8, .bookmarks),
                    (.bitwarden, .bookmarks),
                    (.lastPass, .bookmarks),
                    (.csv, .bookmarks):
                    assertionFailure("Invalid source/dataType")
                }
            }
        }
    }

    private func button(_ localizedTitleKey: LocalizedStringKey) -> some View {
        Button(localizedTitleKey, action: action)
            .onDrop(of: dataType.allowedFileTypes, isTargeted: nil, perform: onDrop)
            .disabled(isButtonDisabled)
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

struct InstructionsView: View {

    enum TextPart {
        case image(NSImage)
        case text(text: String, isBold: Bool, isItalic: Bool)
    }
    enum InstructionsViewItem {
        case lineNumber(Int)
        case textParts([TextPart])
        case view(AnyView)
    }

    let fontName: String
    let fontSize: CGFloat

    private let instructions: [[InstructionsViewItem]]

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    init(fontName: String, fontSize: CGFloat, @InstructionsBuilder builder: () -> [InstructionsItem]) {
        self.fontName = fontName
        self.fontSize = fontSize

        let items = builder()

        guard case .string(let format) = items.first else {
            assertionFailure("First item should provide instructions format using NSLocalizedString")
            self.instructions = []
            return
        }

        do {

            let formatLines = try InstructionsFormatParser().parse(format: format)

            var result = [[InstructionsViewItem]]()
            var argIndex = 1
            var lineNumber = 1

            func fline(_ lineIdx: Int) -> String {
                format.components(separatedBy: "\n")[safe: lineIdx] ?? "?"
            }

            for (lineIdx, line) in formatLines.enumerated() {
                var resultLine = [InstructionsViewItem]()
                func appendTextPart(_ textPart: TextPart) {
                    if case .textParts(var parts) = resultLine.last {
                        parts.append(textPart)
                        resultLine[resultLine.endIndex - 1] = .textParts(parts)
                    } else {
                        resultLine.append(.textParts([textPart]))
                    }
                }

                for component in line {
                    switch component {
                    case .number:
                        resultLine.append(.lineNumber(lineNumber))
                        lineNumber += 1
                    case .text(let text, bold: let bold, italic: let italic):
                        appendTextPart(.text(text: text, isBold: bold, isItalic: italic))
                    case .string(bold: let bold, italic: let italic):
                        switch items[safe: argIndex] {
                        case .string(let str):
                            appendTextPart(.text(text: str, isBold: bold, isItalic: italic))
                        case .none:
                            assertionFailure("String argument missing at index \(argIndex) in “\(fline(lineIdx))”")
                        case .image(let obj as Any), .view(let obj as Any):
                            assertionFailure("Unexpected object argument “\(obj)”, expected string at index \(argIndex) in “\(fline(lineIdx))”")
                        }
                        argIndex += 1

                    case .object:
                        switch items[safe: argIndex] {
                        case .image(let image):
                            appendTextPart(.image(image))
                        case .view(let view):
                            resultLine.append(.view(view))
                        case .none:
                            assertionFailure("Object argument missing at index \(argIndex) in “\(fline(lineIdx))”")
                        case .string(let string):
                            assertionFailure("Unexpected string argument “\(string)”, expected object at index \(argIndex) in “\(fline(lineIdx))”")
                        }

                        argIndex += 1
                    }
                }
                result.append(resultLine)
            }
            if argIndex < items.count {
                assertionFailure("Argument \(items[argIndex]) not used anywhere")
            }

            self.instructions = result

        } catch {
            assertionFailure("Could not build instructions view: \(error)")
            self.instructions = []
        }
    }

    enum InstructionsItem {
        case string(String)
        case image(NSImage)
        case view(AnyView)
    }

    @resultBuilder
    struct InstructionsBuilder {
        static func buildBlock(_ components: [InstructionsItem]...) -> [InstructionsItem] {
            return components.flatMap { $0 }
        }

        static func buildOptional(_ components: [InstructionsItem]?) -> [InstructionsItem] {
            return components ?? []
        }

        static func buildEither(first component: [InstructionsItem]) -> [InstructionsItem] {
            component
        }

        static func buildEither(second component: [InstructionsItem]) -> [InstructionsItem] {
            component
        }

        static func buildLimitedAvailability(_ component: [InstructionsItem]) -> [InstructionsItem] {
            component
        }

        static func buildArray(_ components: [[InstructionsItem]]) -> [InstructionsItem] {
            components.flatMap { $0 }
        }

        static func buildExpression(_ expression: [InstructionsItem]) -> [InstructionsItem] {
            return expression
        }

        static func buildExpression(_ value: String) -> [InstructionsItem] {
            return [.string(value)]
        }

        static func buildExpression(_ value: NSImage) -> [InstructionsItem] {
            return [.image(value)]
        }

        static func buildExpression(_ value: some View) -> [InstructionsItem] {
            return [.view(AnyView(value))]
        }

        static func buildExpression(_ expression: Void) -> [InstructionsItem] {
            return []
        }

    }

    var body: some View {
        ForEach(instructions.indices, id: \.self) { i in
            HStack(spacing: 4) {
                ForEach(instructions[i].indices, id: \.self) { j in
                    switch instructions[i][j] {
                    case .lineNumber(let number):
                        CircleNumberView(number: number)
                    case .textParts(let textParts):
                        Text(textParts, fontName: fontName, fontSize: fontSize)
                    case .view(let view):
                        view
                    }
                }
            }
        }
    }

}

private extension Text {

    init(_ textPart: InstructionsView.TextPart, fontName: String, fontSize: CGFloat) {
        switch textPart {
        case .image(let image):
            self.init(Image(nsImage: image))
            self = self.baselineOffset(fontSize - image.size.height)
        case .text(let text, let isBold, let isItalic):
            self.init(text)
            self = self.font(.custom(fontName, size: fontSize))
            if isBold {
                self = self.bold()
            }
            if isItalic {
                self = self.italic()
            }
        }
    }

    init(_ textParts: [InstructionsView.TextPart], fontName: String, fontSize: CGFloat) {
        guard !textParts.isEmpty else {
            assertionFailure("Empty TextParts")
            self.init("")
            return
        }
        self.init(textParts[0], fontName: fontName, fontSize: fontSize)

        guard textParts.count > 1 else { return }
        for textPart in textParts[1...] {
            // swiftlint:disable:next shorthand_operator
            self = self + Text(textPart, fontName: fontName, fontSize: fontSize)
        }
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
