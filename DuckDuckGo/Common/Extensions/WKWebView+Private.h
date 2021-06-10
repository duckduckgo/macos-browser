//
//  WKWebView+SessionState.h
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
#import <WebKit/WebKit.h>
#import "_WKDownload.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKWebView (Private)

- (void)_restoreFromSessionStateData:(NSData *)data;
- (NSData * _Nullable)_sessionStateData;

- (void)createWebArchiveDataWithCompletionHandler:(void (^)(NSData * _Nullable, NSError * _Nullable))completionHandler;
- (void)createPDFWithConfiguration:(id _Nullable)pdfConfiguration completionHandler:(void (^)(NSData * _Nullable pdfDocumentData, NSError * _Nullable error))completionHandler;

#ifndef __MAC_11_3
- (void)startDownloadUsingRequest:(NSURLRequest *)request completionHandler:(void(^)(_WKDownload *))completionHandler;
- (void)resumeDownloadFromResumeData:(NSData *)resumeData completionHandler:(void(^)(_WKDownload *))completionHandler;
#endif

@end

NS_ASSUME_NONNULL_END
