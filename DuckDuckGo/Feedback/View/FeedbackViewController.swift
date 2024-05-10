//
//  FeedbackViewController.swift
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

import Cocoa
import Combine
import Common
import SwiftUI
import SwiftUIExtensions

final class FeedbackViewController: NSViewController {

    enum Constants {
        static let defaultContentHeight: CGFloat = 160
        static let feedbackContentHeight: CGFloat = 338
        static let thankYouContentHeight: CGFloat = 262
        static let browserFeedbackViewTopConstraint: CGFloat = 53
        static let unsupportedOSWarningHeight: CGFloat = 200
    }

    enum FormOption {
        case feedback(feedbackCategory: Feedback.Category)

        init?(tag: Int) {
            switch tag {
            case 1: self = FormOption.feedback(feedbackCategory: .bug)
            case 2: self = FormOption.feedback(feedbackCategory: .featureRequest)
            case 3: self = FormOption.feedback(feedbackCategory: .other)
            default: return nil
            }
        }
    }
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var okButton: NSButton!
    @IBOutlet weak var thankYouLabel: NSTextField!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var feedbackHelpsLabel: NSTextField!

    @IBOutlet weak var optionPopUpButton: NSPopUpButton!
    @IBOutlet weak var pickOptionMenuItem: NSMenuItem!

    @IBOutlet weak var contentView: ColorView!
    @IBOutlet weak var contentViewHeightContraint: NSLayoutConstraint!

    @IBOutlet weak var browserFeedbackView: NSView!
    @IBOutlet weak var browserFeedbackViewTopConstraint: NSLayoutConstraint!

    @IBOutlet weak var browserFeedbackDescriptionLabel: NSTextField!
    @IBOutlet weak var browserFeedbackTextView: NSTextView!
    @IBOutlet weak var browserFeedbackDisclaimerTextView: NSTextField!
    @IBOutlet weak var unsupportedOsView: NSView!

    @IBOutlet weak var submitButton: NSButton!

    @IBOutlet weak var thankYouView: NSView!
    private var cancellables = Set<AnyCancellable>()

    @IBOutlet weak var generalFeedbackItem: NSMenuItem!
    @IBOutlet weak var requestFeatureItem: NSMenuItem!
    @IBOutlet weak var reportProblemITem: NSMenuItem!

    var currentTab: Tab?
    var currentTabUrl: URL? {
        guard let url = currentTab?.content.urlForWebView else {
            return nil
        }

        // ⚠️ To limit privacy risk, site URL is trimmed to not include query and fragment
        return url.trimmingQueryItemsAndFragment()
    }

    private let feedbackSender = FeedbackSender()

    override func viewDidLoad() {
        super.viewDidLoad()

        setContentViewHeight(Constants.defaultContentHeight, animated: false)
        setupTextViews()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(popUpButtonOpened(_:)),
                                               name: NSPopUpButton.willPopUpNotification,
                                               object: nil)
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()

