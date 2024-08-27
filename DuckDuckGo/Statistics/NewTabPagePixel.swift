//
//  NewTabPagePixel.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import PixelKit

enum NewTabPagePixel: PixelKitEventV2 {

    // New Tab Custom Background
    case newTabBackgroundSelectedGradient
    case newTabBackgroundSelectedSolidColor
    case newTabBackgroundSelectedIllustration
    case newTabBackgroundSelectedUserImage
    case newTabBackgroundAddedUserImage
    case newTabBackgroundDeletedUserImage
    case newTabBackgroundReset

    // MARK: - Debug

    case newTabBackgroundInitializeStorageError
    case newTabBackgroundAddImageError
    case newTabBackgroundThumbnailGenerationError
    case newTabBackgroundImageNotFound
    case newTabBackgroundThumbnailNotFound

    var name: String {
        switch self {
        case .newTabBackgroundSelectedGradient:
            return "m_mac_newtab_background_selected-gradient"
        case .newTabBackgroundSelectedSolidColor:
            return "m_mac_newtab_background_selected-solid-color"
        case .newTabBackgroundSelectedIllustration:
            return "m_mac_newtab_background_selected-illustration"
        case .newTabBackgroundSelectedUserImage:
            return "m_mac_newtab_background_selected-user-image"
        case .newTabBackgroundAddedUserImage:
            return "m_mac_newtab_background_added-user-image"
        case .newTabBackgroundDeletedUserImage:
            return "m_mac_newtab_background_deleted-user-image"
        case .newTabBackgroundReset:
            return "m_mac_newtab_background_reset"

        case .newTabBackgroundInitializeStorageError: return "newtab_background_initialize-storage-error"
        case .newTabBackgroundAddImageError: return "newtab_background_add-image-error"
        case .newTabBackgroundThumbnailGenerationError: return "newtab_background_thumbnail-generation-error"
        case .newTabBackgroundImageNotFound: return "newtab_background_image-not-found"
        case .newTabBackgroundThumbnailNotFound: return "newtab_background_thumbnail-not-found"
        }
    }

    var parameters: [String : String]? {
        nil
    }

    var error: (any Error)? {
        nil
    }
}
