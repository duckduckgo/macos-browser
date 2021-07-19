//
//  CrashReportPromptPresenter.swift
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

#if OUT_OF_APPSTORE

final class CrashReportPromptPresenter {

    lazy var windowController: NSWindowController = {
        let storyboard = NSStoryboard(name: "CrashReports", bundle: nil)
        return storyboard.instantiateController(identifier: "CrashReportPromptWindowController")
    }()

    var viewController: CrashReportPromptViewController {
        // swiftlint:disable force_cast
        return windowController.contentViewController as! CrashReportPromptViewController
        // swiftlint:enable force_cast
    }

    func showPrompt(_ delegate: CrashReportPromptViewControllerDelegate, for crashReport: CrashReport) {
        viewController.delegate = delegate
        viewController.crashReport = crashReport

        windowController.showWindow(self)
        windowController.window?.center()
    }

}

#endif