        // swiftlint:disable notification_center_detachment
        NotificationCenter.default.removeObserver(self)
        // swiftlint:enable notification_center_detachment
    }

    @IBAction func optionPopUpButtonAction(_ sender: Any) {
        updateViews()
    }

    @IBAction func websiteBreakageCategoryPopUpButtonAction(_ sender: Any) {
        updateViews()
    }

    @objc func popUpButtonOpened(_ notification: Notification) {
        guard let popUpButton = notification.object as? NSPopUpButton else {
            assertionFailure("No popup button")
            return
        }

        if popUpButton == optionPopUpButton {
            pickOptionMenuItem.isEnabled = false
        }
    }

    @IBAction func submitButtonAction(_ sender: Any) {
        switch selectedFormOption {
        case .none: assertionFailure("Submit shouldn't be enabled"); return
        case .feedback: sendFeedback()
        }

        showThankYou()
    }

    @IBAction func okButtonAction(_ sender: Any) {
        guard let window = view.window,
              let sheetParent = window.sheetParent else {
                  assertionFailure("No sheet parent")
                  return
              }

        sheetParent.endSheet(window, returnCode: .OK)
    }

    @IBAction func cancelButtonAction(_ sender: Any) {
        guard let window = self.view.window,
              let sheetParent = window.sheetParent else {
                  assertionFailure("No sheet parent")
                  return
              }

        sheetParent.endSheet(window, returnCode: .cancel)
    }

    private func setupTextViews() {
        browserFeedbackTextView.delegate = self
        browserFeedbackTextView.font = NSFont.systemFont(ofSize: 12)
        titleLabel.stringValue = UserText.browserFeedbackTitle
        okButton.title = UserText.ok
        thankYouLabel.stringValue = UserText.browserFeedbackThankYou
        feedbackHelpsLabel.stringValue = UserText.browserFeedbackFeedbackHelps
        cancelButton.title = UserText.cancel
        submitButton.title = UserText.submit
        generalFeedbackItem.title = UserText.browserFeedbackGeneralFeedback
        requestFeatureItem.title = UserText.browserFeedbackRequestFeature
        reportProblemITem.title = UserText.browserFeedbackReportProblem
        pickOptionMenuItem.title = UserText.browserFeedbackSelectCategory
    }

    private var selectedFormOption: FormOption? {
        guard let item = optionPopUpButton.selectedItem, item.tag >= 0 else {
            return nil
        }

        return FormOption(tag: item.tag)
    }

    private func updateViews() {
        defer {
            updateSubmitButton()
        }

        guard let selectedFormOption = selectedFormOption else {
            browserFeedbackView.isHidden = true
            setContentViewHeight(Constants.defaultContentHeight, animated: false)
            pickOptionMenuItem.isEnabled = true
            return
        }

        browserFeedbackView.isHidden = false

        showUnsupportedOsViewIfNeeded()
        let unsupportedOSWarningHeight = isOsUnsupported ? Constants.unsupportedOSWarningHeight : 0

        let contentHeight: CGFloat
        switch selectedFormOption {
        case .feedback(let feedbackCategory):
            contentHeight = Constants.feedbackContentHeight + unsupportedOSWarningHeight
            updateBrowserFeedbackDescriptionLabel(for: feedbackCategory)
            browserFeedbackViewTopConstraint.constant = Constants.browserFeedbackViewTopConstraint + unsupportedOSWarningHeight
        }
        updateBrowserFeedbackDisclaimerLabel(for: selectedFormOption)
        browserFeedbackTextView.makeMeFirstResponder()
        setContentViewHeight(contentHeight, animated: true)
    }

    private func setContentViewHeight(_ height: CGFloat, animated: Bool) {
        if animated {
            NSAnimationContext.runAnimationGroup { [weak self] context in
                context.duration = 1/6
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self?.contentViewHeightContraint.animator().constant = height
            }
        } else {
            contentViewHeightContraint.constant = height
        }
    }

    private func updateSubmitButton() {
        guard let selectedFormOption = selectedFormOption else {
            submitButton.isEnabled = false
            return
        }

        switch selectedFormOption {
        case .feedback:
            if !browserFeedbackTextView.string.trimmingWhitespace().isEmpty {
                submitButton.isEnabled = true
            } else {
                submitButton.isEnabled = false
            }
        }

        submitButton.bezelColor = submitButton.isEnabled ? NSColor.controlAccentColor: nil
    }

    private func updateBrowserFeedbackDescriptionLabel(for category: Feedback.Category) {
        switch category {
        case .bug:
            browserFeedbackDescriptionLabel.stringValue = UserText.feedbackBugDescription
        case .featureRequest:
            browserFeedbackDescriptionLabel.stringValue = UserText.feedbackFeatureRequestDescription
        case .other:
            browserFeedbackDescriptionLabel.stringValue = UserText.feedbackOtherDescription
        case .generalFeedback, .designFeedback, .usability, .dataImport:
            assertionFailure("unexpected flow")
            browserFeedbackDescriptionLabel.stringValue = "\(category)"
        }
    }

    private func updateBrowserFeedbackDisclaimerLabel(for formOption: FormOption) {
        switch formOption {
        case .feedback:
            browserFeedbackDisclaimerTextView.stringValue = UserText.feedbackDisclaimer
        }
    }

    private func sendFeedback() {
        guard let selectedFormOption = selectedFormOption else {
            assertionFailure("Can't send feedback")
            return
        }

        switch selectedFormOption {
        case .feedback(feedbackCategory: let feedbackCategory):
            let feedback = Feedback(category: feedbackCategory,
                                    comment: browserFeedbackTextView.string,
                                    appVersion: "\(AppVersion.shared.versionNumber)",
                                    osVersion: "\(ProcessInfo.processInfo.operatingSystemVersion)")
            feedbackSender.sendFeedback(feedback)
        }
    }

    private func showThankYou() {
        setContentViewHeight(Constants.thankYouContentHeight, animated: true)
        contentView.isHidden = true
        thankYouView.isHidden = false
    }

    var isOsUnsupported: Bool {
        return !SupportedOSChecker.isCurrentOSReceivingUpdates
    }

    private weak var unsupportedOsChildView: NSView?
    private func showUnsupportedOsViewIfNeeded() {
        if isOsUnsupported && unsupportedOsChildView == nil {
            let view = NSHostingView(rootView: Preferences.UnsupportedDeviceInfoBox(wide: false))
            unsupportedOsView.addAndLayout(view)
            unsupportedOsView.isHidden = false
            unsupportedOsChildView = view
        }
    }

}

extension FeedbackViewController: NSTextFieldDelegate {

    func control(_ control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool {
        return true
    }

    func controlTextDidChange(_ notification: Notification) {
        updateSubmitButton()
    }

}

extension FeedbackViewController: NSTextViewDelegate {

    func textDidChange(_ notification: Notification) {
        updateSubmitButton()
    }

}

extension URL {

    func trimmingQueryItemsAndFragment() -> URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        components?.queryItems = nil
        components?.fragment = nil

        return components?.url
    }

}
