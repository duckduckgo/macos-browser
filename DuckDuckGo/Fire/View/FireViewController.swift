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

    private lazy var deletingDataLabel = NSTextField(string: UserText.fireDialogDelitingData)
    private lazy var fakeFireButton = NSButton(image: .burn, target: nil, action: nil)
    private lazy var progressIndicatorWrapper = NSView()
    private lazy var progressIndicator = NSProgressIndicator()
    private lazy var progressIndicatorWrapperBG = ColorView(frame: .zero, backgroundColor: .fireBackground, cornerRadius: 8)

    private var fireAnimationView: LottieAnimationView?
    private var fireAnimationViewLoadingTask: Task<(), Never>?

    init(tabCollectionViewModel: TabCollectionViewModel, fireViewModel: FireViewModel? = nil) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.fireViewModel = fireViewModel ?? FireCoordinator.fireViewModel

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("TabBarViewController: Bad initializer")
    }

    override func loadView() {
        view = ColorView(frame: .zero, backgroundColor: .fireBackground)

        fakeFireButton.translatesAutoresizingMaskIntoConstraints = false
        fakeFireButton.contentTintColor = .button
        fakeFireButton.alignment = .center
        fakeFireButton.bezelStyle = .shadowlessSquare
        fakeFireButton.isBordered = false
        fakeFireButton.imagePosition = .imageOnly
        fakeFireButton.imageScaling = .scaleProportionallyDown
        fakeFireButton.wantsLayer = true
        fakeFireButton.layer?.backgroundColor = NSColor.buttonMouseDown.cgColor
        fakeFireButton.layer?.cornerRadius = 4
        fakeFireButton.setAccessibilityIdentifier("FireViewController.fakeFireButton")

        progressIndicatorWrapperBG.translatesAutoresizingMaskIntoConstraints = false

        let imageView = NSImageView(image: .burnAlert)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(NSLayoutConstraint.Priority(rawValue: 251), for: .horizontal)
        imageView.setContentHuggingPriority(NSLayoutConstraint.Priority(rawValue: 251), for: .vertical)
        imageView.imageScaling = .scaleProportionallyDown

        deletingDataLabel.translatesAutoresizingMaskIntoConstraints = false
        deletingDataLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        deletingDataLabel.setContentHuggingPriority(NSLayoutConstraint.Priority(rawValue: 251), for: .horizontal)
        deletingDataLabel.isEditable = false
        deletingDataLabel.isBordered = false
        deletingDataLabel.isSelectable = false
        deletingDataLabel.drawsBackground = false
        deletingDataLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        deletingDataLabel.lineBreakMode = .byClipping
        deletingDataLabel.textColor = .labelColor

        progressIndicator.isIndeterminate = true
        progressIndicator.maxValue = 100
        progressIndicator.style = .bar
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false

        progressIndicatorWrapper.translatesAutoresizingMaskIntoConstraints = false
        progressIndicatorWrapper.setCornerRadius(8)
        progressIndicatorWrapper.addSubview(progressIndicatorWrapperBG)
        progressIndicatorWrapper.addSubview(progressIndicator)
        progressIndicatorWrapper.addSubview(imageView)
        progressIndicatorWrapper.addSubview(deletingDataLabel)

        view.addSubview(progressIndicatorWrapper)
        view.addSubview(fakeFireButton)

        setupLayout(imageView: imageView)
    }

    private func setupLayout(imageView: NSImageView) {
        NSLayoutConstraint.activate([
            fakeFireButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            progressIndicatorWrapper.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            progressIndicatorWrapper.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            view.trailingAnchor.constraint(equalTo: fakeFireButton.trailingAnchor, constant: 12),

            fakeFireButton.heightAnchor.constraint(equalToConstant: 28),
            fakeFireButton.widthAnchor.constraint(equalToConstant: 28),

            imageView.centerXAnchor.constraint(equalTo: progressIndicatorWrapper.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: progressIndicatorWrapper.centerYAnchor, constant: 13),
            deletingDataLabel.centerXAnchor.constraint(equalTo: progressIndicatorWrapper.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: progressIndicatorWrapper.centerYAnchor, constant: -40),
            progressIndicatorWrapper.bottomAnchor.constraint(equalTo: progressIndicatorWrapperBG.bottomAnchor, constant: 10),
            progressIndicatorWrapper.heightAnchor.constraint(equalToConstant: 220),
            progressIndicator.centerXAnchor.constraint(equalTo: progressIndicatorWrapper.centerXAnchor),
            progressIndicatorWrapper.widthAnchor.constraint(equalToConstant: 320),
            deletingDataLabel.centerYAnchor.constraint(equalTo: progressIndicatorWrapper.centerYAnchor, constant: 34),
            progressIndicatorWrapperBG.leadingAnchor.constraint(equalTo: progressIndicatorWrapper.leadingAnchor, constant: 10),
            progressIndicatorWrapperBG.topAnchor.constraint(equalTo: progressIndicatorWrapper.topAnchor, constant: 10),
            progressIndicatorWrapper.trailingAnchor.constraint(equalTo: progressIndicatorWrapperBG.trailingAnchor, constant: 10),

            imageView.widthAnchor.constraint(equalToConstant: 48),
            imageView.heightAnchor.constraint(equalToConstant: 48),

            progressIndicator.widthAnchor.constraint(equalToConstant: 210),
            progressIndicator.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    deinit {
        fireAnimationViewLoadingTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
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
            .sink { [weak self] isFirePresentationInProgress in
                self?.view.superview?.isHidden = !isFirePresentationInProgress
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
            fireAnimationView?.play(fromProgress: fireAnimationBeginning, toProgress: fireAnimationEnd) { [weak self] _ in
                guard let self = self else { return }

                self.fireViewModel.isAnimationPlaying = false
                self.progressIndicatorWrapper.isHidden = false
                self.fakeFireButton.isHidden = false
                continuation.resume()
            } ?? continuation.resume() // Resume immediately if fireAnimationView is nil
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
            fireAnimationView?.play(fromProgress: fireAnimationBeginning, toProgress: fireAnimationEnd) { [weak self] _ in
                guard let self = self else { return }

                self.fireViewModel.isAnimationPlaying = false
                fireViewModel.fire.fireAnimationDidFinish()

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

@available(macOS 14.0, *)
#Preview { {
    let tabCollectionViewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [Tab(content: .newtab)]))
    let vc = FireViewController(tabCollectionViewModel: tabCollectionViewModel, fireViewModel: FireViewModel())
    vc.onDeinit {
        withExtendedLifetime(tabCollectionViewModel) {}
    }
    return vc

}() }
