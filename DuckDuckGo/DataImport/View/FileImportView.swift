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
import os.log
import BrowserServicesKit

@InstructionsView.InstructionsBuilder
func fileImportInstructionsBuilder(source: DataImport.Source, dataType: DataImport.DataType, button: @escaping (String) -> AnyView) -> [InstructionsView.InstructionsItem] {

    switch (source, dataType) {
    case (.chrome, .passwords):
        NSLocalizedString("import.csv.instructions.chrome", value: """
        %d Open **%s**
        %d In a fresh tab, click %@ then **Google Password Manager → Settings**
        %d Find “Export Passwords” and click **Download File**
        %d Save the passwords file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import Passwords as CSV from Google Chrome browser.
        %N$d - step number
        %2$s - browser name (Chrome)
        %4$@ - hamburger menu icon
        %8$@ - “Select Passwords CSV File” button
        **bold text**; _italic text_
        """)
        source.importSourceName
        NSImage.menuVertical16
        button(UserText.importLoginsSelectCSVFile)

    case (.brave, .passwords):
        NSLocalizedString("import.csv.instructions.brave", value: """
        %d Open **%s**
        %d Click %@ to open the application menu then click **Password Manager**
        %d Click %@ **at the top left** of the Password Manager and select **Settings**
        %d Find “Export Passwords” and click **Download File**
        %d Save the passwords file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import Passwords as CSV from Brave browser.
        %N$d - step number
        %2$s - browser name (Brave)
        %4$@, %6$@ - hamburger menu icon
        %10$@ - “Select Passwords CSV File” button
        **bold text**; _italic text_
        """)
        source.importSourceName
        NSImage.menuHamburger16
        NSImage.menuHamburger16
        button(UserText.importLoginsSelectCSVFile)

    case (.chromium, .passwords),
        (.edge, .passwords):
        NSLocalizedString("import.csv.instructions.chromium", value: """
        %d Open **%s**
        %d In a fresh tab, click %@ then **Password Manager → Settings**
        %d Find “Export Passwords” and click **Download File**
        %d Save the passwords file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import Passwords as CSV from Chromium-based browsers.
        %N$d - step number
        %2$s - browser name
        %4$@ - hamburger menu icon
        %8$@ - “Select Passwords CSV File” button
        **bold text**; _italic text_
        """)
        source.importSourceName
        NSImage.menuVertical16
        button(UserText.importLoginsSelectCSVFile)

    case (.coccoc, .passwords):
        NSLocalizedString("import.csv.instructions.coccoc", value: """
        %d Open **%s**
        %d Type “_coccoc://settings/passwords_” into the Address bar
        %d Click %@ (on the right from _Saved Passwords_) and select **Export passwords**
        %d Save the passwords file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import Passwords as CSV from Cốc Cốc browser.
        %N$d - step number
        %2$s - browser name (Cốc Cốc)
        %5$@ - hamburger menu icon
        %8$@ - “Select Passwords CSV File” button
        **bold text**; _italic text_
        """)
        source.importSourceName
        NSImage.menuVertical16
        button(UserText.importLoginsSelectCSVFile)

    case (.opera, .passwords):
        NSLocalizedString("import.csv.instructions.opera", value: """
        %d Open **%s**
        %d Use the Menu Bar to select **View → Show Password Manager**
        %d Select **Settings**
        %d Find “Export Passwords” and click **Download File**
        %d Save the passwords file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import Passwords as CSV from Opera browser.
        %N$d - step number
        %2$s - browser name (Opera)
        %8$@ - “Select Passwords CSV File” button
        **bold text**; _italic text_
        """)
        source.importSourceName
        button(UserText.importLoginsSelectCSVFile)

    case (.vivaldi, .passwords):
        NSLocalizedString("import.csv.instructions.vivaldi", value: """
        %d Open **%s**
        %d Type “_chrome://settings/passwords_” into the Address bar
        %d Click %@ (on the right from _Saved Passwords_) and select **Export passwords**
        %d Save the file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import Passwords exported as CSV from Vivaldi browser.
        %N$d - step number
        %2$s - browser name (Vivaldi)
        %5$@ - menu button icon
        %8$@ - “Select Passwords CSV File” button
        **bold text**; _italic text_
        """)
        source.importSourceName
        NSImage.menuVertical16
        button(UserText.importLoginsSelectCSVFile)

    case (.operaGX, .passwords):
        NSLocalizedString("import.csv.instructions.operagx", value: """
        %d Open **%s**
        %d Use the Menu Bar to select **View → Show Password Manager**
        %d Click %@ (on the right from _Saved Passwords_) and select **Export passwords**
        %d Save the passwords file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import Passwords as CSV from Opera GX browsers.
        %N$d - step number
        %2$s - browser name (Opera GX)
        %5$@ - menu button icon
        %8$@ - “Select Passwords CSV File” button
        **bold text**; _italic text_
        """)
        source.importSourceName
        NSImage.menuVertical16
        button(UserText.importLoginsSelectCSVFile)

    case (.yandex, .passwords):
        NSLocalizedString("import.csv.instructions.yandex", value: """
        %d Open **%s**
        %d Click %@ to open the application menu then click **Passwords and cards**
        %d Click %@ then **Export passwords**
        %d Choose **To a text file (not secure)** and click **Export**
        %d Save the passwords file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import Passwords as CSV from Yandex Browser.
        %N$d - step number
        %2$s - browser name (Yandex)
        %4$@ - hamburger menu icon
        %8$@ - “Select Passwords CSV File” button
        **bold text**; _italic text_
        """)
        source.importSourceName
        NSImage.menuHamburger16
        NSImage.menuVertical16
        button(UserText.importLoginsSelectCSVFile)

    case (.brave, .bookmarks),
        (.chrome, .bookmarks),
        (.chromium, .bookmarks),
        (.coccoc, .bookmarks),
        (.edge, .bookmarks):
        NSLocalizedString("import.html.instructions.chromium", value: """
        %d Open **%s**
        %d Use the Menu Bar to select **Bookmarks → Bookmark Manager**
        %d Click %@ then **Export Bookmarks**
        %d Save the file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import Bookmarks exported as HTML from Chromium-based browsers.
        %N$d - step number
        %2$s - browser name
        %5$@ - hamburger menu icon
        %8$@ - “Select Bookmarks HTML File” button
        **bold text**; _italic text_
        """)
        source.importSourceName
        NSImage.menuVertical16
        button(UserText.importBookmarksSelectHTMLFile)

    case (.vivaldi, .bookmarks):
        NSLocalizedString("import.html.instructions.vivaldi", value: """
        %d Open **%s**
        %d Use the Menu Bar to select **File → Export Bookmarks…**
        %d Save the file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import Bookmarks exported as HTML from Vivaldi browser.
        %N$d - step number
        %2$s - browser name (Vivaldi)
        %6$@ - “Select Bookmarks HTML File” button
        **bold text**; _italic text_
        """)
        source.importSourceName
        button(UserText.importBookmarksSelectHTMLFile)

    case (.opera, .bookmarks):
        NSLocalizedString("import.html.instructions.opera", value: """
        %d Open **%s**
        %d Use the Menu Bar to select **Bookmarks → Bookmarks**
        %d Click **Open full Bookmarks view…** in the bottom left
        %d Click **Import/Export…** in the bottom left and select **Export Bookmarks**
        %d Save the file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import Bookmarks exported as HTML from Opera browser.
        %N$d - step number
        %2$s - browser name (Opera)
        %8$@ - “Select Bookmarks HTML File” button
        **bold text**; _italic text_
        """)
        source.importSourceName
        button(UserText.importBookmarksSelectHTMLFile)

    case (.operaGX, .bookmarks):
        NSLocalizedString("import.html.instructions.operagx", value: """
        %d Open **%s**
        %d Use the Menu Bar to select **Bookmarks → Bookmarks**
        %d Click **Import/Export…** in the bottom left and select **Export Bookmarks**
        %d Save the file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import Bookmarks exported as HTML from Opera GX browser.
        %N$d - step number
        %2$s - browser name (Opera GX)
        %7$@ - “Select Bookmarks HTML File” button
        **bold text**; _italic text_
        """)
        source.importSourceName
        button(UserText.importBookmarksSelectHTMLFile)

    case (.yandex, .bookmarks):
        NSLocalizedString("import.html.instructions.yandex", value: """
        %d Open **%s**
        %d Use the Menu Bar to select **Favorites → Bookmark Manager**
        %d Click %@ then **Export bookmarks to HTML file**
        %d Save the file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import Bookmarks exported as HTML from Yandex Browser.
        %N$d - step number
        %2$s - browser name (Yandex)
        %5$@ - hamburger menu icon
        %8$@ - “Select Bookmarks HTML File” button
        **bold text**; _italic text_
        """)
        source.importSourceName
        NSImage.menuVertical16
        button(UserText.importBookmarksSelectHTMLFile)

    case (.safari, .passwords), (.safariTechnologyPreview, .passwords):
        if #available(macOS 15.2, *) {
            NSLocalizedString("import.csv.instructions.safari.macos15-2", value: """
            %d Open **Safari**
            %d Open the **File menu → Export Browsing Data to File...**
            %d Select **passwords** and save the file someplace you can find it (e.g., Desktop)
            %d Double click the .zip file to unzip it
            %d %@
            """, comment: """
            Instructions to import Passwords as CSV from Safari zip file on >= macOS 15.2.
            %N$d - step number
            %5$@ - “Select Passwords CSV File” button
            **bold text**; _italic text_
            """)
            button(UserText.importLoginsSelectCSVFile)
        } else {
            NSLocalizedString("import.csv.instructions.safari", value: """
            %d Open **Safari**
            %d Select **File → Export → Passwords**
            %d Save the passwords file someplace you can find it (e.g., Desktop)
            %d %@
            """, comment: """
            Instructions to import Passwords as CSV from Safari.
            %N$d - step number
            %5$@ - “Select Passwords CSV File” button
            **bold text**; _italic text_
            """)
            button(UserText.importLoginsSelectCSVFile)
        }

    case (.safari, .bookmarks), (.safariTechnologyPreview, .bookmarks):
        NSLocalizedString("import.html.instructions.safari", value: """
        %d Open **Safari**
        %d Select **File → Export → Bookmarks**
        %d Save the passwords file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import Bookmarks exported as HTML from Safari.
        %N$d - step number
        %5$@ - “Select Bookmarks HTML File” button
        **bold text**; _italic text_
        """)
        button(UserText.importBookmarksSelectHTMLFile)

    case (.firefox, .passwords):
        NSLocalizedString("import.csv.instructions.firefox", value: """
        %d Open **%s**
        %d Click %@ to open the application menu then click **Passwords**
        %d Click %@ then **Export Logins…**
        %d Save the passwords file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import Passwords as CSV from Firefox.
        %N$d - step number
        %2$s - browser name (Firefox)
        %4$@, %6$@ - hamburger menu icon
        %9$@ - “Select Passwords CSV File” button
        **bold text**; _italic text_
        """)
        source.importSourceName
        NSImage.menuHamburger16
        NSImage.menuHorizontal16
        button(UserText.importLoginsSelectCSVFile)

    case (.firefox, .bookmarks), (.tor, .bookmarks):
        NSLocalizedString("import.html.instructions.firefox", value: """
        %d Open **%s**
        %d Use the Menu Bar to select **Bookmarks → Manage Bookmarks**
        %d Click %@ then **Export bookmarks to HTML…**
        %d Save the file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import Bookmarks exported as HTML from Firefox based browsers.
        %N$d - step number
        %2$s - browser name (Firefox)
        %5$@ - hamburger menu icon
        %8$@ - “Select Bookmarks HTML File” button
        **bold text**; _italic text_
        """)
        source.importSourceName
        NSImage.importExport16
        button(UserText.importBookmarksSelectHTMLFile)

    case (.onePassword8, .passwords):
        NSLocalizedString("import.csv.instructions.onePassword8", value: """
        %d Open and unlock **%s**
        %d Select **File → Export** from the Menu Bar and choose the account you want to export
        %d Enter your 1Password account password
        %d Select the File Format: **CSV (Logins and Passwords only)**
        %d Click Export Data and save the file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import Passwords as CSV from 1Password 8.
        %2$s - app name (1Password)
        %8$@ - “Select 1Password CSV File” button
        **bold text**; _italic text_
        """)
        source.importSourceName
        button(UserText.importLoginsSelectCSVFile(from: source))

    case (.onePassword7, .passwords):
        NSLocalizedString("import.csv.instructions.onePassword7", value: """
        %d Open and unlock **%s**
        %d Select the vault you want to export (you can only export one vault at a time)
        %d Select **File → Export → All Items** from the Menu Bar
        %d Enter your 1Password main or account password
        %d Select the File Format: **iCloud Keychain (.csv)**
        %d Save the passwords file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import Passwords as CSV from 1Password 7.
        %2$s - app name (1Password)
        %9$@ - “Select 1Password CSV File” button
        **bold text**; _italic text_
        """)
        source.importSourceName
        button(UserText.importLoginsSelectCSVFile(from: source))

    case (.bitwarden, .passwords):
        NSLocalizedString("import.csv.instructions.bitwarden", value: """
        %d Open and unlock **%s**
        %d Select **File → Export vault** from the Menu Bar
        %d Select the File Format: **.csv**
        %d Enter your Bitwarden main password
        %d Click %@ and save the file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import Passwords as CSV from Bitwarden.
        %2$s - app name (Bitwarden)
        %7$@ - hamburger menu icon
        %9$@ - “Select Bitwarden CSV File” button
        **bold text**; _italic text_
        """)
        source.importSourceName
        NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: nil) ?? .downloads
        button(UserText.importLoginsSelectCSVFile(from: source))

    case (.lastPass, .passwords):
        NSLocalizedString("import.csv.instructions.lastpass", value: """
        %d Click on the **%s** icon in your browser and enter your main password
        %d Select **Open My Vault**
        %d From the sidebar select **Advanced Options → Export**
        %d Enter your LastPass main password
        %d Select the File Format: **Comma Delimited Text (.csv)**
        %d %@
        """, comment: """
        Instructions to import Passwords as CSV from LastPass.
        %2$s - app name (LastPass)
        %8$@ - “Select LastPass CSV File” button
        **bold text**; _italic text_
        """)
        source.importSourceName
        button(UserText.importLoginsSelectCSVFile(from: source))

    case (.csv, .passwords):
        NSLocalizedString("import.csv.instructions.generic", value: """
        The CSV importer will try to match column headers to their position.
        If there is no header, it supports two formats:
        %d URL, Username, Password
        %d Title, URL, Username, Password
        %@
        """, comment: """
        Instructions to import a generic CSV passwords file.
        %N$d - step number
        %3$@ - “Select Passwords CSV File” button
        **bold text**; _italic text_
        """)
        button(UserText.importLoginsSelectCSVFile)

    case (.bookmarksHTML, .bookmarks):
        NSLocalizedString("import.html.instructions.generic", value: """
        %d Open your old browser
        %d Open **Bookmark Manager**
        %d Export bookmarks to HTML…
        %d Save the file someplace you can find it (e.g., Desktop)
        %d %@
        """, comment: """
        Instructions to import a generic HTML Bookmarks file.
        %N$d - step number
        %6$@ - “Select Bookmarks HTML File” button
        **bold text**; _italic text_
        """)
        button(UserText.importBookmarksSelectHTMLFile)

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
        VStack(alignment: .leading, spacing: 16) {
            {
                switch dataType {
                case .bookmarks:
                    Text("Import Bookmarks", comment: "Title of dialog with instruction for the user to import bookmarks from another browser")
                case .passwords:
                    Text("Import Passwords", comment: "Title of dialog with instruction for the user to import passwords from another browser")
                }
            }().bold()

            if [.onePassword7, .onePassword8].contains(source) {
                HStack {
                    Image(.info)
                    // markdown not supported on macOS 11
                    InstructionsView {
                        NSLocalizedString("import.onePassword.app.version.info", value: """
                        You can find your version by selecting **%s → About %s** from the Menu Bar.
                        """, comment: """
                        Instructions how to find an installed 1Password password manager app version.
                        %1$s, %2$s - app name (1Password)
                        """)
                        source.importSourceName
                        source.importSourceName
                    }

                    Spacer()
                }
                .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                .background(Color(.blackWhite5))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separator),
                                style: StrokeStyle(lineWidth: 1))
                )
                .padding(.top, 8)
                .padding(.bottom, 8)
            }

            InstructionsView {
                fileImportInstructionsBuilder(source: source, dataType: dataType, button: self.button)
            }
        }
    }

    private func button(_ title: String) -> AnyView {
        AnyView(
            Button(title, action: action)
                .onDrop(of: dataType.allowedFileTypes, isTargeted: nil, perform: onDrop)
                .disabled(isButtonDisabled)
        )
    }

    private func onDrop(_ providers: [NSItemProvider], _ location: CGPoint) -> Bool {
        let allowedTypeIdentifiers = providers.reduce(into: Set<String>()) {
            $0.formUnion($1.registeredTypeIdentifiers)
        }.intersection(dataType.allowedFileTypes.map(\.identifier))

        guard let typeIdentifier = allowedTypeIdentifiers.first,
              let provider = providers.first(where: {
                  $0.hasItemConformingToTypeIdentifier(typeIdentifier)
              }) else {
            Logger.dataImportExport.error("invalid type identifiers: \(allowedTypeIdentifiers)")
            return false
        }

        provider.loadItem(forTypeIdentifier: typeIdentifier) { data, error in
            guard let data else {
                Logger.dataImportExport.error("error loading \(typeIdentifier): \(error?.localizedDescription ?? "?")")
                return
            }
            let url: URL
            switch data {
            case let value as URL:
                url = value
            case let data as Data:
                guard let value = URL(dataRepresentation: data, relativeTo: nil) else {
                    Logger.dataImportExport.error("could not decode data: \(data.debugDescription)")
                    return
                }
                url = value
            default:
                Logger.dataImportExport.error("unsupported data: \(String(describing: data))")
                return
            }

            onFileDrop(url)
        }

        return true
    }

}

