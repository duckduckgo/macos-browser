//
//  NSObject+performSelector.m
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

#import "NSObject+performSelector.h"

@implementation NSObject (performSelector)

- (id)performSelector:(SEL)selector withArguments:(NSArray *)arguments {
    NSMethodSignature *methodSignature = [self methodSignatureForSelector:selector];

    if (!methodSignature) {
        [[[NSException alloc] initWithName:@"InvalidSelectorOrTarget" reason:[NSString stringWithFormat:@"Could not get method signature for selector %@ on %@", NSStringFromSelector(selector), self] userInfo:nil] raise];
    }

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
    [invocation setSelector:selector];
    [invocation setTarget:self];

    for (NSInteger i = 0; i < arguments.count; i++) {
        id argument = arguments[i];
        [invocation setArgument:&argument atIndex:i + 2]; // Indices 0 and 1 are reserved for target and selector
    }

    [invocation invoke];

    if (methodSignature.methodReturnLength > 0) {
        id returnValue;
        [invocation getReturnValue:&returnValue];

        return returnValue;
    }

    return nil;
}


@end
