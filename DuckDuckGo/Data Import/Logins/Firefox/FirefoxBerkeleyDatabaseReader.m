//
//  FirefoxBerkeleyDatabaseReader.m
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

#import "FirefoxBerkeleyDatabaseReader.h"

#include <sys/types.h>
#include <db.h>
#include <fcntl.h>
#include <limits.h>

// MARK: - NSData to Hexadecimal

@interface NSData (NSDataConversion)

- (NSString *)hexadecimalString;

@end

@implementation NSData (NSDataConversion)

- (NSString *)hexadecimalString {
    const unsigned char *dataBuffer = (const unsigned char *)[self bytes];

    if (!dataBuffer) {
        return [NSString string];
    }

    NSUInteger dataLength  = [self length];
    NSMutableString *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];

    for (int i = 0; i < dataLength; ++i) {
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
    }

    return [NSString stringWithString:hexString];
}

@end

// MARK: - FirefoxBerkeleyDatabaseReader

NSString * const FirefoxBerkeleyDatabaseReaderASN1Key = @"f8000000000000000000000000000001";

@implementation FirefoxBerkeleyDatabaseReader

+ (NSDictionary<NSString *, NSData *> *)readDatabase:(NSString *)databasePath {
    const char *path = [databasePath cStringUsingEncoding:NSUTF8StringEncoding];

    DB *db = dbopen(path, O_RDONLY, O_RDONLY, DB_HASH, NULL);
    NSMutableDictionary<NSString *, NSData *> *resultDictionary = [NSMutableDictionary dictionary];
    DBT currentKeyDBT, currentDataDBT;

    while (db->seq(db, &currentKeyDBT, &currentDataDBT, R_NEXT) == 0) {
        NSData *currentKeyData = [NSData dataWithBytes:currentKeyDBT.data length:currentKeyDBT.size];
        NSData *currentData = [NSData dataWithBytes:currentDataDBT.data length:currentDataDBT.size];

        NSString *currentKeyHexadecimalString = [currentKeyData hexadecimalString];
        NSString *currentKeyString = [[NSString alloc] initWithData:currentKeyData encoding:NSUTF8StringEncoding];

        if ([currentKeyHexadecimalString isEqualToString:FirefoxBerkeleyDatabaseReaderASN1Key]) {
            [resultDictionary setValue:currentData forKey:@"data"];
        } else {
            [resultDictionary setValue:currentData forKey:currentKeyString];
        }
    }

    db->close(db);

    return resultDictionary;
}

@end
