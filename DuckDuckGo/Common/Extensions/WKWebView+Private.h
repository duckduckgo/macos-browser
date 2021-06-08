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

@interface WKWebView (Private)

- (void)_restoreFromSessionStateData:(NSData * _Nonnull)data;
- (NSData * _Nullable)_sessionStateData;

- (void)createWebArchiveDataWithCompletionHandler:(void (^ _Nonnull)(NSData * _Nullable, NSError * _Nullable))completionHandler;
- (void)createPDFWithConfiguration:(id _Nullable)pdfConfiguration completionHandler:(void (^ _Nonnull)(NSData * _Nullable pdfDocumentData, NSError * _Nullable error))completionHandler;

- (void)startDownloadUsingRequest:(NSURLRequest * _Nonnull)request completionHandler:(void(^ _Nonnull)(NSObject * _Nonnull))completionHandler;
- (void)resumeDownloadFromResumeData:(NSData * _Nonnull)resumeData completionHandler:(void(^ _Nonnull)(NSObject * _Nonnull))completionHandler;

@end

@interface WKProcessPool (Private)

// https://github.com/WebKit/WebKit/blob/8afe31a018b11741abdf9b4d5bb973d7c1d9ff05/Source/WebKit/UIProcess/API/Cocoa/WKProcessPool.mm#L522
- (NSObject * _Nonnull)_downloadURLRequest:(NSURLRequest * _Nonnull)request websiteDataStore:(WKWebsiteDataStore * _Nonnull)dataStore originatingWebView:(WKWebView * _Nonnull)webView;
- (NSObject * _Nonnull)_resumeDownloadFromData:(NSData * _Nonnull)resumeData websiteDataStore:(WKWebsiteDataStore * _Nonnull)dataStore path:(NSString * _Nonnull)path originatingWebView:(WKWebView * _Nonnull)webView;

@end
