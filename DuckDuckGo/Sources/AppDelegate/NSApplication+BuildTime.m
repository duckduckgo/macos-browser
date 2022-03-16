//
//  NSApplication+BuildTime.m
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

#import "NSApplication+BuildTime.h"

@implementation NSApplication (BuildTime)

- (NSDate *)buildDate {
    NSString *buildDateTime = [[NSString stringWithUTF8String:__DATE__] stringByAppendingFormat:@" %s", __TIME__];
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    
    [df setDateFormat:@"MMM d yyyy HH:mm:ss"];
    [df setLocale: [NSLocale localeWithLocaleIdentifier:@"en_US"]];

    return [df dateFromString:buildDateTime];
}

@end
