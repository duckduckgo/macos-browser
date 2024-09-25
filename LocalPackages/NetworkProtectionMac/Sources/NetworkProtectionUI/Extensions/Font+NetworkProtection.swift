//
//  Font+NetworkProtection.swift
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

import SwiftUI

extension Font {
    enum NetworkProtection {
        static var connectionStatusDetail: Font {
            .system(size: 13, weight: .regular, design: .default)
        }

        static var dataVolume: Font {
            .system(size: 13, weight: .regular, design: .default)
        }

        static var currentSite: Font {
            .system(size: 13, weight: .regular, design: .default)
        }

        static var location: Font {
            .system(size: 13, weight: .regular, design: .default)
        }

        static var content: Font {
            .system(size: 13, weight: .regular, design: .default)
        }

        static var description: Font {
            .system(size: 13, weight: .regular, design: .default)
        }

        static var label: Font {
            .system(size: 13, weight: .regular, design: .default)
        }

        static var sectionHeader: Font {
            .system(size: 12, weight: .semibold, design: .default)
        }

        static var timer: Font {
            .system(size: 13, weight: .regular, design: .default)
            .monospacedDigit()
        }

        static var title: Font {
            .system(size: 15, weight: .semibold, design: .default)
        }
    }
}
