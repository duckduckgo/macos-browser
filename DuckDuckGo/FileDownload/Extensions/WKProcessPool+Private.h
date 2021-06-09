//
//  WKProcessPool+Private.h
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

#import "_WKDownload.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKProcessPool (Private)

// https://github.com/WebKit/WebKit/blob/8afe31a018b11741abdf9b4d5bb973d7c1d9ff05/Source/WebKit/UIProcess/API/Cocoa/WKProcessPool.mm#L522
- (_WKDownload *)_downloadURLRequest:(NSURLRequest *)request websiteDataStore:(WKWebsiteDataStore *)dataStore originatingWebView:(WKWebView *)webView;
- (_WKDownload *)_resumeDownloadFromData:(NSData *)resumeData websiteDataStore:(WKWebsiteDataStore *)dataStore path:(NSString *)path originatingWebView:(WKWebView *)webView;

@end

NS_ASSUME_NONNULL_END
