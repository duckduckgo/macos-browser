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

@MainActor
final class FireViewController: NSViewController {

    enum Const {
        static let animationName = "01_Fire_really_small"
    }

    private(set) var fireViewModel: FireViewModel
    private let tabCollectionViewModel: TabCollectionViewModel
    private var cancellables = Set<AnyCancellable>()

    private lazy var fireDialogViewController: FirePopoverViewController = {
        let storyboard = NSStoryboard(name: "Fire", bundle: nil)
        return storyboard.instantiateController(identifier: "FirePopoverViewController")
    }()

    @IBOutlet weak var deletingDataLabel: NSTextField!
    @IBOutlet weak var fakeFireButton: NSButton!
    @IBOutlet weak var progressIndicatorWrapper: NSView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var progressIndicatorWrapperBG: NSView!
    private var fireAnimationView: LottieAnimationView?
    private var fireAnimationViewLoadingTask: Task<(), Never>?
    private(set) lazy var fireIndicatorVisibilityManager = FireIndicatorVisibilityManager { [weak self] in self?.view.superview }

    static func create(tabCollectionViewModel: TabCollectionViewModel, fireViewModel: FireViewModel? = nil) -> FireViewController {
        NSStoryboard(name: "Fire", bundle: nil).instantiateInitialController { coder in
            self.init(coder: coder, tabCollectionViewModel: tabCollectionViewModel, fireViewModel: fireViewModel)
        }!
    }

    required init?(coder: NSCoder) {
        fatalError("TabBarViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel, fireViewModel: FireViewModel? = nil) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.fireViewModel = fireViewModel ?? FireCoordinator.fireViewModel

        super.init(coder: coder)
    }

    deinit {
        fireAnimationViewLoadingTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        deletingDataLabel.stringValue = UserText.fireDialogDelitingData
        if case .normal = NSApp.runType {
            fireAnimationViewLoadingTask = Task.detached(priority: .userInitiated) {
                await self.setupFireAnimationView()
            }
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        subscribeToFireAnimationEvents()
        progressIndicator.startAnimation(self)
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()

        progressIndicator.stopAnimation(self)
    }

    private var fireAnimationEventsCancellable: AnyCancellable?
    private func subscribeToFireAnimationEvents() {
        fireAnimationEventsCancellable = fireViewModel.isFirePresentationInProgress
            .sink { [weak self] shouldShowFirePresentation in
                self?.fireIndicatorVisibilityManager.updateVisibility(shouldShowFirePresentation)
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

        animationView.animationSpeed = fireAnimationSpeed

        fakeFireButton.wantsLayer = true
        fakeFireButton.layer?.backgroundColor = NSColor.buttonMouseDown.cgColor

        fakeFireButton.setAccessibilityIdentifier("FireViewController.fakeFireButton")
        subscribeToIsBurning()
    }

    private func subscribeToIsBurning() {
        fireViewModel.fire.$burningData
            .sink(receiveValue: { [weak self] burningData in
                guard let burningData = burningData,
                    let self = self else {
                        return
                    }

                switch burningData {
                case .all, .specificDomains(_, shouldPlayFireAnimation: true):
                    Task {
                        await self.animateFire(burningData: burningData)
                    }
                case .specificDomains(_, shouldPlayFireAnimation: false):
                    break
                }
            })
            .store(in: &cancellables)
    }

    func showDialog() {
        presentAsModalWindow(fireDialogViewController)
    }

    private let fireAnimationSpeed = 1.2
    private let fireAnimationBeginning = 0.1
    private let fireAnimationEnd = 0.63

    func animateFireWhenClosing() async {
        await waitForFireAnimationViewIfNeeded()
        await withUnsafeContinuation { (continuation: UnsafeContinuation<Void, Never>) in
            progressIndicatorWrapper.isHidden = true
            fakeFireButton.isHidden = true
            fireViewModel.isAnimationPlaying = true

            fireAnimationView?.currentProgress = 0
            let completion = { [fireViewModel] in
                fireViewModel.isAnimationPlaying = false
                continuation.resume()
            }
            fireAnimationView?.play(fromProgress: fireAnimationBeginning, toProgress: fireAnimationEnd) { [weak self] _ in
                defer { completion() }
                guard let self = self else { return }

                self.progressIndicatorWrapper.isHidden = false
                self.fakeFireButton.isHidden = false

            } ?? completion() // Resume immediately if fireAnimationView is nil
        }
    }

    @MainActor
    private func animateFire(burningData: Fire.BurningData) async {
        var playFireAnimation = true

        // Animate just on the active window
        let lastKeyWindowController = WindowControllersManager.shared.lastKeyMainWindowController
        if view.window?.windowController !== lastKeyWindowController {
            playFireAnimation = false
        }

        if playFireAnimation {
            await waitForFireAnimationViewIfNeeded()

            progressIndicatorWrapper.isHidden = true
            fireViewModel.isAnimationPlaying = true

            fireViewModel.fire.fireAnimationDidStart()
            fireAnimationView?.currentProgress = 0
            fireAnimationView?.play(fromProgress: fireAnimationBeginning, toProgress: fireAnimationEnd) { [weak self, fireViewModel] _ in
                fireViewModel.isAnimationPlaying = false
                fireViewModel.fire.fireAnimationDidFinish()

                guard let self = self else { return }

                // If not finished yet, present the progress indicator
                if self.fireViewModel.fire.burningData != nil {

                    // Waits until windows are closed in Fire.swift
                    DispatchQueue.main.async {
                        self.progressIndicatorWrapper.isHidden = false
                        self.progressIndicatorWrapperBG.applyDropShadow()
                    }
                }
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
    func createAnimationView() async -> LottieAnimationView? {
        guard let animation = await animation else {
            return nil
        }
        let view = LottieAnimationView(animation: animation)
        view.identifier = .init(rawValue: animationName)
        return view
    }

    private init(animationName: String) {
        self.animationName = animationName
    }

    private let animationName: String

    private var animation: LottieAnimation? {
        LottieAnimation.named(animationName, animationCache: LottieAnimationCache.shared)
    }
}

/**
 * This class is responsible for showing the modal dialog during burning process.
 *
 * It ensures that the dialog, once shown, stays on screen for at least 1 second.
 */
final class FireIndicatorVisibilityManager {
    var view: () -> NSView?

    init(_ view: @escaping () -> NSView?) {
        self.view = view
    }

    func updateVisibility(_ shouldShow: Bool) {
        if shouldShow {
            fireIndicatorDialogPresentedAt = Date()
            timer?.invalidate()
            view()?.isHidden = false
        } else {
            if let fireIndicatorDialogPresentedAt {
                let presentationDuration = Date().timeIntervalSince(fireIndicatorDialogPresentedAt)
                self.fireIndicatorDialogPresentedAt = nil
                if presentationDuration > Self.fireIndicatorPresentationDuration {
                    view()?.isHidden = true
                } else {
                    let remainingPresentationTime = Self.fireIndicatorPresentationDuration - presentationDuration
                    timer = Timer.scheduledTimer(withTimeInterval: remainingPresentationTime, repeats: false) { [weak self] _ in
                        self?.view()?.isHidden = true
                    }
                }
            } else {
                view()?.isHidden = true
            }
        }
    }

    private var fireIndicatorDialogPresentedAt: Date?
    private var timer: Timer?
    private static let fireIndicatorPresentationDuration = TimeInterval.seconds(1)
}
