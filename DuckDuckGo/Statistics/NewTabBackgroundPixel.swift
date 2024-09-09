//
//  NewTabBackgroundPixel.swift
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

/**
 * This enum keeps pixels related to New Tab page background customization.
 *
 * > Related links:
 * [Privacy Triage](https://app.asana.com/0/69071770703008/1208146890364172/f)
 * [Detailed Pixels description](https://app.asana.com/0/1201621708115095/1207983904350396/f)
 */
enum NewTabBackgroundPixel: PixelKitEventV2 {

    /**
     * Event Trigger: User selects gradient as custom NTP background.
     *
     * Anomaly Investigation:
     * - `customBackground` is updated with this value from `HomePage.Models.SettingsModel` and `HomePage.Views.BackgroundPickerView`.
     * - Check the above places in code and make sure nothing got broken to cause the update to be fired repeatedly.
     */
    case newTabBackgroundSelectedGradient

    /**
     * Event Trigger: User selects solid color as custom NTP background.
     *
     * Anomaly Investigation:
     * - `customBackground` is updated with this value from `HomePage.Models.SettingsModel` and `HomePage.Views.BackgroundPickerView`.
     * - Check the above places in code and make sure nothing got broken to cause the update to be fired repeatedly.
     */
    case newTabBackgroundSelectedSolidColor

    /**
     * Event Trigger: User selects a user-uploaded image as custom NTP background.
     *
     * Anomaly Investigation:
     * - `customBackground` is updated with this value from `HomePage.Models.SettingsModel` and `HomePage.Views.BackgroundPickerView`.
     * - Check the above places in code and make sure nothing got broken to cause the update to be fired repeatedly.
     */
    case newTabBackgroundSelectedUserImage

    /**
     * Event Trigger: User removes custom NTP background.
     *
     * Anomaly Investigation:
     * - `customBackground` is updated with this value from `HomePage.Models.SettingsModel` and `HomePage.Views.SettingsView`.
     * - Check the above places in code and make sure nothing got broken to cause the update to be fired repeatedly.
     */
    case newTabBackgroundReset

    /**
     * Event Trigger: User uploads new image to be used as custom NTP background.
     *
     * Anomaly Investigation:
     * - Check `UserBackgroundImagesManager.addImage(with:)` where this pixel is fired.
     * - Check `HomePage.Models.SettingsModel.addNewImage()` where images manager's `addImage(with:)` is called.
     */
    case newTabBackgroundAddedUserImage

    /**
     * Event Trigger: User deletes an image from the list of user-provided backgrounds.
     *
     * Anomaly Investigation:
     * - Check `UserBackgroundImagesManager.deleteImage(_:)` where this pixel is fired.
     * - Check `BackgroundThumbnailView` where images manager's `deleteImage(_:)` is called.
     */
    case newTabBackgroundDeletedUserImage

    // MARK: - Debug

    /**
     * Event Trigger: User images storage directory can't be set up properly.
     *
     * Anomaly Investigation:
     * - Check `UserBackgroundImagesManager`'s initializer, where this pixel is fired.
     * - The pixel is fired when calls to `setUpStorageDirectory(at:)` throw an error.
     * - If the logic looks good, the anomaly may be coming from a single user with permissions
     *   issue or no space left on disk, restarting the app frequently.
     */
    case newTabBackgroundInitializeStorageError

    /**
     * Event Trigger: Adding user's own image fails (i.e. file name has image extension but the file itself is not an image).
     *
     * Anomaly Investigation:
     * - This will likely be an error with either `FileManager` and disk access,
     *   or with `ImageProcessor` and image manipulation logic.
     * - Consult the error parameter to learn more. `ImageProcessingError` should give you more visibility into what got broken.
     */
    case newTabBackgroundAddImageError

    /**
     * Event Trigger: Generating thumbnail for an image fails.
     *
     * Anomaly Investigation:
     * - This will likely be an error with either `FileManager` and disk access,
     *   or with `ImageProcessor` and image manipulation logic.
     * - Consult the error parameter to learn more. `ImageProcessingError` should give you more visibility into what got broken.
     */
    case newTabBackgroundThumbnailGenerationError

    /**
     * Event Trigger: Previously uploaded user's own image couldn't be loaded from disk.
     *
     * > Note: This pixel should only be fired once per file per app session.
     *
     * Anomaly Investigation:
     * - This could happen when a user modifies their app data directory and removes files.
     * - If there's an anomaly, it may be related to the logic in our code getting broken.
     *   See `UserBackgroundImagesManager.image(for:)` and verify that the logic is correct.
     */
    case newTabBackgroundImageNotFound

    /**
     * Event Trigger: Previously uploaded user's own image thumbnail couldn't be loaded from disk
     *
     * > Note: This pixel should only be fired once per file per app session.
     *
     * Anomaly Investigation:
     * - This could happen when a user modifies their app data directory and removes files.
     * - If there's an anomaly, it may be related to the logic in our code getting broken.
     *   See `UserBackgroundImagesManager.thumbnailImage(for:)` and verify that the logic is correct.
     */
    case newTabBackgroundThumbnailNotFound

    var name: String {
        switch self {
        case .newTabBackgroundSelectedGradient:
            return "m_mac_newtab_background_selected-gradient"
        case .newTabBackgroundSelectedSolidColor:
            return "m_mac_newtab_background_selected-solid-color"
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

    var parameters: [String: String]? {
        nil
    }

    var error: (any Error)? {
        nil
    }
}
