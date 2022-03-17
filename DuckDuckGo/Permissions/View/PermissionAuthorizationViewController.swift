//
//  PermissionAuthorizationViewController.swift
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

import Cocoa

extension PermissionType {
    var localizedDescription: String {
        switch self {
        case .camera:
            return UserText.permissionCamera
        case .microphone:
            return UserText.permissionMicrophone
        case .geolocation:
            return UserText.permissionGeolocation
        case .popups:
            return UserText.permissionPopups
        }
    }
}

extension Array where Element == PermissionType {

    var localizedDescription: String {
        if Set(self) == Set([.camera, .microphone]) {
            return UserText.permissionCameraAndMicrophone
        } else if self.count == 1 {
            return self[0].localizedDescription
        }
        assertionFailure("Unexpected Permissions combination")
        return self.map(\.localizedDescription).joined(separator: ", ")
    }

}

final class PermissionAuthorizationViewController: NSViewController {

    @IBOutlet var descriptionLabel: NSTextField!

    weak var query: PermissionAuthorizationQuery? {
        didSet {
            updateText()
        }
    }

    override func viewDidLoad() {
        updateText()
    }

    private func updateText() {
        guard isViewLoaded,
              let query = query
        else { return }

        let format = query.permissions == [.popups]
            ? UserText.popupWindowsPermissionAuthorizationFormat
            : UserText.devicePermissionAuthorizationFormat
        self.descriptionLabel.stringValue = String(format: format,
                                                   query.domain,
                                                   query.permissions.localizedDescription)
    }

    @IBAction func grantAction(_ sender: NSButton) {
        self.dismiss()
        query?.handleDecision(grant: true)
    }

    @IBAction func denyAction(_ sender: NSButton) {
        self.dismiss()
        query?.handleDecision(grant: false)
    }

}
