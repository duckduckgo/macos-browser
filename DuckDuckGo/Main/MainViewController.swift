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
    var browserTabViewController: BrowserTabViewController?

    @IBSegueAction
    func createNavigationBarViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> NavigationBarViewController? {
        let navigationBarViewController = NavigationBarViewController(coder: coder)
        self.navigationBarViewController = navigationBarViewController
        navigationBarViewController?.delegate = self
        return navigationBarViewController
    }

    @IBSegueAction
    func createWebViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> BrowserTabViewController? {
        let browserTabViewController = BrowserTabViewController(coder: coder)
        self.browserTabViewController = browserTabViewController
        browserTabViewController?.delegate = self
        return browserTabViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSAppleEventManager
            .shared()
            .setEventHandler(
                self,
                andSelector: #selector(handleURL(event:reply:)),
                forEventClass: AEEventClass(kInternetEventClass),
                andEventID: AEEventID(kAEGetURL)
            )

    }

    @objc func handleURL(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let path = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue?.removingPercentEncoding,
            let url = URL(string: path) else { return }
            
        let model = URLViewModel(url: url)
        browserTabViewController?.urlViewModel = model
        navigationBarViewController?.urlViewModel = model
    }

}

extension MainViewController: NavigationBarViewControllerDelegate {

    func navigationBarViewController(_ navigationBarViewController: NavigationBarViewController, urlDidChange urlViewModel: URLViewModel?) {
        browserTabViewController?.urlViewModel = urlViewModel
    }

}

extension MainViewController: BrowserTabViewControllerDelegate {

    func browserTabViewController(_ browserTabViewController: BrowserTabViewController, urlDidChange urlViewModel: URLViewModel?) {
        navigationBarViewController?.urlViewModel = urlViewModel
    }

}
