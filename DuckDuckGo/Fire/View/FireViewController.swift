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

    enum Const {
        static let animationName = "01_Fire_really_small"
    }

    private var fireViewModel: FireViewModel
    private let tabCollectionViewModel: TabCollectionViewModel
    private var cancellables = Set<AnyCancellable>()

    private lazy var fireDialogViewController: FirePopoverViewController = {
        let storyboard = NSStoryboard(name: "Fire", bundle: nil)
        return storyboard.instantiateController(identifier: "FirePopoverViewController")
    }()

    @IBOutlet weak var fakeFireButton: NSButton!
    @IBOutlet weak var progressIndicatorWrapper: NSView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var progressIndicatorWrapperBG: NSView!
    private var fireAnimationView: AnimationView?
    private var fireAnimationViewLoadingTask: Task<(), Never>?

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

    deinit {
        fireAnimationViewLoadingTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        fireAnimationViewLoadingTask = Task.detached(priority: .userInitiated) {
            await self.setupFireAnimationView()
        }
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

    private var shouldPreventUserInteractionCancellable: AnyCancellable?
    private func subscribeToShouldPreventUserInteraction() {
        shouldPreventUserInteractionCancellable = fireViewModel.shouldPreventUserInteraction
            .sink { [weak self] shouldPreventUserInteraction in
                self?.view.superview?.isHidden = !shouldPreventUserInteraction
            }
    }

    @MainActor
    private func setupFireAnimationView() async {
        guard let animationView = await FireAnimationViewLoader.shared.createAnimationView() else {
            return
        }

        animationView.contentMode = .scaleToFill
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView, positioned: .below, relativeTo: progressIndicatorWrapper)
        let constraints = animationView.addConstraints(to: view, [
            .top: .top(),
            .bottom: .bottom(),
            .leading: .leading(),
            .trailing: .trailing()
        ])
        NSLayoutConstraint.activate(constraints)
        fireAnimationView = animationView

        fakeFireButton.wantsLayer = true
        fakeFireButton.layer?.backgroundColor = NSColor.buttonMouseDownColor.cgColor

        subscribeToIsBurning()
    }

    private func subscribeToIsBurning() {
        fireViewModel.fire.$burningData
            .sink(receiveValue: { [weak self] burningData in
                guard let burningData = burningData,
                    let self = self else {
                        return
                    }

                Task {
                    await self.animateFire(burningData: burningData)
                }
            })
            .store(in: &cancellables)
    }

    func showDialog() {
        presentAsModalWindow(fireDialogViewController)
    }

    @MainActor
    private func animateFire(burningData: Fire.BurningData) async {
        switch burningData {
        case .all: break
        case .specificDomains(let burningDomains):
            if tabCollectionViewModel.localHistory.isDisjoint(with: burningDomains) {
                // Do not play animation in this window since tabs aren't influenced
                return
            }
        }

        await waitForFireAnimationViewIfNeeded()

        progressIndicatorWrapper.isHidden = true
        fireViewModel.isAnimationPlaying = true

        fireAnimationView?.play { [weak self] _ in
            guard let self = self else { return }

            self.fireViewModel.isAnimationPlaying = false
            if self.fireViewModel.fire.burningData != nil {
                self.progressIndicatorWrapper.isHidden = false
                self.progressIndicatorWrapperBG.applyDropShadow()
            }
        }
    }

    private func waitForFireAnimationViewIfNeeded() async {
        if fireAnimationView == nil {
            await fireAnimationViewLoadingTask?.value
        }
    }
}

/**
 * This actor creates Fire animation views by loading animation always on a background thread.
 *
 * We use animation cache for Lottie animations, so as soon as the first animation is loaded,
 * subsequent views would use the cache. However, the first load takes between 0.5 and 3 seconds
 * and would contribute to application start-up time (before any window is shown) if done synchronously.
 */
private actor FireAnimationViewLoader {

    static let shared: FireAnimationViewLoader = .init(animationName: FireViewController.Const.animationName)

    @MainActor
    func createAnimationView() async -> AnimationView? {
        guard let animation = await animation else {
            return nil
        }
        let view = AnimationView(animation: animation)
        view.identifier = .init(rawValue: animationName)
        return view
    }

    private init(animationName: String) {
        self.animationName = animationName
    }

    private let animationName: String

    private var animation: Animation? {
        Animation.named(animationName, animationCache: LottieAnimationCache.shared)
    }
}
