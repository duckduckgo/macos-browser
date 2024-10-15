//
//  DHCPOptionDetector.h
//  NetworkProtectionMac
//
//  Created by ddg on 10/15/24.
//


#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

@interface VPNGuardian : NSObject

- (nullable NSData *)getDHCPOption121;

@end