struct InstructionsView: View {

    // item used in InstructionBuilder: string literal, NSImage or Choose File Button (AnyView)
    enum InstructionsItem {
        case string(String)
        case image(NSImage)
        case view(AnyView)
    }
    // Text item view ViewModel - joined in a line using Text(string).bold().italic() + Text(image).. seq
    enum TextItem {
        case image(NSImage)
        case text(text: String, isBold: Bool, isItalic: Bool)
    }
    // Possible InstructionsView line components:
    // - lineNumber (number in a circle)
    // - textItems: Text(string).bold().italic() + Text(image).. seq
    // - view: Choose File Button
    enum InstructionsViewItem {
        case lineNumber(Int)
        case textItems([TextItem])
        case view(AnyView)
    }

    // View Model
    private let instructions: [[InstructionsViewItem]]

    init(@InstructionsBuilder builder: () -> [InstructionsItem]) {
        var args = builder()

        guard case .string(let format) = args.first else {
            assertionFailure("First item should provide instructions format using NSLocalizedString")
            self.instructions = []
            return
        }

        do {
            // parse %12$d, %23$s, %34$@ out of the localized format into component sequence
            let formatLines = try InstructionsFormatParser().parse(format: format)

            // assertion helper
            func fline(_ lineIdx: Int) -> String {
                format.components(separatedBy: "\n")[safe: lineIdx] ?? "?"
            }

            // arguments are positioned (%42$s %23$@) but lines numbers are auto-incremented
            // but the line arguments (%12$d) are still indexed.
            // insert fake components at .line components positions to keep order
            let lineNumberArgumentIndices = formatLines.reduce(into: IndexSet()) {
                $0.formUnion($1.reduce(into: IndexSet()) {
                    if case .number(argIndex: let argIndex) = $1 {
                        $0.insert(argIndex)
                    }
                })
            }
            for idx in lineNumberArgumentIndices {
                args.insert(.string(""), at: idx)
            }

            // generate instructions view model from localized format
            var result = [[InstructionsViewItem]]()
            var lineNumber = 1
            var usedArgs = IndexSet()
            for (lineIdx, line) in formatLines.enumerated() {
                // collect view items placed in line
                var resultLine = [InstructionsViewItem]()
                func appendTextItem(_ textItem: TextItem) {
                    // text item should be appended to an ongoing textItem sequence if present
                    if case .textItems(var items) = resultLine.last {
                        items.append(textItem)
                        resultLine[resultLine.endIndex - 1] = .textItems(items)
                    } else {
                        // previous item is not .textItems - initiate a new textItem sequence
                        resultLine.append(.textItems([textItem]))
                    }
                }

                for component in line {
                    switch component {
                    // %d line number argument
                    case .number(let argIndex):
                        resultLine.append(.lineNumber(lineNumber))
                        usedArgs.insert(argIndex)
                        lineNumber += 1 // line number is auto-incremented

                    // text literal [optionally with markdown attributes]
                    case .text(let text, bold: let bold, italic: let italic):
                        appendTextItem(.text(text: text, isBold: bold, isItalic: italic))

                    // %s string argument
                    case .string(let argIndex, bold: let bold, italic: let italic):
                        switch args[safe: argIndex] {
                        case .string(let str):
                            appendTextItem(.text(text: str, isBold: bold, isItalic: italic))
                        case .none:
                            assertionFailure("String argument missing at index \(argIndex) in line \(lineIdx + 1):\n“\(fline(lineIdx))”.\nArgs:\n\(args)")
                        case .image(let obj as Any), .view(let obj as Any):
                            assertionFailure("Unexpected object argument at index \(argIndex):\n\(obj)\nExpected object in line \(lineIdx + 1):\n“\(fline(lineIdx))”.\nArgs:\n\(args)")
                        }
                        usedArgs.insert(argIndex)

                    // %@ object argument - inline image or button (view)
                    case .object(let argIndex):
                        switch args[safe: argIndex] {
                        case .image(let image):
                            appendTextItem(.image(image))
                        case .view(let view):
                            resultLine.append(.view(view))
                        case .none:
                            assertionFailure("Object argument missing at index \(argIndex) in line \(lineIdx + 1):\n“\(fline(lineIdx))”.\nArgs:\n\(args)")
                        case .string(let string):
                            assertionFailure("Unexpected string argument at index \(argIndex):\n“\(string)”.\nExpected object in line \(lineIdx + 1):\n“\(fline(lineIdx))”.\nArgs:\n\(args)")
                        }

                        usedArgs.insert(argIndex)
                    }
                }
                result.append(resultLine)
            }
            assert(usedArgs.subtracting(IndexSet(args.indices)).isEmpty,
                   "Unused arguments at indices \(usedArgs.subtracting(IndexSet(args.indices)))")
            self.instructions = result

        } catch {
            assertionFailure("Could not build instructions view: \(error)")
            self.instructions = []
        }
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
        VStack(alignment: .leading, spacing: 8) {
            ForEach(instructions.indices, id: \.self) { i in
                HStack(alignment: .top, spacing: 8) {
                    ForEach(instructions[i].indices, id: \.self) { j in
                        switch instructions[i][j] {
                        case .lineNumber(let number):
                            CircleNumberView(number: number)
                        case .textItems(let textParts):
                            Text(textParts)
                                .makeSelectable()
                                .frame(minHeight: CircleNumberView.Constants.diameter)
                        case .view(let view):
                            view
                        }
                    }
                }
            }
        }
    }

}

