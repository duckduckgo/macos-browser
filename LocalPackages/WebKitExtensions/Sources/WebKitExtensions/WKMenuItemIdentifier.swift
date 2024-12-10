//
//  WKMenuItemIdentifier.swift
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

import AppKitExtensions

public enum WKMenuItemIdentifier: String, CaseIterable {
    case copy = "WKMenuItemIdentifierCopy"
    case copyImage = "WKMenuItemIdentifierCopyImage"
    case copyLink = "WKMenuItemIdentifierCopyLink"
    case copyMediaLink = "WKMenuItemIdentifierCopyMediaLink"
    case downloadImage = "WKMenuItemIdentifierDownloadImage"
    case downloadLinkedFile = "WKMenuItemIdentifierDownloadLinkedFile"
    case downloadMedia = "WKMenuItemIdentifierDownloadMedia"
    case goBack = "WKMenuItemIdentifierGoBack"
    case goForward = "WKMenuItemIdentifierGoForward"
    case inspectElement = "WKMenuItemIdentifierInspectElement"
    case lookUp = "WKMenuItemIdentifierLookUp"
    case addHighlightToCurrentQuickNote = "WKMenuItemIdentifierAddHighlightToCurrentQuickNote"
    case addHighlightToNewQuickNote = "WKMenuItemIdentifierAddHighlightToNewQuickNote"

    case openFrameInNewWindow = "WKMenuItemIdentifierOpenFrameInNewWindow"
    case openImageInNewWindow = "WKMenuItemIdentifierOpenImageInNewWindow"
    case openLink = "WKMenuItemIdentifierOpenLink"
    case openLinkInNewWindow = "WKMenuItemIdentifierOpenLinkInNewWindow"
    case openMediaInNewWindow = "WKMenuItemIdentifierOpenMediaInNewWindow"
    case paste = "WKMenuItemIdentifierPaste"
    case reload = "WKMenuItemIdentifierReload"
    case revealImage = "WKMenuItemIdentifierRevealImage"
    case searchWeb = "WKMenuItemIdentifierSearchWeb"
    case showHideMediaControls = "WKMenuItemIdentifierShowHideMediaControls"
    case toggleEnhancedFullScreen = "WKMenuItemIdentifierToggleEnhancedFullScreen"
    case toggleFullScreen = "WKMenuItemIdentifierToggleFullScreen"

    case shareMenu = "WKMenuItemIdentifierShareMenu"
    case speechMenu = "WKMenuItemIdentifierSpeechMenu"

    case translate = "WKMenuItemIdentifierTranslate"
    case copySubject = "WKMenuItemIdentifierCopySubject"

    case spellingMenu = "WKMenuItemIdentifierSpellingMenu"
    case showSpellingPanel = "WKMenuItemIdentifierShowSpellingPanel"
    case checkSpelling = "WKMenuItemIdentifierCheckSpelling"
    case checkSpellingWhileTyping = "WKMenuItemIdentifierCheckSpellingWhileTyping"
    case checkGrammarWithSpelling = "WKMenuItemIdentifierCheckGrammarWithSpelling"

    public init?(_ identifier: NSUserInterfaceItemIdentifier) {
        self.init(rawValue: identifier.rawValue)
    }
}

public extension NSMenu {
    func item(with identifier: WKMenuItemIdentifier) -> NSMenuItem? {
        return indexOfItem(withIdentifier: identifier.rawValue).map { self.items[$0] }
    }
}
