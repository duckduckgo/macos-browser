//
//  NSURL+sandboxExtensionRetainCount.m
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

#import <Foundation/Foundation.h>

// Macro for adding quotes
#define STRINGIFY(X) STRINGIFY2(X)
#define STRINGIFY2(X) #X

#import STRINGIFY(SWIFT_OBJC_INTERFACE_HEADER_NAME)

@implementation NSURL (sandboxExtensionRetainCount)

/**
 * This method will be automatically called at app launch time to swizzle `startAccessingSecurityScopedResource` and
 * `stopAccessingSecurityScopedResource` methods to accurately reflect the current number of start and stop calls
 * stored in the associated `NSURL.sandboxExtensionRetainCount` value.
 *
 * See SecurityScopedFileURLController.swift
 */
+ (void)initialize {
    [self swizzleStartStopAccessingSecurityScopedResourceOnce];
}

@end
