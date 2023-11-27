//
//  PreferencesViewController.swift
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

import AppKit
import SwiftUI
import Combine

final class PreferencesViewController: NSViewController {

    weak var delegate: BrowserTabSelectionDelegate?

    let model = PreferencesSidebarModel(includeDuckPlayer: DuckPlayer.shared.isAvailable)
    private var selectedTabIndexCancellable: AnyCancellable?
    private var selectedPreferencePaneCancellable: AnyCancellable?

    private var bitwardenManager: BWManagement = BWManager.shared

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let host = NSHostingView(rootView: Preferences.RootView(model: model))
        view.addAndLayout(host)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        model.refreshSections()
        bitwardenManager.refreshStatusIfNeeded()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        selectedTabIndexCancellable = model.$selectedTabIndex
            .dropFirst()
            .sink { [weak self] index in
                self?.delegate?.selectedTab(at: index)
            }

        selectedPreferencePaneCancellable = model.$selectedPane
            .dropFirst()
            .sink { [weak self] identifier in
                self?.delegate?.selectedPreferencePane(identifier)
            }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        selectedTabIndexCancellable?.cancel()
        selectedTabIndexCancellable = nil
        selectedPreferencePaneCancellable?.cancel()
        selectedPreferencePaneCancellable = nil
    }
}
