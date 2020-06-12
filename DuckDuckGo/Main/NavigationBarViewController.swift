//
//  NavigationBarViewController.swift
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

protocol NavigationBarViewControllerDelegate: AnyObject {

    func navigationBarViewController(_ navigationBarViewController: NavigationBarViewController, urlDidChange urlViewModel: URLViewModel?)

}

class NavigationBarViewController: NSViewController {

    @IBOutlet weak var searchField: NSSearchField!

    var urlViewModel: URLViewModel? {
        didSet {
            refreshSearchField()
        }
    }

    weak var delegate: NavigationBarViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        searchField.delegate = self
    }

    private func refreshSearchField() {
        searchField.stringValue = urlViewModel?.addressBarRepresentation ?? ""
    }

    private func refreshUrlViewModel() {
        urlViewModel = URLViewModel(addressBarString: searchField.stringValue)

        delegate?.navigationBarViewController(self, urlDidChange: urlViewModel)
    }
    
}

extension NavigationBarViewController: NSSearchFieldDelegate {

    func controlTextDidEndEditing(_ obj: Notification) {
        let textMovement = obj.userInfo?["NSTextMovement"] as? Int
        if textMovement == NSReturnTextMovement {
            refreshUrlViewModel()
        }
    }

    func controlTextDidChange(_ obj: Notification) {

    }

}
