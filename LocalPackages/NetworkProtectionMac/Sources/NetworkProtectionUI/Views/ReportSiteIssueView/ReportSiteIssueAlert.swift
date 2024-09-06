//
//  ReportSiteIssueAlert.swift
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
import SwiftUIExtensions
import VPNPixels

public struct ReportSiteIssueAlert {

    private let pixelKit: PixelFiring?

    public init(pixelKit: PixelFiring? = PixelKit.shared) {
        self.pixelKit = pixelKit
    }

    public func askUserToReportIssues(withDomain domain: String, in parentWindow: NSWindow?) async {
        let reportIssuesView = ReportSiteIssuesView(domain: domain) { dismiss in

            let pixel: SiteTroubleshootingPixel = .reportIssues(domain: domain)
            pixelKit?.fire(pixel)

            dismiss()
        } cancelAction: { dismiss in
            dismiss()
        } dontShowAgainAction: { dismiss in
            dismiss()
        }

        await reportIssuesView.show(in: parentWindow)
    }
}
