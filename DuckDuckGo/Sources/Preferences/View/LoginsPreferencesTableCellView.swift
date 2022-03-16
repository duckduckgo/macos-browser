//
//  LoginsPreferencesTableCellView.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

protocol LoginsPreferencesTableCellViewDelegate: AnyObject {

    func loginsPreferencesTableCellView(_ cell: LoginsPreferencesTableCellView,
                                        setShouldAutoLockLogins: Bool,
                                        autoLockThreshold: LoginsPreferences.AutoLockThreshold)

}

final class LoginsPreferencesTableCellView: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("LoginsPreferencesTableCellView")
    private static let nibName = "LoginsPreferencesTableCellView"

    static func nib() -> NSNib {
        return NSNib(nibNamed: nibName, bundle: Bundle.main)!
    }
    
    @IBOutlet var autoLockEnabledRadioButton: NSButton!
    @IBOutlet var autoLockDisabledRadioButton: NSButton!
    @IBOutlet var autoLockThresholdPopUpButton: NSPopUpButton!
    
    weak var delegate: LoginsPreferencesTableCellViewDelegate?

    private var loginPreferences = LoginsPreferences()

    @IBAction func autoLockEnabledPreferenceChanged(_ sender: AnyObject) {
        notifyDelegateOfPreferenceChanges()
        refreshInterface()
    }
    
    @IBAction func autoLockThresholdChanged(_ sender: AnyObject) {
        notifyDelegateOfPreferenceChanges()
        refreshInterface()
    }

    func update(autoLockEnabled: Bool, threshold: LoginsPreferences.AutoLockThreshold) {
        if autoLockEnabled {
            autoLockEnabledRadioButton.state = .on
        } else {
            autoLockDisabledRadioButton.state = .on
        }

        autoLockThresholdPopUpButton.removeAllItems()
        
        for threshold in LoginsPreferences.AutoLockThreshold.allCases {
            autoLockThresholdPopUpButton.addItem(withTitle: threshold.title)
            autoLockThresholdPopUpButton.lastItem?.representedObject = threshold
        }
        
        autoLockThresholdPopUpButton.selectItem(withTitle: threshold.title)
        refreshInterface()
    }
    
    private func refreshInterface() {
        autoLockThresholdPopUpButton.isEnabled = (autoLockEnabledRadioButton.state == .on)
    }
    
    private func notifyDelegateOfPreferenceChanges() {
        let shouldAutoLock = (autoLockEnabledRadioButton.state == .on)
        let threshold = (autoLockThresholdPopUpButton.selectedItem?.representedObject as? LoginsPreferences.AutoLockThreshold) ?? .fifteenMinutes
        
        delegate?.loginsPreferencesTableCellView(self, setShouldAutoLockLogins: shouldAutoLock, autoLockThreshold: threshold)
    }
    
}
