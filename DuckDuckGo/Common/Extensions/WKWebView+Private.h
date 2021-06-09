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

NS_ASSUME_NONNULL_BEGIN

@interface WKWebView (Private)

- (void)_restoreFromSessionStateData:(NSData *)data;
- (NSData * _Nullable)_sessionStateData;

- (void)createWebArchiveDataWithCompletionHandler:(void (^)(NSData * _Nullable, NSError * _Nullable))completionHandler;
- (void)createPDFWithConfiguration:(id _Nullable)pdfConfiguration completionHandler:(void (^)(NSData * _Nullable pdfDocumentData, NSError * _Nullable error))completionHandler;

#ifndef __MAC_10_15_3
- (void)startDownloadUsingRequest:(NSURLRequest * _Nonnull)request completionHandler:(void(^ _Nonnull)(NSObject * _Nonnull))completionHandler;
- (void)resumeDownloadFromResumeData:(NSData * _Nonnull)resumeData completionHandler:(void(^ _Nonnull)(NSObject * _Nonnull))completionHandler;
#endif

@end

#ifndef __MAC_10_15

typedef NS_ENUM(NSInteger, WKDownloadRedirectPolicy) {
    WKDownloadRedirectPolicyCancel,
    WKDownloadRedirectPolicyAllow,
} NS_SWIFT_NAME(WKDownload.RedirectPolicy);

@protocol WKDownloadDelegate <NSObject>

@required
- (void)download:(WKDownload *)download decideDestinationUsingResponse:(NSURLResponse *)response suggestedFilename:(NSString *)suggestedFilename completionHandler:(void (^)(NSURL * _Nullable destination))completionHandler;

@optional
- (void)download:(WKDownload *)download willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request decisionHandler:(void (^)(WKDownloadRedirectPolicy))decisionHandler WK_SWIFT_ASYNC_NAME(download(_:decidedPolicyForHTTPRedirection:newRequest:)) WK_SWIFT_ASYNC(4);
- (void)download:(WKDownload *)download didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler WK_SWIFT_ASYNC_NAME(download(_:respondTo:));
- (void)downloadDidFinish:(WKDownload *)download;
- (void)download:(WKDownload *)download didFailWithError:(NSError *)error resumeData:(nullable NSData *)resumeData;
@end

@interface WKDownload : NSObject<NSProgressReporting>
@property (nonatomic, readonly, nullable) NSURLRequest *originalRequest;
@property (nonatomic, weak) id <WKDownloadDelegate> delegate;

- (void)cancel:(void(^ _Nullable)(NSData * _Nullable resumeData))completionHandler;
@end

#endif

@interface _WKDownload : NSObject <NSCopying>

- (void)cancel;

- (void)publishProgressAtURL:(NSURL *)URL;

@property (nonatomic, readonly) NSURLRequest *request;
@property (nonatomic, readonly, weak) WKWebView *originatingWebView;
@property (nonatomic, readonly, copy) NSArray<NSURL *> *redirectChain;
@property (nonatomic, readonly) BOOL wasUserInitiated;
@property (nonatomic, readonly) NSData *resumeData;
@property (nonatomic, readonly) WKFrameInfo *originatingFrame;

@end

@interface WKProcessPool (Private)

// https://github.com/WebKit/WebKit/blob/8afe31a018b11741abdf9b4d5bb973d7c1d9ff05/Source/WebKit/UIProcess/API/Cocoa/WKProcessPool.mm#L522
- (NSObject *)_downloadURLRequest:(NSURLRequest *)request websiteDataStore:(WKWebsiteDataStore *)dataStore originatingWebView:(WKWebView *)webView;
- (NSObject *)_resumeDownloadFromData:(NSData *)resumeData websiteDataStore:(WKWebsiteDataStore *)dataStore path:(NSString *)path originatingWebView:(WKWebView *)webView;

@end

NS_ASSUME_NONNULL_END
