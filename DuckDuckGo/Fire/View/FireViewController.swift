//
//  FireViewController.swift
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
import Lottie
import Combine

final class FireViewController: NSViewController {

    private var fireViewModel: FireViewModel
    private let tabCollectionViewModel: TabCollectionViewModel
    private var cancellables = Set<AnyCancellable>()

    private lazy var fireDialogViewController: FirePopoverViewController = {
        let storyboard = NSStoryboard(name: "Fire", bundle: nil)
        return storyboard.instantiateController(identifier: "FirePopoverViewController")
    }()

    @IBOutlet weak var fakeFireButton: NSButton!
    @IBOutlet weak var fireAnimationView: AnimationView!
    @IBOutlet weak var progressIndicatorWrapper: NSView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var progressIndicatorWrapperBG: NSView!

    required init?(coder: NSCoder) {
        fatalError("TabBarViewController: Bad initializer")
    }

    init?(coder: NSCoder,
          tabCollectionViewModel: TabCollectionViewModel,
          fireViewModel: FireViewModel = FireCoordinator.fireViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.fireViewModel = fireViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupFireAnimation()
        subscribeToIsBurning()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        self.view.superview?.isHidden = true
        subscribeToShouldPreventUserInteraction()
        progressIndicator.startAnimation(self)
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()

        progressIndicator.stopAnimation(self)
    }

    private var shouldPreventUserInteractioCancellable: AnyCancellable?
    private func subscribeToShouldPreventUserInteraction() {
        shouldPreventUserInteractioCancellable = fireViewModel.shouldPreventUserInteraction
            .sink { [weak self] shouldPreventUserInteraction in
                self?.view.superview?.isHidden = !shouldPreventUserInteraction
            }
    }

    private func setupView() {
        fakeFireButton.wantsLayer = true
        fakeFireButton.layer?.backgroundColor = NSColor.buttonMouseDownColor.cgColor
    }

    private func setupFireAnimation() {
        fireAnimationView.contentMode = .scaleToFill
    }

    private func subscribeToIsBurning() {
        fireViewModel.fire.$burningData
            .sink(receiveValue: { [weak self] burningData in
                guard let burningData = burningData,
                    let self = self else {
                        return
                    }

                self.animateFire(burningData: burningData)
            })
            .store(in: &cancellables)
    }

    func showDialog() {
        presentAsModalWindow(fireDialogViewController)
    }

    func animateFire(burningData: Fire.BurningData) {
        switch burningData {
        case .all: break
        case .specificDomains(let burningDomains):
            let localHistory = tabCollectionViewModel.tabCollection.localHistory
            if localHistory.isDisjoint(with: burningDomains) {
                // Do not play animation in this window since tabs aren't influenced
                return
            }
        }
        progressIndicatorWrapper.isHidden = true

        fireViewModel.isAnimationPlaying = true
        fireAnimationView.play { [weak self] _ in
            guard let self = self else { return }

            self.fireViewModel.isAnimationPlaying = false
            if self.fireViewModel.fire.burningData != nil {
                self.progressIndicatorWrapper.isHidden = false
                self.progressIndicatorWrapperBG.applyDropShadow()
            }
        }
    }

}
