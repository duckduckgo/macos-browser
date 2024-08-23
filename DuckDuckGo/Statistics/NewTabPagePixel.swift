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
    case newTabBackgroundThumbnailError

    var name: String {
        switch self {
        case .newTabBackgroundSelectedGradient:
            return "newtab_mac_background_selected-gradient"
        case .newTabBackgroundSelectedSolidColor:
            return "newtab_mac_background_selected-solid-color"
        case .newTabBackgroundSelectedIllustration:
            return "newtab_mac_background_selected-illustration"
        case .newTabBackgroundSelectedUserImage:
            return "newtab_mac_background_selected-user-image"
        case .newTabBackgroundAddedUserImage:
            return "newtab_mac_background_added-user-image"
        case .newTabBackgroundDeletedUserImage:
            return "newtab_mac_background_deleted-user-image"
        case .newTabBackgroundReset:
            return "newtab_mac_background_reset"

        case .newTabBackgroundInitializeStorageError: return "newtab_background_initialize-storage-error"
        case .newTabBackgroundAddImageError: return "newtab_background_add-image-error"
        case .newTabBackgroundThumbnailError: return "newtab_background_thumbnail-error"
        }
    }

    var parameters: [String : String]? {
        nil
    }

    var error: (any Error)? {
        nil
    }
}
