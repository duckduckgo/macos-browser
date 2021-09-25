//
//  WKGeolocationProvider.h
//  DuckDuckGo
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

// https://github.com/WebKit/WebKit/blob/8afe31a018b11741abdf9b4d5bb973d7c1d9ff05/Source/WebKit/UIProcess/API/C/WKGeolocationManager.h

typedef void (*WKGeolocationProviderStartUpdatingCallback)(const void * geolocationManager, const void* clientInfo);
typedef void (*WKGeolocationProviderStopUpdatingCallback)(const void * geolocationManager, const void* clientInfo);
typedef void (*WKGeolocationProviderSetEnableHighAccuracyCallback)(const void * geolocationManager, bool enabled, const void* clientInfo);

typedef struct WKGeolocationProviderBase {
    int version;
    const void * clientInfo;
} WKGeolocationProviderBase;

typedef struct WKGeolocationProviderV0 {
    WKGeolocationProviderBase base;

    WKGeolocationProviderStartUpdatingCallback startUpdating;
    WKGeolocationProviderStopUpdatingCallback stopUpdating;
} WKGeolocationProviderV0;

typedef struct WKGeolocationProviderV1 {
    WKGeolocationProviderBase base;

    WKGeolocationProviderStartUpdatingCallback startUpdating;
    WKGeolocationProviderStopUpdatingCallback stopUpdating;

    WKGeolocationProviderSetEnableHighAccuracyCallback setEnableHighAccuracy;
} WKGeolocationProviderV1;
