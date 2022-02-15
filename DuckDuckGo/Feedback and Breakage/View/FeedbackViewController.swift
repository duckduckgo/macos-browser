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

final class FeedbackViewController: NSViewController {

    enum Constants {
        static let defaultContentHeight: CGFloat = 160
        static let feedbackContentHeight: CGFloat = 323
        static let websiteBreakageContentHeight: CGFloat = 307
        static let thankYouContentHeight: CGFloat = 262

    }

    enum FormOption {
        case websiteBreakage
        case feedback(feedbackCategory: Feedback.Category)

        init?(tag: Int) {
            switch tag {
            case 0: self = FormOption.websiteBreakage
            case 1: self = FormOption.feedback(feedbackCategory: .bug)
            case 2: self = FormOption.feedback(feedbackCategory: .featureRequest)
            case 3: self = FormOption.feedback(feedbackCategory: .other)
            default: return nil
            }
        }
    }

    @IBOutlet weak var optionPopUpButton: NSPopUpButton!
    @IBOutlet weak var pickOptionMenuItem: NSMenuItem!

    @IBOutlet weak var contentView: ColorView!
    @IBOutlet weak var contentViewHeightContraint: NSLayoutConstraint!

    @IBOutlet weak var browserFeedbackView: NSView!
    @IBOutlet weak var browserFeedbackDescriptionLabel: NSTextField!
    @IBOutlet weak var browserFeedbackTextField: NSTextField!

    @IBOutlet weak var websiteBreakageView: NSView!
    @IBOutlet weak var urlTextField: NSTextField!
    @IBOutlet weak var websiteBreakageCategoryPopUpButton: NSPopUpButton!

    @IBOutlet weak var submitButton: NSButton!

    @IBOutlet weak var thankYouView: NSView!
    private var cancellables = Set<AnyCancellable>()

    var currentTab: Tab?
    var currentTabUrl: URL? {
        guard let url = currentTab?.content.url else {
            return nil
        }

        // ⚠️ To limit privacy risk, site URL is trimmed to not include query and fragment
        return url.trimmingQueryItemsAndFragment()
    }

    private let feedbackSender = FeedbackSender()
    private let websiteBreakageSender = WebsiteBreakageSender()

