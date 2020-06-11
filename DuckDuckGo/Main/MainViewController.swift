//
//  MainViewController.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import os.log

class MainViewController: NSViewController {

    @IBOutlet weak var navigationBarContainerView: NSView!
    @IBOutlet weak var webContainerView: NSView!

    var navigationBarViewController: NavigationBarViewController?
    var webViewController: WebViewController?

    var urlViewModel: URLViewModel? {
        didSet {
            navigationBarViewController?.urlViewModel = urlViewModel
        }
    }

    @IBSegueAction
    func createNavigationBarViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> NavigationBarViewController? {
        let navigationBarViewController = NavigationBarViewController(coder: coder)
        self.navigationBarViewController = navigationBarViewController
        navigationBarViewController?.delegate = self
        return navigationBarViewController
    }

    @IBSegueAction
    func createWebViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> WebViewController? {
        let webViewController = WebViewController(coder: coder)
        self.webViewController = webViewController
        return webViewController
    }

    private func loadURLInWebView() {
        guard let webViewController = webViewController else {
            os_log("%s: webViewController is nil", log: generalLog, type: .error, self.className)
            return
        }

        guard let url = urlViewModel?.url else {
            os_log("%s: urlViewModel is nil", log: generalLog, type: .error, self.className)
            return
        }

        webViewController.load(url: url)
    }
    
}

extension MainViewController: NavigationBarViewControllerDelegate {

    func navigationBarViewController(_ navigationBarViewController: NavigationBarViewController, textDidChange text: String) {}

    func navigationBarViewControllerDidConfirmInput(_ navigationBarViewController: NavigationBarViewController) {
        if let url = URL.makeURL(from: navigationBarViewController.searchField.stringValue) {
            urlViewModel = URLViewModel(url: url)
        } else {
            urlViewModel = nil
        }

        loadURLInWebView()
    }

}
