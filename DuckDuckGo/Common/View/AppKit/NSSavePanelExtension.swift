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

    static private let fileTypesPopupTag = 100

    private var fileTypesPopup: NSPopUpButton? {
        self.accessoryView?.viewWithTag(Self.fileTypesPopupTag) as? NSPopUpButton
    }

    var selectedFileType: UTType? {
        self.fileTypesPopup?.selectedItem?.representedObject as? UTType
    }

    @UserDefaultsWrapper(key: .saveAsPreferredFileType, defaultValue: nil)
    static private var preferredFileType: String?

    static func withFileTypeChooser(fileTypes: [UTType], suggestedFilename: String?, directoryURL: URL? = nil) -> NSSavePanel {
        let savePanel = NSSavePanel()

        guard let nib = NSNib(nibNamed: "SavePanelAccessoryView", bundle: .main) else {
            fatalError("Could not load nib named \"SavePanel\"")
        }
        nib.instantiate(withOwner: savePanel, topLevelObjects: nil)

        guard let popup = savePanel.fileTypesPopup else {
            fatalError("NSSavePanel: accessoryView not loaded")
        }
        popup.target = savePanel
        popup.action = #selector(NSSavePanel.fileTypePopUpSelectionDidChange(_:))

        popup.removeAllItems()
        var selectedItem: NSMenuItem?
        let preferredFileType = Self.preferredFileType.map(UTType.init(mimeType:))
        for fileType in fileTypes {
            popup.addItem(withTitle: "\(fileType.description ?? "") (.\(fileType.fileExtension ?? ""))")
            let item = popup.item(at: popup.numberOfItems - 1)
            item?.representedObject = fileType

            if selectedItem == nil || fileType == preferredFileType {
                selectedItem = item
            }
        }
        popup.select(selectedItem)
        savePanel.fileTypePopUpSelectionDidChange(popup)

        if let suggestedFilename = suggestedFilename {
            savePanel.nameFieldStringValue = suggestedFilename
        }
        if let directoryURL = directoryURL {
            savePanel.directoryURL = directoryURL
        }
        savePanel.canCreateDirectories = true

        return savePanel
    }

    @objc private func fileTypePopUpSelectionDidChange(_ popup: NSPopUpButton) {
        guard let fileType = popup.selectedItem?.representedObject as? UTType else {
            if #available(macOS 11.0, *) {
                self.allowedContentTypes = []
            } else {
                self.allowedFileTypes = nil
            }
            return
        }
        if fileType.fileExtension?.isEmpty == false,
           let mimeType = fileType.mimeType {
            Self.preferredFileType = mimeType
        }
        if #available(macOS 11.0, *) {
            guard let fileExtension = fileType.fileExtension else {
                self.allowedContentTypes = []
                return
            }
            self.allowedContentTypes = [UniformTypeIdentifiers.UTType.init(filenameExtension: fileExtension)].compactMap { $0 }
        } else {
            self.allowedFileTypes = [fileType.rawValue as String]
        }
    }

}