    override func viewDidLoad() {
        super.viewDidLoad()
        browserFeedbackTextField.delegate = self
        urlTextField.delegate = self
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
        } else if popUpButton == websiteBreakageCategoryPopUpButton {
            view.makeMeFirstResponder()
        } else {
            assertionFailure("Unknown popup button")
        }
    }

    @IBAction func submitButtonAction(_ sender: Any) {
        switch selectedFormOption {
        case .none: assertionFailure("Submit shouldn't be enabled"); return
        case .websiteBreakage: sendWebsiteBreakage()
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

    private var selectedFormOption: FormOption? {
        guard let item = optionPopUpButton.selectedItem, item.tag >= 0 else {
            return nil
        }

        return FormOption(tag: item.tag)
    }

    private var selectedWebsiteBreakageCategory: WebsiteBreakage.Category? {
        guard let subcategoryItem = websiteBreakageCategoryPopUpButton.selectedItem,
              let subcategory = WebsiteBreakage.Category(tag: subcategoryItem.tag) else {
                  return nil
              }
        return subcategory
    }

    private func updateViews() {
        defer {
            updateSubmitButton()
        }

        guard let selectedFormOption = selectedFormOption else {
            browserFeedbackView.isHidden = true
            websiteBreakageView.isHidden = true
            setContentViewHeight(Constants.defaultContentHeight, animated: false)
            pickOptionMenuItem.isEnabled = true
            return
        }

        let contentHeight: CGFloat
        switch selectedFormOption {
        case .feedback(let feedbackCategory):
            browserFeedbackView.isHidden = false
            contentHeight = Constants.feedbackContentHeight
            updateBrowserFeedbackDescriptionLabel(for: feedbackCategory)
            browserFeedbackTextField.makeMeFirstResponder()
        case .websiteBreakage:
            browserFeedbackView.isHidden = true
            contentHeight = Constants.websiteBreakageContentHeight
            urlTextField.stringValue = currentTabUrl?.absoluteString ?? ""
            if urlTextField.stringValue.isEmpty {
                urlTextField.makeMeFirstResponder()
            }
        }
        websiteBreakageView.isHidden = !browserFeedbackView.isHidden
        setContentViewHeight(contentHeight, animated: true)
    }

    private func setContentViewHeight(_ height: CGFloat, animated: Bool) {
        if animated {
            NSAnimationContext.runAnimationGroup { [weak self] context in
                context.duration = 1/3
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
            if !browserFeedbackTextField.stringValue.trimmingWhitespaces().isEmpty {
                submitButton.isEnabled = true
            } else {
                submitButton.isEnabled = false
            }
        case .websiteBreakage:
            submitButton.isEnabled = !urlTextField.stringValue.isEmpty
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
        }
    }

    private func sendFeedback() {
        guard let selectedFormOption = selectedFormOption else {
            assertionFailure("Can't send feedback")
            return
        }

        switch selectedFormOption {
        case .websiteBreakage: assertionFailure("Wrong method executed")
        case .feedback(feedbackCategory: let feedbackCategory):
            let feedback = Feedback(category: feedbackCategory,
                                    comment: browserFeedbackTextField.stringValue,
                                    appVersion: "\(AppVersion.shared.versionNumber)",
                                    osVersion: "\(ProcessInfo.processInfo.operatingSystemVersion)")
            feedbackSender.sendFeedback(feedback)
        }
    }

    private func sendWebsiteBreakage() {
        guard let selectedFormOption = selectedFormOption else {
            assertionFailure("Can't send breakage")
            return
        }

        switch selectedFormOption {
        case .feedback: assertionFailure("Wrong method executed")
        case .websiteBreakage:
            let blockedTrackerDomains = currentTab?.trackerInfo?.trackersBlocked.compactMap { $0.domain } ?? []
            let installedSurrogates = currentTab?.trackerInfo?.installedSurrogates.map {$0} ?? []
            let websiteBreakage = WebsiteBreakage(category: selectedWebsiteBreakageCategory,
                                                  siteUrlString: urlTextField.stringValue,
                                                  osVersion: "\(ProcessInfo.processInfo.operatingSystemVersion)",
                                                  upgradedHttps: currentTab?.connectionUpgradedTo != nil,
                                                  tdsETag: DefaultConfigurationStorage.shared.loadEtag(for: .trackerRadar),
                                                  atb: LocalStatisticsStore().atb,
                                                  blockedTrackerDomains: blockedTrackerDomains,
                                                  installedSurrogates: installedSurrogates)
            websiteBreakageSender.sendWebsiteBreakage(websiteBreakage)
        }
    }

    private func showThankYou() {
        setContentViewHeight(Constants.thankYouContentHeight, animated: true)
        contentView.isHidden = true
        thankYouView.isHidden = false
    }
}

fileprivate extension WebsiteBreakage.Category {

    init?(tag: Int) {
        switch tag {
        case 0: self = .theSiteAskedToDisable
        case 1: self = .cantSignIn
        case 2: self = .linksDontWork
        case 3: self = .imagesDidntLoad
        case 4: self = .videoDidntPlay
        case 5: self = .contentIsMissing
        case 6: self = .commentsDidntLoad
        case 7: self = .browserIsIncompatible
        case 8: self = .somethingElse

        default:
            return nil
        }
    }

}

extension FeedbackViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ notification: Notification) {
        updateSubmitButton()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSStandardKeyBindingResponding.insertNewline(_:)) {
            textView.insertNewlineIgnoringFieldEditor(self)
            return true
        }
        return false
    }

}

private extension URL {

    func trimmingQueryItemsAndFragment() -> URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        components?.queryItems = nil
        components?.fragment = nil

        return components?.url
    }

}
