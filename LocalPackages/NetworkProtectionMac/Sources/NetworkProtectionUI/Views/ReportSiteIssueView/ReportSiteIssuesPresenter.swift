//
//  ReportSiteIssuesPresenter.swift
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

public extension UserDefaults {
    private var vpnReportSiteIssuesDontAskAgainKey: String {
        "vpnReportSiteIssuesDontAskAgain"
    }

    @objc
    dynamic var vpnReportSiteIssuesDontAskAgain: Bool {
        get {
            bool(forKey: vpnReportSiteIssuesDontAskAgainKey)
        }

        set {
            set(newValue, forKey: vpnReportSiteIssuesDontAskAgainKey)
        }
    }

    func resetVPNReportSiteIssuesDontAskAgain() {
        removeObject(forKey: vpnReportSiteIssuesDontAskAgainKey)
    }
}

public final class ReportSiteIssuesPresenter {

    private let userDefaults: UserDefaults
    private let pixelKit: PixelKit?

    /// Default initializer
    ///
    /// - Parameters:
    ///     - userDefaults: the user defaults to use to store the "don't ask again" option
    ///     - pixelKit: the ``PixelKit`` instance to use for firing pixels.
    ///
    public init(userDefaults: UserDefaults, pixelKit: PixelKit? = .shared) {
        self.userDefaults = userDefaults
        self.pixelKit = pixelKit
    }

    private var dontAskAgain: Bool {
        get {
            userDefaults.vpnReportSiteIssuesDontAskAgain
        }

        set {
            userDefaults.vpnReportSiteIssuesDontAskAgain = newValue
        }
    }

    /// Shows the ``ReportSiteIssuesView`` view modally if reporting is enabled.
    ///
    /// This presenter helps keep the view abstracted from our VPN business logic.  This is the point where
    /// our code can decide whether to show the view or not, and to take action based on what buttons are
    /// clicked on the view.
    ///
    /// - Parameters:
    ///     - domain: the domain to show in the view
    ///     - parentWindow: the parent window to show the view in (as a sheet).  If no parent window is provided the view
    ///         will be presented as a stand-alone modal.
    ///
    public func show(withDomain domain: String, in parentWindow: NSWindow?) async {

        guard !dontAskAgain else {
            return
        }

        let reportIssuesView = ReportSiteIssuesView(domain: domain) { [weak self] dismiss in
            guard let self else { return }

            let pixel: SiteTroubleshootingPixel = .reportIssues(domain: domain)
            pixelKit?.fire(pixel)

            dismiss()
        } cancelAction: { dismiss in
            dismiss()
        } dontAskAgainAction: { [weak self] dismiss in
            guard let self else { return }

            dontAskAgain = true
            dismiss()
        }

        await reportIssuesView.show(in: parentWindow)
    }
}
