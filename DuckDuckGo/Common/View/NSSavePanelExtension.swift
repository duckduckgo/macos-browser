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

extension NSSavePanel {

    static private let fileTypesPopupTag = 100

    private var fileTypesPopup: NSPopUpButton? {
        self.accessoryView?.viewWithTag(Self.fileTypesPopupTag) as? NSPopUpButton
    }

    var selectedFileType: UTType? {
        self.fileTypesPopup?.selectedItem?.representedObject as? UTType
    }

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
        for fileType in fileTypes {
            popup.addItem(withTitle: "\(fileType.description ?? "") (.\(fileType.fileExtension ?? ""))")
            popup.item(at: popup.numberOfItems - 1)?.representedObject = fileType
        }
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
        guard let ext = popup.selectedItem?.representedObject as? UTType else {
            self.allowedFileTypes = nil
            return
        }
        self.allowedFileTypes = [ext.rawValue as String]
    }

}
