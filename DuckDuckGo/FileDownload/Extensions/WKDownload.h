//
//  WKDownload.h
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
#import "WebKitDownloadDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@protocol WebKitDownload <NSObject>
@property (nonatomic, readonly, nullable) NSURLRequest *originalRequest;
@property (nonatomic, readonly, weak) WKWebView *webView;
@end

#ifndef __MAC_11_3
// defining non-existing in pre-macOS 11.3 WKDownload; WKDownloadDelegate

@class WKDownload;

@protocol WKDownloadDelegate <NSObject>
@required
- (void)download:(WKDownload *)download decideDestinationUsingResponse:(NSURLResponse *)response suggestedFilename:(NSString *)suggestedFilename completionHandler:(void (^)(NSURL * _Nullable destination))completionHandler;

@optional
- (void)download:(WKDownload *)download willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request decisionHandler:(void (^)(WKDownloadRedirectPolicy))decisionHandler;
- (void)download:(WKDownload *)download didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler;
- (void)downloadDidFinish:(WKDownload *)download;
- (void)download:(WKDownload *)download didFailWithError:(NSError *)error resumeData:(nullable NSData *)resumeData;
@end

#endif

API_AVAILABLE(macosx(11.3))
@protocol ObjCWKDownloadProtocol <NSObject>
@property (nonatomic, weak) id <WKDownloadDelegate> delegate;
- (void)cancel:(void(^ _Nullable)(NSData * _Nullable resumeData))completionHandler;
@end

#ifndef __MAC_11_3

// https://github.com/WebKit/WebKit/blob/9a6f03d46238213231cf27641ed1a55e1949d074/Source/WebKit/UIProcess/API/Cocoa/WKDownload.h
API_AVAILABLE(macosx(11.3))
@interface WKDownload : NSObject<NSProgressReporting, WebKitDownload, ObjCWKDownloadProtocol>
@property (nonatomic, readonly, nullable) NSURLRequest *originalRequest;
@property (nonatomic, readonly, weak) WKWebView *webView;
@property (nonatomic, weak) id <WKDownloadDelegate> delegate;

- (void)cancel:(void(^ _Nullable)(NSData * _Nullable resumeData))completionHandler;
@end

#endif

NS_ASSUME_NONNULL_END
