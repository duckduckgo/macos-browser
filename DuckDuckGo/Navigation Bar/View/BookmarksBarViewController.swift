//
//  BookmarksBarViewController.swift
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

import Foundation
import AppKit
import CryptoKit

final class BookmarksBarViewController: NSViewController {
    
    private enum Constants {
        static let buttonSpacing: CGFloat = 12
        static let buttonHeight: CGFloat = 28
        static let maximumButtonWidth: CGFloat = 120
    }
    
    private var buttons: [NSButton] = []
    private var clippedButtons: [NSButton] = []
    private var hasClippedButtons: Bool {
        !clippedButtons.isEmpty
    }
    
    // MARK: - Layout Calculation
    
    private var cumulativeButtonWidth: CGFloat = 0
    private var cumulativeSpacingWidth: CGFloat = 0
    private var totalButtonListWidth: CGFloat = 0
    
    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(frameChanged),
                                               name: NSView.frameDidChangeNotification,
                                               object: self.view)
        
        self.buttons = generateFakeButtons()
        positionButtonsForInitialLayout()
        layoutButtons()
    }
    
    @objc
    private func frameChanged() {
        if view.frame.size.width <= (totalButtonListWidth + (Constants.buttonSpacing * 2)) {
            removeLastButton()
        } else {
            tryToRestoreClippedButton()
        }
    }
    
    override func viewWillLayout() {
        super.viewWillLayout()
        layoutButtons()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
    }
    
    private func positionButtonsForInitialLayout() {
        for button in buttons {
            view.addSubview(button)
        }
        
        calculateFixedButtonSizingValues()
    }
    
    private func tryToRestoreClippedButton() {
        guard let firstClippedButton = clippedButtons.first else {
            return
        }

        // Check if the next clipped button to restore can fit, and add it if so:
        
        let clippedButtonWidth = firstClippedButton.bounds.width
        
        // Button spacing * 3: Once for the padding between the last button and the new one,
        // and two to account for the spacing at the beginning and end of the list.
        if totalButtonListWidth + (Constants.buttonSpacing * 3) + clippedButtonWidth < view.bounds.width {
            let buttonToRestore = clippedButtons.removeFirst()
            buttons.append(buttonToRestore)
            view.addSubview(buttonToRestore)
            
            calculateFixedButtonSizingValues()
            layoutButtons()
        }
    }
    
    private func removeLastButton() {
        guard let lastButton = buttons.popLast() else {
            return
        }

        lastButton.removeFromSuperview()
        clippedButtons.insert(lastButton, at: 0)
        
        calculateFixedButtonSizingValues()
        layoutButtons()
    }
    
    private func calculateFixedButtonSizingValues() {
        self.cumulativeButtonWidth = buttons.map(\.bounds.size.width).reduce(0, +)
        self.cumulativeSpacingWidth = Constants.buttonSpacing * CGFloat(max(0, buttons.count - 1))
        self.totalButtonListWidth = cumulativeButtonWidth + cumulativeSpacingWidth
    }

    private func layoutButtons() {
        var previousMaximumXValue: CGFloat
        
        // If there are any clipped buttons, the button list should always be leading-aligned.
        if hasClippedButtons {
            previousMaximumXValue = Constants.buttonSpacing
        } else {
            previousMaximumXValue = max(Constants.buttonSpacing, (view.bounds.midX) - (self.totalButtonListWidth / 2))
        }

        for button in buttons {
            var updatedButtonFrame = button.frame
            updatedButtonFrame.origin = CGPoint(x: previousMaximumXValue, y: view.frame.midY - (button.frame.height / 2) + 3)
            button.frame = updatedButtonFrame
            
            previousMaximumXValue = updatedButtonFrame.maxX + Constants.buttonSpacing
        }
    }
    
    private func generateFakeButtons() -> [NSButton] {
        return [
            bookmarkButton(titled: "Testing Testing Testing 1"),
            bookmarkButton(titled: "Test 2"),
            bookmarkButton(titled: "Test 3"),
            bookmarkButton(titled: "Test 4?!"),
            bookmarkButton(titled: "Test 5"),
            bookmarkButton(titled: "Test Test 6"),
            bookmarkButton(titled: "Testing 7: Still Testing"),
            bookmarkButton(titled: "Test Test 8"),
            bookmarkButton(titled: "Test Test 9"),
            bookmarkButton(titled: "Test Test 10"),
            bookmarkButton(titled: "Test Test 11"),
            bookmarkButton(titled: "Test Test 12")
        ]
    }
    
    private func bookmarkButton(titled title: String) -> NSButton {
        let button = NSButton(frame: .zero)
        button.isBordered = false
        button.title = title
        button.sizeToFit()
        
        var buttonFrame = button.frame
        buttonFrame.size.width = min(Constants.maximumButtonWidth, buttonFrame.size.width)
        button.frame = buttonFrame
        
        button.lineBreakMode = .byTruncatingTail

        return button
    }
    
}
