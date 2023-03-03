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
        fileTypesPopup?.itemArray.compactMap { ($0.representedObject as? UTType)?.mimeType }.joined(separator: ";") ?? ""
    }

    static func savePanelWithFileTypeChooser(fileTypes: [UTType], suggestedFilename: String?, directoryURL: URL? = nil) -> NSSavePanel {
        let savePanel = NSSavePanel()

        if !fileTypes.isEmpty {
            let accessoryView = SavePanelAccessoryView()
            savePanel.accessoryView = accessoryView
            let popup = accessoryView.fileTypesPopup

            popup.target = savePanel
            popup.action = #selector(NSSavePanel.fileTypePopUpSelectionDidChange(_:))

            for fileType in fileTypes {
                popup.addItem(withTitle: "\(fileType.description ?? "") (.\(fileType.fileExtension ?? ""))")
                let item = popup.item(at: popup.numberOfItems - 1)
                item?.representedObject = fileType
            }
        }
        savePanel.isExtensionHidden = false

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
        if fileType?.fileExtension?.isEmpty == false,
           let mimeType = fileType?.mimeType {

            Self.preferredFileType[defaultsKey] = mimeType
        }
    }

    private(set) var selectedFileType: UTType? {
        get {
            if #available(macOS 11.0, *) {
                guard let contentType = self.allowedContentTypes.first else { return nil }
                return UTType(rawValue: contentType.identifier as CFString)
            } else {
                guard let fileType = self.allowedFileTypes?.first else { return nil }
                return UTType(rawValue: fileType as CFString)
            }
        }
        set {
            let oldFileExtension = selectedFileType?.fileExtension
            let setRequiredFileType = NSSelectorFromString("setRequiredFileType:")
            if responds(to: setRequiredFileType) {
                // 1. make sure the panel has an old extension selected so it is replaced when we change it
                self.perform(setRequiredFileType, with: oldFileExtension)
                // 2. use good ol' working method to replace the extension
                self.perform(setRequiredFileType, with: newValue?.fileExtension)
            } else { assertionFailure("NSSavePanel does not respond to setRequiredFileType:") }

            // 3. now since we‘ve done what we wanted, let‘s use a designated API which isn‘t (always) working
            // e.g. changing .xml -> .rss will change file extension, but .rss -> xml - won‘t  ¯\_(ツ)_/¯
            if #available(macOS 11.0, *) {
                self.allowedContentTypes = (newValue.flatMap { UniformTypeIdentifiers.UTType($0.rawValue as String) }.map { [$0] } ?? [])
                    + [UniformTypeIdentifiers.UTType.data] // always allow any file type
            } else {
                self.allowedFileTypes = (newValue.map { [$0.rawValue as String] } ?? [])
                    + [UTType.data.rawValue as String] // always allow any file type
            }
        }
    }

}