private extension Text {

    init(_ textPart: InstructionsView.TextItem) {
        switch textPart {
        case .image(let image):
            self.init(Image(nsImage: image))
            self = self
                .baselineOffset(-3)

        case .text(let text, let isBold, let isItalic):
            self.init(text)
            if isBold {
                self = self.bold()
            }
            if isItalic {
                self = self.italic()
            }
        }
    }

    init(_ textParts: [InstructionsView.TextItem]) {
        guard !textParts.isEmpty else {
            assertionFailure("Empty TextParts")
            self.init("")
            return
        }
        self.init(textParts[0])

        guard textParts.count > 1 else { return }
        for textPart in textParts[1...] {
            // swiftlint:disable:next shorthand_operator
            self = self + Text(textPart)
        }
    }

}

struct CircleNumberView: View {

    enum Constants {
        static let diameter: CGFloat = 20
    }

    let number: Int

    var body: some View {
        Circle()
            .fill(.globalBackground)
            .frame(width: Constants.diameter, height: Constants.diameter)
            .overlay(
                Text("\(number)")
                    .foregroundColor(Color(.onboardingActionButton))
                    .bold()

            )
    }

}

// MARK: - Preview

#Preview {
    HStack {
        FileImportView(source: .onePassword8, dataType: .passwords, isButtonDisabled: false)
            .padding()
            .frame(width: 512 - 20)
    }
    .font(.system(size: 13))
    .background(Color.white)
}
