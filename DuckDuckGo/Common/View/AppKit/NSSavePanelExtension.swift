//
//  NSSavePanelExtension.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import UniformTypeIdentifiers

extension NSSavePanel {

    private var fileTypesPopup: NSPopUpButton? {
        (self.accessoryView as? SavePanelAccessoryView)?.fileTypesPopup
    }

    @UserDefaultsWrapper(key: .saveAsPreferredFileType, defaultValue: [:])
    static private var preferredFileType: [String: String]

    private var defaultsKey: String {
        fileTypesPopup?.itemArray.compactMap { ($0.representedObject as? UTType)?.preferredMIMEType }.joined(separator: ";") ?? ""
    }

    static func savePanelWithFileTypeChooser(fileTypes: [UTType], suggestedFilename: String?, directoryURL: URL? = nil) -> NSSavePanel {
        let savePanel = NSSavePanel()

        if !fileTypes.isEmpty {
            let accessoryView = SavePanelAccessoryView()
            savePanel.accessoryView = accessoryView
            let popup = accessoryView.fileTypesPopup

            popup.target = savePanel
            popup.action = #selector(NSSavePanel.fileTypePopUpSelectionDidChange(_:))
            popup.menu = NSMenu {
                for fileType in fileTypes {
                    let title: String? = switch (fileType.localizedDescription, fileType.preferredFilenameExtension) {
                    case let (.some(description), .some(fileExtension)):
                        "\(description) (.\(fileExtension))"
                    case let (.some(description), .none):
                        description
                    case let (.none, .some(fileExtension)):
                        "." + fileExtension
                    case (.none, .none):
                        nil
                    }
                    if let title {
                        NSMenuItem(title: title, representedObject: fileType)
                    }
                }
            }
        }

        if let suggestedFilename {
            savePanel.nameFieldStringValue = suggestedFilename
        }

        // select saved file type for this set of file types
        if let fileTypesPopup = savePanel.fileTypesPopup,
           let savedFileType = preferredFileType[savePanel.defaultsKey].map({ UTType(mimeType: $0) }),
           let item = savePanel.fileTypesPopup?.itemArray.first(where: { $0.representedObject as? UTType == savedFileType }) {
            fileTypesPopup.select(item)
            savePanel.selectedFileType = savedFileType
        } else {
            // select first file type
            savePanel.fileTypesPopup?.selectItem(at: 0)
            savePanel.selectedFileType = fileTypes.first
        }

        if let directoryURL = directoryURL {
            savePanel.directoryURL = directoryURL
        }
        savePanel.canCreateDirectories = true

        return savePanel
    }

    @objc private func fileTypePopUpSelectionDidChange(_ popup: NSPopUpButton) {
        let fileType = popup.selectedItem?.representedObject as? UTType
        self.selectedFileType = fileType

        // save selected file mime type
        if fileType?.preferredFilenameExtension?.isEmpty == false,
           let mimeType = fileType?.preferredMIMEType {

            Self.preferredFileType[defaultsKey] = mimeType
        }
    }

    private(set) var selectedFileType: UTType? {
        get {
            self.allowedContentTypes.first
        }
        set {
            let oldFileExtension = selectedFileType?.preferredFilenameExtension
            let setRequiredFileType = NSSelectorFromString("setRequiredFileType:")
            if responds(to: setRequiredFileType) {
                // 1. make sure the panel has an old extension selected so it is replaced when we change it
                self.perform(setRequiredFileType, with: oldFileExtension)
                // 2. use good ol' working method to replace the extension
                self.perform(setRequiredFileType, with: newValue?.preferredFilenameExtension)
            } else { assertionFailure("NSSavePanel does not respond to setRequiredFileType:") }

            // 3. now since we‘ve done what we wanted, let‘s use a designated API which isn‘t (always) working
            // e.g. changing .xml -> .rss will change file extension, but .rss -> xml - won‘t  ¯\_(ツ)_/¯
            var fileTypes = newValue.map { [$0] } ?? []
            if newValue != .data {
                fileTypes.append(.data) // always allow any file type
            }
            self.allowedContentTypes = fileTypes
        }
    }

}
