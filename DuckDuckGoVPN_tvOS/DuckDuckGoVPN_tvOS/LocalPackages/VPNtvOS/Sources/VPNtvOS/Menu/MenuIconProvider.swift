//
//  MenuIconProvider.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import AppKit
import Foundation

/// Release build status menu icons.
///
public final class MenuIconProvider: IconProvider {
    public init() {}

    public var onIcon: NetworkProtectionAsset {
        .statusbarVPNOnIcon
    }

    public var offIcon: NetworkProtectionAsset {
        .statusbarVPNOffIcon
    }

    public var issueIcon: NetworkProtectionAsset {
        .statusbarVPNIssueIcon
    }
}

/// Debug build status menu icons.
///
public final class DebugMenuIconProvider: IconProvider {
    public init() {}

    public var onIcon: NetworkProtectionAsset {
        .statusbarDebugVPNOnIcon
    }

    public var offIcon: NetworkProtectionAsset {
        .statusbarBrandedVPNOffIcon
    }

    public var issueIcon: NetworkProtectionAsset {
        .statusbarBrandedVPNIssueIcon
    }
}

/// Review build status menu icons.
///
public final class ReviewMenuIconProvider: IconProvider {
    public init() {}

    public var onIcon: NetworkProtectionAsset {
        .statusbarReviewVPNOnIcon
    }

    public var offIcon: NetworkProtectionAsset {
        .statusbarBrandedVPNOffIcon
    }

    public var issueIcon: NetworkProtectionAsset {
        .statusbarBrandedVPNIssueIcon
    }
}
