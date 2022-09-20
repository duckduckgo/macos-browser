//
//  OpenSSLWrapper.m
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

#import "OpenSSLWrapper.h"
#import "os/log.h"

#define KEY_LENGTH  2048
#define PUB_EXP     65537
#define WRITE_TO_FILE

@implementation OpenSSLWrapper

RSA *keypair;
BIO *pri;
BIO *pub;

//TODO Check return values
//TODO Free stuff

// Returns public key base64 encoded
- (NSString *)generateKeys {
    // Generate key pair
    keypair = RSA_generate_key(KEY_LENGTH, PUB_EXP, NULL, NULL);

    // Return the public key in the desired format
    size_t outputLength;
    char   *outputKey;
    BIO *output = BIO_new(BIO_s_mem());
    i2d_RSA_PUBKEY_bio(output,keypair);
    outputLength = BIO_pending(output);
    outputKey = malloc(outputLength + 1);
    BIO_read(output, outputKey, (int)outputLength);

    NSData *outputData = [NSData dataWithBytes:outputKey length:outputLength];

    free(outputKey);
    return [outputData base64EncodedStringWithOptions:0];
}

- (NSString *)decryptSharedKey:(NSString *)sharedKey {
    NSData *sharedKeyData = [[NSData alloc] initWithBase64EncodedString:sharedKey options:0];
    unsigned char *sharedKeyDataPointer = (unsigned char *)[sharedKeyData bytes];

    // Decrypt it
    unsigned char decrypted[2560] = { 0 };
    int decryptedLength = RSA_private_decrypt(RSA_size(keypair),
                                              sharedKeyDataPointer,
                                              decrypted,
                                              keypair,
                                              RSA_PKCS1_OAEP_PADDING);
    if(decryptedLength == -1) {
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEBUG,"Failed %s", ERR_error_string(ERR_get_error(), NULL));
    }

    NSData *decryptedSharedKeyData = [NSData dataWithBytes:decrypted length:decryptedLength];
    return [decryptedSharedKeyData base64EncodedStringWithOptions:0];


}

@end
