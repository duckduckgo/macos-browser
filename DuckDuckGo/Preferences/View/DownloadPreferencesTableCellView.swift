//
//  DownloadPreferencesTableCellView.swift
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

import Foundation

protocol DownloadPreferencesTableCellViewDelegate: class {

    func downloadPreferencesTableCellViewRequestedDownloadLocationPicker(_ cell: DownloadPreferencesTableCellView)
    func downloadPreferencesTableCellView(_ cell: DownloadPreferencesTableCellView, setAlwaysRequestDownloadLocation: Bool)

}

final class DownloadPreferencesTableCellView: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("DownloadPreferencesTableCellView")

    static func nib() -> NSNib {
        return NSNib(nibNamed: "DownloadPreferencesTableCellView", bundle: Bundle.main)!
    }

    @IBOutlet var downloadLocationPathControl: NSPathControl! {
        didSet {
            downloadLocationPathControl.wantsLayer = true
            downloadLocationPathControl.layer?.cornerRadius = 3.0
            downloadLocationPathControl.layer?.borderColor = NSColor.quaternaryLabelColor.cgColor
            downloadLocationPathControl.layer?.borderWidth = 1.0
        }
    }

    @IBOutlet var changeLocationButton: NSButton!
    @IBOutlet var alwaysRequestDownloadLocationCheckbox: NSButton!

    weak var delegate: DownloadPreferencesTableCellViewDelegate?

    @IBAction func changeLocationButtonClicked(_ sender: NSButton) {
        delegate?.downloadPreferencesTableCellViewRequestedDownloadLocationPicker(self)
    }

    @IBAction func toggledAlwaysRequestDownloadLocationCheckbox(_ sender: NSButton) {
        let alwaysRequestDownloadLocation = alwaysRequestDownloadLocationCheckbox.state == .on
        updateInterface(downloadLocationSelectionEnabled: !alwaysRequestDownloadLocation)
        delegate?.downloadPreferencesTableCellView(self, setAlwaysRequestDownloadLocation: alwaysRequestDownloadLocation)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        downloadLocationPathControl.layer?.borderColor = NSColor(named: "SeparatorColor")!.cgColor
    }

    func update(downloadLocation: URL?, alwaysRequestDownloadLocation: Bool) {
        downloadLocationPathControl.url = downloadLocation
        alwaysRequestDownloadLocationCheckbox.state = alwaysRequestDownloadLocation ? .on : .off
        updateInterface(downloadLocationSelectionEnabled: !alwaysRequestDownloadLocation)
    }

    private func updateInterface(downloadLocationSelectionEnabled: Bool) {
        changeLocationButton.isEnabled = downloadLocationSelectionEnabled
        downloadLocationPathControl.isEnabled = downloadLocationSelectionEnabled
        downloadLocationPathControl.alphaValue = downloadLocationSelectionEnabled ? 1 : 0.5
    }

}
