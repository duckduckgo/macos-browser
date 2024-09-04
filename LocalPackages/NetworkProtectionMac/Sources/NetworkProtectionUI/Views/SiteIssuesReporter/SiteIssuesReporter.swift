//
//  SiteIssuesReporter.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Foundation
import PixelKit
import VPNPixels

public struct SiteIssuesReporter {

    private let pixelKit: PixelFiring?

    public init(pixelKit: PixelFiring? = PixelKit.shared) {
        self.pixelKit = pixelKit
    }

    private func makeAlert(title: String, message: String? = nil, buttonNames: [String] = ["Ok"]) -> NSAlert{

        let alert = NSAlert()
        alert.messageText = title

        if let message = message {
            alert.informativeText = message
        }

        for buttonName in buttonNames {
            alert.addButton(withTitle: buttonName)
        }
        alert.accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 0))
        return alert
    }

    public func askUserToReportIssues(withDomain domain: String) {
        let alert = makeAlert(title: "Report Site Issues?",
                              message: "Help us improve by anonymously reporting that \(domain) doesn't work correctly through the VPN.",
                              buttonNames: ["Report", "Don't Report"])

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let pixel: SiteTroubleshootingPixel = .reportIssues(domain: domain)
            pixelKit?.fire(pixel)
        }
    }
}
