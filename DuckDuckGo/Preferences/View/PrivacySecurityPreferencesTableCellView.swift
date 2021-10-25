//
//  PrivacySecurityPreferencesTableCellView.swift
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
import AppKit

protocol PrivacySecurityPreferencesTableCellViewDelegate: AnyObject {

    func privacySecurityPreferencesTableCellViewRequestedFireproofManagementModal(_ cell: PrivacySecurityPreferencesTableCellView)
    func privacySecurityPreferencesTableCellView(_ cell: PrivacySecurityPreferencesTableCellView, setLoginDetectionEnabled: Bool)
    func privacySecurtyPreferencesTableCellView( _ cell: PrivacySecurityPreferencesTableCellView, setGPCEnabled: Bool)

}

final class PrivacySecurityPreferencesTableCellView: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("PrivacySecurityPreferencesTableCellView")

    static func nib() -> NSNib {
        return NSNib(nibNamed: "PrivacySecurityPreferencesTableCellView", bundle: Bundle.main)!
    }

    @IBOutlet var loginDetectionCheckbox: NSButton!
    @IBOutlet var gpcCheckbox: NSButton!
    
    @IBOutlet var gpcDisclaimer: NSTextView!

    weak var delegate: PrivacySecurityPreferencesTableCellViewDelegate?
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        appendLearnMore()
    }
    
    func update(loginDetectionEnabled: Bool, gpcEnabled: Bool) {
        loginDetectionCheckbox.state = loginDetectionEnabled ? .on : .off
        gpcCheckbox.state = gpcEnabled ? .on : .off
    }

    @IBAction func manageFireproofWebsitesButtonClicked(_ sender: NSButton) {
        delegate?.privacySecurityPreferencesTableCellViewRequestedFireproofManagementModal(self)
    }

    @IBAction func toggledLoginDetectionCheckbox(_ sender: NSButton) {
        let loginDetectionEnabled = loginDetectionCheckbox.state == .on
        delegate?.privacySecurityPreferencesTableCellView(self, setLoginDetectionEnabled: loginDetectionEnabled)
    }
    
    @IBAction func toggledGPCCheckbox(_ sender: NSButton) {
        let gpcEnabled = gpcCheckbox.state == .on
        delegate?.privacySecurtyPreferencesTableCellView(self, setGPCEnabled: gpcEnabled)
    }
    
    func appendLearnMore() {
        let attrString = NSAttributedString(string: UserText.gpcLearnMore, attributes: [
            NSAttributedString.Key.link: URL.gpcLearnMore,
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
        ])
        gpcDisclaimer.linkTextAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            NSAttributedString.Key.foregroundColor: NSColor(named: "LinkBlueColor")!,
            NSAttributedString.Key.cursor: NSCursor.pointingHand
        ]
        let newStr = NSMutableAttributedString(attributedString: gpcDisclaimer.attributedString())
        newStr.append(attrString)
        gpcDisclaimer.textStorage?.setAttributedString(newStr)
    }
}

extension PrivacySecurityPreferencesTableCellView: NSTextViewDelegate {
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        if let link = link as? URL {
            WindowControllersManager.shared.show(url: link, newTab: true)
        } else if let link = link as? String,
            let url = URL(string: link) {
            WindowControllersManager.shared.show(url: url, newTab: true)
        }
        return true
    }
}
