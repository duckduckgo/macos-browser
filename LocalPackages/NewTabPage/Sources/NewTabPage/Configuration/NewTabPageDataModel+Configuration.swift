//
//  NewTabPageDataModel+Configuration.swift
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

public extension NewTabPageDataModel {
    struct OpenAction: Codable {
        let target: Target

        public enum Target: String, Codable {
            case settings
        }
    }
}

extension NewTabPageDataModel {

    enum WidgetId: String, Codable {
        case rmf, freemiumPIRBanner, nextSteps, favorites, privacyStats, recentActivity = "activity"
    }

    struct ContextMenuParams: Codable {
        let visibilityMenuItems: [ContextMenuItem]

        struct ContextMenuItem: Codable {
            let id: WidgetId
            let title: String
        }
    }

    struct Exception: Codable, Equatable {
        let message: String
    }

    struct NewTabPageConfiguration: Encodable {
        var widgets: [Widget]
        var widgetConfigs: [WidgetConfig]
        var env: String
        var locale: String
        var platform: Platform
        var settings: Settings?
        var customizer: NewTabPageDataModel.CustomizerData?

        struct Widget: Encodable, Equatable {
            public var id: WidgetId
        }

        struct WidgetConfig: Codable, Equatable {

            enum WidgetVisibility: String, Codable {
                case visible, hidden

                var isVisible: Bool {
                    self == .visible
                }
            }

            init(id: WidgetId, isVisible: Bool) {
                self.id = id
                self.visibility = isVisible ? .visible : .hidden
            }

            var id: WidgetId
            var visibility: WidgetVisibility
        }

        struct Platform: Encodable, Equatable {
            var name: String
        }

        struct Settings: Encodable, Equatable {
            let customizerDrawer: Setting
        }

        struct Setting: Encodable, Equatable {
            let state: BooleanSetting
        }

        enum BooleanSetting: String, Encodable {
            case enabled, disabled

            var isEnabled: Bool {
                self == .enabled
            }
        }
    }
}
